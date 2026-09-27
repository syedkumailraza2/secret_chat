"""Seed the recipe feed.

A one-off developer tool, deliberately outside the request path: the API only
ever reads what is in MongoDB, so a fresh database simply has an empty feed
until this runs.

    cd backend
    .venv/bin/python seed_db.py           # insert if the feed is empty
    .venv/bin/python seed_db.py --reset   # wipe recipes first, then insert

Adding real content later means writing to the collection by any means you
like; nothing here is load-bearing.
"""

import argparse
import asyncio
import logging
import random
from datetime import datetime, timezone

import db
from seed_images import (
    AVOCADO_TOAST,
    CHIA_PUDDING,
    CHICKPEA_BOWL,
    MUSHROOM_RISOTTO,
    PANEER_BOWL,
    QUINOA_BOWL,
    SALMON,
    TOMATO_SOUP,
)

logging.basicConfig(level=logging.INFO, format="%(levelname)-8s %(message)s")
logger = logging.getLogger("seed")


def _recipe(
    *,
    id: str,
    name: str,
    description: str,
    image_url: str,
    calories: int,
    protein: float,
    carbs: float,
    fat: float,
    fiber: float,
    cooking_time: int,
    difficulty: str,
    categories: list[str],
    ingredients: list[tuple[str, float, str]],
    instructions: list[str],
    sort_order: int,
    servings: int = 2,
    rating: float = 0,
    review_count: int = 0,
) -> dict:
    return {
        "_id": id,
        "name": name,
        "description": description,
        "image_url": image_url,
        "nutrition": {
            "calories": calories,
            "protein": protein,
            "carbs": carbs,
            "fat": fat,
            "fiber": fiber,
            "sugar": 0.0,
            "sodium": 0.0,
            "cholesterol": 0.0,
            "estimated": True,
        },
        "calories": calories,
        "protein": protein,
        "carbs": carbs,
        "fat": fat,
        "servings": servings,
        "cooking_time": cooking_time,
        "difficulty": difficulty,
        "ingredients": [
            {"name": n, "quantity": float(q), "unit": u, "optional": False}
            for n, q, u in ingredients
        ],
        "instructions": instructions,
        "categories": categories,
        "rating": rating,
        "review_count": review_count,
        "ai_generated": False,
        "created_by": None,
        "sort_order": sort_order,
        "created_at": datetime.now(timezone.utc),
        # Position in the shuffled feed. Fixed per recipe, so paging through
        # the feed never repeats or skips one.
        "random_key": random.random(),
        "is_public": True,
        "source": "seed",
        "input_fingerprint": None,
    }


