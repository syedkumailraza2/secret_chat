"""LangChain -> OpenAI pipeline for recipe generation.

Routes never talk to OpenAI directly; they go through recipe_service, which
calls into here.
"""

import logging

from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI

from config import get_settings
from models.recipe import RecipeDraft, RecipeDraftList
from prompts.recipe_prompt import SYSTEM_PROMPT, build_user_prompt

logger = logging.getLogger(__name__)


class AIServiceError(Exception):
    """Raised when generation fails for a reason the caller should handle."""


class AIService:
    def __init__(self) -> None:
        self.settings = get_settings()
        self._chain = None

    def _build_chain(self):
        """Lazily construct the chain so importing this module never requires
        credentials (which keeps mock mode and the test suite cheap)."""
        if self._chain is not None:
            return self._chain

        llm = ChatOpenAI(
            model=self.settings.openai_text_model,
            temperature=self.settings.openai_temperature,
            api_key=self.settings.openai_api_key,
            timeout=90,
            max_retries=2,
        )

        # Structured output binds the Pydantic schema to the model, so the
        # response is validated JSON rather than prose we have to parse.
        structured = llm.with_structured_output(
            RecipeDraftList,
            method="json_schema",
        )

        prompt = ChatPromptTemplate.from_messages(
            [
                ("system", SYSTEM_PROMPT),
                ("human", "{request}"),
            ]
        )

        self._chain = prompt | structured
        return self._chain

    async def generate_recipes(
        self,
        *,
        ingredients: list[str],
        goal: str,
        meal: str,
        max_cooking_time: int,
        servings: int,
        diet: str | None,
        allergies: list[str],
        cuisines: list[str],
        count: int | None = None,
    ) -> list[RecipeDraft]:
        count = count or self.settings.recipes_per_request

        user_prompt = build_user_prompt(
            ingredients=ingredients,
            goal=goal,
            meal=meal,
            max_cooking_time=max_cooking_time,
            servings=servings,
            diet=diet,
            allergies=allergies,
            cuisines=cuisines,
            count=count,
        )

        try:
            chain = self._build_chain()
            result = await chain.ainvoke({"request": user_prompt})
        except Exception as exc:  # noqa: BLE001 - surfaced as a clean error
            logger.exception("Recipe generation failed")
            raise AIServiceError(str(exc)) from exc

        if not isinstance(result, RecipeDraftList) or not result.recipes:
            raise AIServiceError("Model returned no recipes")

        return result.recipes
