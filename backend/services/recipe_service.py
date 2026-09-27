"""Recipe orchestration.

The only module the routes talk to. It decides where a recipe comes from,
runs generated nutrition through validation, and persists everything to
MongoDB.
"""

import logging
import uuid

from config import get_settings
from models.recipe import GenerateRequest, Recipe
from services.ai_service import AIService, AIServiceError
from services.fingerprint import fingerprint
from services.image_service import ImageService, ImageServiceError
from services.nutrition_service import NutritionService
from services.recipe_repository import Page, RecipeRepository
from services.user_repository import UserRepository

logger = logging.getLogger(__name__)


class RecipeNotFound(Exception):
    pass


class GenerationFailed(Exception):
    pass


class AIUnavailable(Exception):
    """No OpenAI credentials configured, so generation cannot run."""


class RecipeService:
    def __init__(self) -> None:
        self.settings = get_settings()
        self.ai = AIService()
        self.images = ImageService()
        self.nutrition = NutritionService()
        self.recipes = RecipeRepository()
        self.users = UserRepository()

    # --- Feed ---------------------------------------------------------------

    async def list_recipes(
        self,
        category: str | None = None,
        limit: int = 10,
        cursor: str | None = None,
    ) -> Page:
        return await self.recipes.list_feed(
            category=category, limit=limit, cursor=cursor
        )

    async def browse(self, **filters) -> tuple[list[Recipe], int]:
        return await self.recipes.browse(**filters)

    async def get_recipe(self, recipe_id: str) -> Recipe:
        recipe = await self.recipes.get(recipe_id)
        if recipe is None:
            raise RecipeNotFound(recipe_id)
        return recipe

    # --- Saved --------------------------------------------------------------

    async def saved_recipes(self, user_id: str) -> list[Recipe]:
        ids = await self.users.saved_recipe_ids(user_id)
        return await self.recipes.get_many(ids)

    async def save_recipe(self, user_id: str, recipe_id: str) -> None:
        # Confirms the recipe exists before recording the save, so the saved
        # list can never point at nothing.
        await self.get_recipe(recipe_id)
        await self.users.save(user_id, recipe_id)

    async def unsave_recipe(self, user_id: str, recipe_id: str) -> None:
        await self.users.unsave(user_id, recipe_id)

    # --- Generation ---------------------------------------------------------

    async def generate(
        self, request: GenerateRequest, user_id: str | None = None
    ) -> tuple[list[Recipe], bool]:
        """Generate recipes, validate their nutrition, and store them.

        Returns the recipes and whether they came from the cache. An identical
        earlier request is reused rather than re-run: it is faster, it costs
        nothing, and the results are just as good — the inputs were the same.
        The caller can force a real generation with `force_new`, which is what
        happens when the user declines what they were offered.
        """

        request_fingerprint = fingerprint(request)

        if not request.force_new:
            cached = await self.recipes.find_by_fingerprint(
                request_fingerprint,
                limit=self.settings.recipes_per_request,
            )
            if cached:
                logger.info(
                    "Serving %s cached recipes for fingerprint %s",
                    len(cached),
                    request_fingerprint[:12],
                )
                return cached, True

        if not self.settings.ai_enabled:
            raise AIUnavailable(
                "OPENAI_API_KEY is not configured on the server"
            )

        try:
            drafts = await self.ai.generate_recipes(
                ingredients=request.ingredients,
                goal=request.goal,
                meal=request.meal,
                max_cooking_time=request.max_cooking_time,
                servings=request.servings,
                diet=request.diet,
                allergies=request.allergies,
                cuisines=request.cuisines,
            )
        except AIServiceError as exc:
            raise GenerationFailed(str(exc)) from exc

        recipes: list[Recipe] = []
        for draft in drafts:
            recipe_id = f"gen-{uuid.uuid4().hex[:12]}"
            recipe = Recipe.from_draft(
                draft,
                recipe_id,
                categories=[request.meal, request.goal],
            )

            # Nutrition is never returned straight from the model.
            validated = self.nutrition.validate(
                recipe.nutrition,
                recipe.ingredients,
                recipe.servings,
            )
            recipe.nutrition = validated
            recipe.calories = validated.calories
            recipe.protein = validated.protein
            recipe.carbs = validated.carbs
            recipe.fat = validated.fat

            recipes.append(recipe)

        # Stored with the fingerprint so the next identical request is a
        # database read instead of another model call.
        await self.recipes.insert_many(
            recipes, created_by=user_id, fingerprint=request_fingerprint
        )
        return recipes, False

    # --- Images -------------------------------------------------------------

    async def generate_image(self, recipe_id: str) -> str | None:
        recipe = await self.get_recipe(recipe_id)

        # Seeded recipes already ship with photography.
        if recipe.image_url:
            return recipe.image_url

        if not self.settings.ai_enabled:
            logger.warning(
                "Image generation skipped — no OPENAI_API_KEY configured."
            )
            return None

        try:
            url = await self.images.generate_for_recipe(recipe)
        except ImageServiceError:
            # A missing photo must not fail the request; the client shows a
            # placeholder.
            return None

        await self.recipes.set_image(recipe_id, url)
        return url


_service: RecipeService | None = None


def get_recipe_service() -> RecipeService:
    """FastAPI dependency."""
    global _service
    if _service is None:
        _service = RecipeService()
    return _service