# sort_order drives the feed ordering; 0 is the card the design features.
SEED_RECIPES = [
    _recipe(
        id="chickpea-power-bowl",
        name="Creamy Chickpea Power Bowl",
        description=(
            "Golden spiced chickpeas over fresh greens with a creamy tahini "
            "drizzle — a bowl that eats like a proper meal."
        ),
        image_url=CHICKPEA_BOWL,
        calories=420, protein=18, carbs=52, fat=14, fiber=12,
        cooking_time=20, difficulty="Easy", sort_order=0,
        categories=["healthy", "lunch", "high_protein", "quick", "popular"],
        ingredients=[
            ("Chickpeas, drained", 400, "g"),
            ("Baby spinach", 100, "g"),
            ("Cherry tomatoes, halved", 150, "g"),
            ("Tahini", 2, "tbsp"),
            ("Lemon juice", 1, "tbsp"),
            ("Olive oil", 1, "tbsp"),
            ("Smoked paprika", 1, "tsp"),
        ],
        instructions=[
            "Pat the chickpeas dry, then toss them with the olive oil and "
            "smoked paprika until evenly coated.",
            "Pan-fry the chickpeas over medium-high heat for 8-10 minutes, "
            "shaking the pan occasionally, until golden and slightly crisp.",
            "Whisk the tahini with the lemon juice and 2 tablespoons of warm "
            "water until it loosens into a pourable dressing.",
            "Divide the spinach and tomatoes between two bowls, top with the "
            "warm chickpeas, and finish with the tahini drizzle.",
        ],
        rating=4.7, review_count=96,
    ),
    _recipe(
        id="high-protein-paneer-bowl",
        name="High Protein Paneer Bowl",
        description=(
            "Seared tikka-spiced paneer over fluffy quinoa with broccoli and "
            "cherry tomatoes."
        ),
        image_url=PANEER_BOWL,
        calories=520, protein=28, carbs=62, fat=18, fiber=8,
        cooking_time=25, difficulty="Easy", sort_order=1,
        categories=["healthy", "dinner", "high_protein", "popular"],
        ingredients=[
            ("Paneer, cubed", 150, "g"),
            ("Quinoa", 0.5, "cup"),
            ("Broccoli florets", 1, "cup"),
            ("Cherry tomatoes", 100, "g"),
            ("Olive oil", 1, "tbsp"),
            ("Tikka masala spice mix", 2, "tsp"),
        ],
        instructions=[
            "Rinse the quinoa thoroughly. In a small pot, bring 1 cup of "
            "water to a boil, add the quinoa, cover, and simmer for 15 "
            "minutes or until water is absorbed.",
            "While quinoa is cooking, toss the cubed paneer in the tikka "
            "masala spice mix. Heat olive oil in a pan over medium heat and "
            "sear the paneer until golden brown on all sides (about 5-7 "
            "minutes).",
            "Lightly steam or blanch the broccoli florets until tender-crisp. "
            "Halve the cherry tomatoes.",
            "Assemble the bowl by placing a base of cooked quinoa, topping "
            "with the seared paneer, steamed broccoli, and fresh tomatoes. "
            "Serve immediately.",
        ],
        rating=4.8, review_count=124,
    ),
    _recipe(
        id="avocado-toast-poached-egg",
        name="Artisanal Avocado Toast with Poached Egg",
        description=(
            "Sourdough, smashed avocado and a soft poached egg, finished with "
            "microgreens and chilli flakes."
        ),
        image_url=AVOCADO_TOAST,
        calories=340, protein=14, carbs=32, fat=18, fiber=9,
        cooking_time=10, difficulty="Easy", sort_order=2,
        categories=["healthy", "breakfast", "quick", "under_500"],
        ingredients=[
            ("Sourdough bread", 2, "slices"),
            ("Avocado, ripe", 1, ""),
            ("Eggs", 2, ""),
            ("Lemon juice", 1, "tsp"),
            ("Red pepper flakes", 0.5, "tsp"),
            ("Microgreens", 10, "g"),
        ],
        instructions=[
            "Bring a shallow pan of water to a bare simmer and add a splash "
            "of vinegar.",
            "Toast the sourdough until deeply golden.",
            "Mash the avocado with the lemon juice and a pinch of salt, then "
            "spread it thickly over the toast.",
            "Poach the eggs for 3 minutes, lift out with a slotted spoon, and "
            "set one on each toast.",
            "Finish with microgreens and red pepper flakes.",
        ],
        rating=4.6, review_count=88,
    ),
    _recipe(
        id="mediterranean-quinoa-bowl",
        name="Mediterranean Quinoa Power Bowl",
        description="Roasted chickpeas, cucumber, olives and tahini over quinoa.",
        image_url=QUINOA_BOWL,
        calories=420, protein=18, carbs=54, fat=16, fiber=11,
        cooking_time=25, difficulty="Easy", sort_order=3,
        categories=["healthy", "lunch", "high_protein", "under_500"],
        ingredients=[
            ("Quinoa", 1, "cup"),
            ("Chickpeas, drained", 240, "g"),
            ("Cucumber, diced", 1, ""),
            ("Cherry tomatoes", 150, "g"),
            ("Kalamata olives", 50, "g"),
            ("Tahini", 2, "tbsp"),
            ("Olive oil", 1, "tbsp"),
        ],
        instructions=[
            "Cook the quinoa in 2 cups of water for 15 minutes, then fluff "
            "with a fork and let it cool slightly.",
            "Roast the chickpeas with the olive oil at 200C for 20 minutes "
            "until crisp.",
            "Combine the cucumber, tomatoes and olives in a bowl.",
            "Layer the quinoa, vegetables and chickpeas, then drizzle with "
            "tahini loosened with a little water.",
        ],
        rating=4.5, review_count=71,
    ),
    _recipe(
        id="wild-mushroom-risotto",
        name="Creamy Wild Mushroom Risotto",
        description="Slow-stirred arborio with wild mushrooms, parmesan and parsley.",
        image_url=MUSHROOM_RISOTTO,
        calories=510, protein=12, carbs=72, fat=17, fiber=4,
        cooking_time=40, difficulty="Medium", sort_order=4,
        categories=["dinner", "popular"],
        ingredients=[
            ("Arborio rice", 200, "g"),
            ("Mixed wild mushrooms", 250, "g"),
            ("Vegetable stock", 750, "ml"),
            ("Parmesan, grated", 40, "g"),
            ("Onion, finely diced", 1, ""),
            ("Butter", 20, "g"),
            ("Flat-leaf parsley", 10, "g"),
        ],
        instructions=[
            "Warm the stock in a pan and keep it at a bare simmer.",
            "Soften the onion in half the butter for 5 minutes, then add the "
            "mushrooms and cook until their liquid has evaporated.",
            "Stir in the rice and toast it for 1 minute.",
            "Add the stock a ladle at a time, stirring, waiting for each "
            "addition to absorb before the next — about 20 minutes.",
            "Beat in the remaining butter and the parmesan, then scatter with "
            "parsley and serve.",
        ],
        rating=4.9, review_count=142,
    ),
    _recipe(
        id="berry-chia-pudding",
        name="Berry Layered Chia Pudding",
        description="Overnight chia layered with berry compote and raspberries.",
        image_url=CHIA_PUDDING,
        calories=220, protein=8, carbs=26, fat=9, fiber=10,
        cooking_time=10, difficulty="Easy", sort_order=5,
        categories=["breakfast", "snacks", "quick", "under_500"],
        ingredients=[
            ("Chia seeds", 4, "tbsp"),
            ("Milk", 300, "ml"),
            ("Mixed berries", 150, "g"),
            ("Maple syrup", 1, "tbsp"),
            ("Fresh raspberries", 50, "g"),
        ],
        instructions=[
            "Whisk the chia seeds into the milk with the maple syrup and let "
            "them stand for 5 minutes, then whisk again to break up clumps.",
            "Refrigerate for at least 4 hours, ideally overnight.",
            "Crush the mixed berries lightly to make a rough compote.",
            "Layer the set chia and the compote in glasses and top with fresh "
            "raspberries.",
        ],
        rating=4.4, review_count=53,
    ),
    _recipe(
        id="herb-crusted-salmon",
        name="Herb-Crusted Salmon",
        description="Crisp-skinned salmon with a herb crust and asparagus.",
        image_url=SALMON,
        calories=480, protein=38, carbs=12, fat=31, fiber=5,
        cooking_time=25, difficulty="Medium", sort_order=6,
        categories=["dinner", "high_protein", "under_500"],
        ingredients=[
            ("Salmon fillets", 2, ""),
            ("Asparagus spears", 200, "g"),
            ("Breadcrumbs", 40, "g"),
            ("Dill, chopped", 10, "g"),
            ("Parsley, chopped", 10, "g"),
            ("Dijon mustard", 1, "tbsp"),
            ("Olive oil", 1, "tbsp"),
        ],
        instructions=[
            "Heat the oven to 200C.",
            "Mix the breadcrumbs with the herbs and half the olive oil.",
            "Brush the salmon with mustard and press the herb crust onto the "
            "flesh side.",
            "Toss the asparagus in the remaining oil and spread it on a tray "
            "with the salmon.",
            "Roast for 12-14 minutes, until the salmon flakes and the crust "
            "is golden.",
        ],
        rating=4.7, review_count=110,
    ),
    _recipe(
        id="roasted-tomato-basil-soup",
        name="Roasted Tomato Basil Soup",
        description="Slow-roasted tomatoes blended with basil and a little cream.",
        image_url=TOMATO_SOUP,
        calories=260, protein=6, carbs=28, fat=13, fiber=6,
        cooking_time=45, difficulty="Easy", sort_order=7,
        categories=["lunch", "dinner", "under_500"],
        ingredients=[
            ("Ripe tomatoes", 1, "kg"),
            ("Garlic cloves", 4, ""),
            ("Onion, quartered", 1, ""),
            ("Vegetable stock", 400, "ml"),
            ("Basil leaves", 20, "g"),
            ("Olive oil", 2, "tbsp"),
            ("Double cream", 50, "ml"),
        ],
        instructions=[
            "Heat the oven to 200C. Halve the tomatoes and spread them on a "
            "tray with the garlic and onion.",
            "Drizzle with olive oil, season, and roast for 30 minutes until "
            "caramelised at the edges.",
            "Tip everything into a pot with the stock and simmer for 5 "
            "minutes.",
            "Blend until smooth, stir through the basil and cream, and adjust "
            "the seasoning.",
        ],
        rating=4.5, review_count=64,
    ),
]


async def main(reset: bool) -> None:
    if not await db.ping():
        logger.error(
            "Cannot reach MongoDB. Start it, then run this again."
        )
        raise SystemExit(1)

    await db.init_db()
    collection = db.get_db()[db.RECIPES]

    if reset:
        deleted = await collection.delete_many({"ai_generated": False})
        logger.info("Removed %s seeded recipes", deleted.deleted_count)

    existing = await collection.count_documents({})
    if existing and not reset:
        logger.info(
            "Feed already has %s recipes — nothing to do. "
            "Use --reset to replace them.",
            existing,
        )
        await db.close()
        return

    await collection.insert_many(SEED_RECIPES)
    logger.info("Inserted %s recipes", len(SEED_RECIPES))
    await db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Seed the NutriCook feed.")
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Delete existing seeded recipes before inserting. "
        "AI-generated recipes are left alone.",
    )
    args = parser.parse_args()
    asyncio.run(main(args.reset))
