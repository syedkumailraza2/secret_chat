"""Pydantic schemas shared by the API and the AI pipeline.

`RecipeDraft` is the shape the language model is constrained to produce.
`Recipe` is what the API returns — the draft plus server-assigned fields.
"""

from typing import Literal, Optional

from pydantic import BaseModel, Field

Difficulty = Literal["Easy", "Medium", "Hard"]


class Ingredient(BaseModel):
    name: str = Field(description="Ingredient name, e.g. 'Paneer, cubed'")
    quantity: float = Field(
        default=0,
        ge=0,
        description="Numeric amount. Use 0 only when the unit is self-contained.",
    )
    unit: str = Field(
        default="",
        description="Unit of measure, e.g. 'g', 'ml', 'cup', 'tbsp', 'tsp'",
    )
    optional: bool = Field(
        default=False,
        description="True when the recipe works without this ingredient.",
    )


class Nutrition(BaseModel):
    """Per-serving nutrition.

    These come from the model as estimates and are then checked by
    nutrition_service before being returned.
    """

    calories: int = Field(ge=0, le=5000)
    protein: float = Field(ge=0, le=500)
    carbs: float = Field(ge=0, le=500)
    fat: float = Field(ge=0, le=500)
    fiber: float = Field(default=0, ge=0, le=200)
    sugar: float = Field(default=0, ge=0, le=500)
    sodium: float = Field(default=0, ge=0, le=20000)
    cholesterol: float = Field(default=0, ge=0, le=5000)
    estimated: bool = Field(
        default=True,
        description="True when the values are AI estimates rather than "
        "looked up in a nutrition database.",
    )


class RecipeDraft(BaseModel):
    """The structured output contract for the language model."""

    name: str
    description: str
    ingredients: list[Ingredient]
    instructions: list[str]
    nutrition: Nutrition
    servings: int = Field(ge=1, le=12)
    cooking_time: int = Field(ge=1, le=240, description="Total minutes")
    difficulty: Difficulty


class RecipeDraftList(BaseModel):
    """Wrapper so the model returns several recipes in one structured call."""

    recipes: list[RecipeDraft]


class Recipe(BaseModel):
    """A recipe as the API returns it."""

    id: str
    name: str
    description: str = ""
    image_url: Optional[str] = None

    nutrition: Nutrition

    # Flat macros mirror the response shape in the brief and keep simple
    # clients from having to reach into the nested object.
    calories: int = 0
    protein: float = 0
    carbs: float = 0
    fat: float = 0

    servings: int = 2
    cooking_time: int = 0
    difficulty: str = "Easy"
    ingredients: list[Ingredient] = []
    instructions: list[str] = []
    categories: list[str] = []
    rating: float = 0
    review_count: int = 0
    ai_generated: bool = False

    @classmethod
    def from_draft(
        cls,
        draft: RecipeDraft,
        recipe_id: str,
        categories: list[str] | None = None,
    ) -> "Recipe":
        return cls(
            id=recipe_id,
            name=draft.name,
            description=draft.description,
            nutrition=draft.nutrition,
            calories=draft.nutrition.calories,
            protein=draft.nutrition.protein,
            carbs=draft.nutrition.carbs,
            fat=draft.nutrition.fat,
            servings=draft.servings,
            cooking_time=draft.cooking_time,
            difficulty=draft.difficulty,
            ingredients=draft.ingredients,
            instructions=draft.instructions,
            categories=categories or [],
            ai_generated=True,
        )


# --- Request / response envelopes ---------------------------------------


class GenerateRequest(BaseModel):
    ingredients: list[str] = Field(min_length=1)
    goal: str = "balanced"
    meal: str = "dinner"
    max_cooking_time: int = Field(default=30, ge=5, le=240)
    servings: int = Field(default=2, ge=1, le=12)
    diet: Optional[str] = None
    allergies: list[str] = []
    cuisines: list[str] = []

    force_new: bool = Field(
        default=False,
        description="Skip the cache and call the model even when an identical "
        "request has been generated before. This is what the client sends "
        "when the user declines the recipes it was offered.",
    )


class RecipeListResponse(BaseModel):
    recipes: list[Recipe]


class GenerateResponse(BaseModel):
    """Generation result, plus where the recipes came from.

    `cached` is what lets the results screen say these were made for someone
    else first and offer to generate fresh ones instead.
    """

    recipes: list[Recipe]
    cached: bool = False


class FeedResponse(BaseModel):
    """One page of the shuffled public feed.

    `next_cursor` is opaque: it encodes where in the shuffle this reader has
    got to, and is null once there is nothing left.
    """

    recipes: list[Recipe]
    next_cursor: Optional[str] = None
    has_more: bool = False


class BrowseResponse(BaseModel):
    recipes: list[Recipe]
    page: int
    page_size: int
    total: int
    has_more: bool = False


class ImageResponse(BaseModel):
    recipe_id: str
    image_url: Optional[str] = None
