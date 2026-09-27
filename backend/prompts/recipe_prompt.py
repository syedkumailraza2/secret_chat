"""Prompt construction for recipe generation.

Kept apart from the AI service so the wording can be iterated on without
touching the pipeline.
"""

SYSTEM_PROMPT = """You are a professional nutrition-aware chef.

Generate healthy recipes using the ingredients provided by the user.

Requirements:

1. Prioritize the user's available ingredients.
2. Respect dietary restrictions.
3. Respect allergies.
4. Respect cooking time.
5. Respect servings.
6. Provide exact ingredient quantities.
7. Provide clear step-by-step instructions.
8. Generate realistic calorie and macro estimates.
9. Prefer nutritionally balanced recipes.
10. Avoid unnecessary ingredients.
11. Clearly identify optional ingredients.
12. Return structured JSON matching the requested schema.

Additional guidance:

- Nutrition figures are PER SERVING, not for the whole dish.
- Keep macros physically consistent: protein and carbs are about 4 kcal per
  gram, fat about 9 kcal per gram, and those should roughly account for the
  calorie total.
- Every ingredient needs a numeric quantity and a unit. Use grams and
  millilitres for weights and volumes, and common kitchen units (cup, tbsp,
  tsp) where a cook would.
- Instructions should be complete sentences a beginner can follow, one action
  per step, in order.
- Never include an ingredient the user is allergic to, in any form or
  derivative.
- Staples such as salt, pepper, oil and water may be assumed available and
  added freely.
"""

# Human-readable labels for the enum-ish values the client sends.
GOAL_LABELS = {
    "high_protein": "maximise protein content",
    "low_calorie": "keep calories low",
    "balanced": "keep the macros balanced",
    "weight_loss": "support weight loss (lower calorie, high satiety)",
    "muscle_gain": "support muscle gain (high protein, sufficient calories)",
    "eat_healthier": "be nutritious and wholesome",
    "lose_weight": "support weight loss (lower calorie, high satiety)",
    "build_muscle": "support muscle gain (high protein, sufficient calories)",
    "maintain_weight": "maintain current weight with balanced macros",
}

DIET_LABELS = {
    "vegetarian": "vegetarian (no meat or fish; dairy and eggs are fine)",
    "vegan": "vegan (strictly plant-based, no animal products at all)",
    "non_vegetarian": "non-vegetarian (any protein is acceptable)",
    "pescatarian": "pescatarian (no meat; seafood, dairy and eggs are fine)",
}


def build_user_prompt(
    *,
    ingredients: list[str],
    goal: str,
    meal: str,
    max_cooking_time: int,
    servings: int,
    diet: str | None,
    allergies: list[str],
    cuisines: list[str],
    count: int,
) -> str:
    """Assemble the per-request instruction sent alongside SYSTEM_PROMPT."""

    lines = [
        f"Create {count} distinct healthy {meal} recipes.",
        "",
        f"Available ingredients: {', '.join(ingredients)}.",
        f"Goal: {GOAL_LABELS.get(goal, goal)}.",
        f"Maximum total cooking time: {max_cooking_time} minutes.",
        f"Servings: {servings}.",
    ]

    if diet:
        lines.append(f"Diet: {DIET_LABELS.get(diet, diet)}.")

    if allergies:
        lines.append(
            f"ALLERGIES — must be strictly avoided: {', '.join(allergies)}."
        )

    if cuisines:
        lines.append(f"Preferred cuisines: {', '.join(cuisines)}.")

    lines += [
        "",
        "Each recipe must be genuinely different from the others — vary the "
        "cooking method and the form of the dish, not just the seasoning.",
        f"Every recipe must be completable within {max_cooking_time} minutes "
        "and sized for exactly the requested number of servings.",
    ]

    return "\n".join(lines)
