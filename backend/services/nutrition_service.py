"""Nutrition validation.

The brief is explicit that the LLM must not be blindly trusted for nutrition
numbers. This module is the single place those numbers are checked, so a real
nutrition database can replace the estimate path later without touching the
routes, the AI service, or the client.

The seam is `NutritionSource`: today only `EstimatedNutritionSource` exists,
which sanity-checks what the model produced. A future
`DatabaseNutritionSource` would look each ingredient up and compute the totals
instead, and nothing else would need to change.
"""

import logging
from typing import Protocol

from models.recipe import Ingredient, Nutrition

logger = logging.getLogger(__name__)

# Atwater factors: kcal per gram of each macronutrient.
KCAL_PER_G_PROTEIN = 4.0
KCAL_PER_G_CARBS = 4.0
KCAL_PER_G_FAT = 9.0

# How far the macro-derived calorie total may drift from the stated calories
# before we treat the stated figure as unreliable. Rounding, fibre and sugar
# alcohols make some slack legitimate.
CALORIE_TOLERANCE = 0.25

# Plausible per-serving bounds for a single dish.
MIN_CALORIES = 20
MAX_CALORIES = 2000


class NutritionSource(Protocol):
    """Anything that can produce validated nutrition for a recipe."""

    def resolve(
        self, nutrition: Nutrition, ingredients: list[Ingredient], servings: int
    ) -> Nutrition: ...


class EstimatedNutritionSource:
    """Validates the model's own estimates without an external database."""

    def resolve(
        self, nutrition: Nutrition, ingredients: list[Ingredient], servings: int
    ) -> Nutrition:
        protein = max(0.0, nutrition.protein)
        carbs = max(0.0, nutrition.carbs)
        fat = max(0.0, nutrition.fat)
        calories = nutrition.calories

        derived = (
            protein * KCAL_PER_G_PROTEIN
            + carbs * KCAL_PER_G_CARBS
            + fat * KCAL_PER_G_FAT
        )

        # If the stated calories disagree materially with the macros, trust the
        # macros — they are individually easier for the model to get right than
        # a single aggregate figure.
        if derived > 0:
            drift = abs(calories - derived) / derived
            if drift > CALORIE_TOLERANCE:
                logger.info(
                    "Calories %s inconsistent with macros (derived %.0f); "
                    "using derived value",
                    calories,
                    derived,
                )
                calories = round(derived)

        calories = int(min(max(calories, MIN_CALORIES), MAX_CALORIES))

        # Fibre is a subset of carbohydrate, and sugar cannot exceed it either.
        fiber = min(max(0.0, nutrition.fiber), carbs)
        sugar = min(max(0.0, nutrition.sugar), carbs)

        return Nutrition(
            calories=calories,
            protein=round(protein, 1),
            carbs=round(carbs, 1),
            fat=round(fat, 1),
            fiber=round(fiber, 1),
            sugar=round(sugar, 1),
            sodium=round(max(0.0, nutrition.sodium), 1),
            cholesterol=round(max(0.0, nutrition.cholesterol), 1),
            estimated=True,
        )


class NutritionService:
    def __init__(self, source: NutritionSource | None = None) -> None:
        self._source = source or EstimatedNutritionSource()

    def validate(
        self,
        nutrition: Nutrition,
        ingredients: list[Ingredient] | None = None,
        servings: int = 1,
    ) -> Nutrition:
        return self._source.resolve(nutrition, ingredients or [], servings)
