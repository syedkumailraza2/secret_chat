"""Give generated recipes their photos.

Two jobs, both safe to re-run:

    .venv/bin/python backfill_images.py            # migrate only, costs nothing
    .venv/bin/python backfill_images.py --generate # also generate what is missing

**Migrate** rewrites any recipe still holding an inline `data:` URI into a file
under `media/`, leaving a short path on the document. Those documents were
megabytes each and shipped in full with every feed page containing them.

**Generate** calls the image model for recipes that have no photo at all. That
costs real money — one call per recipe — so it is opt-in and prints what it is
about to do first.

Generated recipes reach the feed without a photo because generation returns
text immediately and the client fetches each image afterwards; anything created
outside that flow, including by a script, never gets one.
"""

import argparse
import asyncio
import base64
import logging

import db
from config import get_settings
from models.recipe import Recipe
from services.image_service import ImageService, ImageServiceError
from services.recipe_repository import RecipeRepository, _to_recipe

logging.basicConfig(level=logging.INFO, format="%(levelname)-8s %(message)s")
logger = logging.getLogger("backfill")


async def migrate_data_uris() -> int:
    """Inline base64 -> a file on disk. No network, no cost."""
    collection = db.get_db()[db.RECIPES]
    settings = get_settings()
    settings.media_root.mkdir(parents=True, exist_ok=True)

    from services.image_service import media_path_for

    migrated = 0
    async for doc in collection.find({"image_url": {"$regex": "^data:"}}):
        url = doc["image_url"]
        try:
            payload = base64.b64decode(url.split(",", 1)[1])
        except (IndexError, ValueError):
            logger.warning("%s: unreadable data URI, clearing it", doc["_id"])
            await collection.update_one(
                {"_id": doc["_id"]}, {"$set": {"image_url": None}}
            )
            continue

        path = media_path_for(doc["_id"])
        (settings.media_root / path.removeprefix("/media/")).write_bytes(payload)
        await collection.update_one(
            {"_id": doc["_id"]}, {"$set": {"image_url": path}}
        )
        logger.info(
            "%s: %.1f MB inline -> %s", doc["name"][:40], len(url) / 1_048_576, path
        )
        migrated += 1

    return migrated


async def generate_missing(limit: int | None) -> tuple[int, int]:
    """One image-model call per recipe without a photo."""
    collection = db.get_db()[db.RECIPES]
    images = ImageService()
    repository = RecipeRepository()

    query = {"image_url": None, "source": "generated"}
    pending = [doc async for doc in collection.find(query)]
    if limit:
        pending = pending[:limit]

    if not pending:
        logger.info("Nothing to generate — every recipe already has a photo.")
        return 0, 0

    logger.info("Generating %s images. This costs money.", len(pending))

    done = failed = 0
    for doc in pending:
        recipe: Recipe = _to_recipe(doc)
        try:
            url = await images.generate_for_recipe(recipe)
        except ImageServiceError as exc:
            logger.error("%s: %s", recipe.name[:40], exc)
            failed += 1
            continue

        await repository.set_image(recipe.id, url)
        logger.info("%s -> %s", recipe.name[:40], url)
        done += 1

    return done, failed


async def main(generate: bool, limit: int | None) -> None:
    if not await db.ping():
        logger.error("MongoDB is unreachable. Start it, then re-run.")
        return

    migrated = await migrate_data_uris()
    logger.info("Migrated %s inline image(s) to files.", migrated)

    if generate:
        settings = get_settings()
        if not settings.ai_enabled:
            logger.error(
                "Image generation needs OPENAI_API_KEY (and MOCK_AI off)."
            )
        else:
            done, failed = await generate_missing(limit)
            logger.info("Generated %s image(s), %s failed.", done, failed)
    else:
        remaining = await db.get_db()[db.RECIPES].count_documents(
            {"image_url": None, "source": "generated"}
        )
        if remaining:
            logger.info(
                "%s generated recipe(s) still have no photo. "
                "Re-run with --generate to create them.",
                remaining,
            )

    await db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--generate",
        action="store_true",
        help="Also call the image model for recipes with no photo (costs money).",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Cap how many images to generate in one run.",
    )
    args = parser.parse_args()
    asyncio.run(main(args.generate, args.limit))
