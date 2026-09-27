"""Recipe persistence.

The only place recipe documents are read or written. Swapping the storage
engine means rewriting this file and nothing else.
"""

import base64
import logging
import random
import re
from dataclasses import dataclass
from datetime import datetime, timezone

from pymongo import ASCENDING, DESCENDING
from pymongo.errors import DuplicateKeyError

from db import RECIPES, get_db
from models.recipe import Recipe

logger = logging.getLogger(__name__)

# Fields stored on the document that the API model has no place for.
_INTERNAL_FIELDS = (
    "created_at",
    "sort_order",
    "created_by",
    "random_key",
    "is_public",
    "input_fingerprint",
    "source",
)


def _to_document(recipe: Recipe) -> dict:
    """Recipe -> BSON. `id` becomes `_id` so there is one identity, not two."""
    doc = recipe.model_dump()
    doc["_id"] = doc.pop("id")
    doc.setdefault("created_at", datetime.now(timezone.utc))
    return doc


def _to_recipe(doc: dict) -> Recipe:
    doc = dict(doc)
    doc["id"] = doc.pop("_id")
    for field in _INTERNAL_FIELDS:
        doc.pop(field, None)
    return Recipe(**doc)


@dataclass(frozen=True)
class Page:
    """One page of feed, plus the cursor that continues it."""

    recipes: list[Recipe]
    next_cursor: str | None


class _FeedCursor:
    """Where a shuffled walk of the feed has got to.

    The feed is randomised by giving every recipe a fixed `random_key` in
    [0, 1) and walking that space in order from a random starting point,
    wrapping past the end back to zero. The order is different for every
    reader because the start is, and no recipe repeats inside one walk —
    which is what `$sample` per page could never promise.
    """

    __slots__ = ("position", "start", "wrapped")

    def __init__(self, position: float, start: float, wrapped: bool) -> None:
        self.position = position
        self.start = start
        self.wrapped = wrapped

    @classmethod
    def fresh(cls) -> "_FeedCursor":
        start = random.random()
        return cls(position=start, start=start, wrapped=False)

    def encode(self) -> str:
        raw = f"{self.position!r}:{self.start!r}:{int(self.wrapped)}"
        return base64.urlsafe_b64encode(raw.encode("ascii")).decode("ascii")

    @classmethod
    def decode(cls, cursor: str | None) -> "_FeedCursor":
        """A cursor we cannot read starts a new walk rather than erroring —
        it is a scroll position, not a credential."""
        if not cursor:
            return cls.fresh()
        try:
            raw = base64.urlsafe_b64decode(cursor.encode("ascii")).decode(
                "ascii"
            )
            position, start, wrapped = raw.split(":")
            return cls(float(position), float(start), bool(int(wrapped)))
        except (ValueError, TypeError):
            logger.info("Unreadable feed cursor; starting a new walk")
            return cls.fresh()


class RecipeRepository:
    @property
    def _collection(self):
        return get_db()[RECIPES]

    # --- The public feed --------------------------------------------------

    async def list_feed(
        self,
        category: str | None = None,
        limit: int = 10,
        cursor: str | None = None,
    ) -> Page:
        """A page of the shuffled public feed.

        Every reader gets a different order, and paging never repeats or skips
        a recipe, because the walk is over a fixed random coordinate rather
        than a fresh sample each time.
        """
        position = _FeedCursor.decode(cursor)

        base: dict = {"is_public": True}
        if category:
            base["categories"] = category

        docs = await self._walk(base, position.position, None, limit)

        if len(docs) < limit and not position.wrapped:
            # Ran off the end of the space; continue from zero up to where
            # this walk began.
            remaining = limit - len(docs)
            docs += await self._walk(base, -1.0, position.start, remaining)
            position.wrapped = True
        elif position.wrapped:
            # Already past the wrap: everything ahead is bounded by the start.
            docs = await self._walk(
                base, position.position, position.start, limit
            )

        recipes = [_to_recipe(doc) for doc in docs]

        next_cursor = None
        if len(docs) == limit:
            position.position = float(docs[-1].get("random_key", 0.0))
            next_cursor = position.encode()

        return Page(recipes=recipes, next_cursor=next_cursor)

    async def _walk(
        self,
        base: dict,
        after: float,
        before: float | None,
        limit: int,
    ) -> list[dict]:
        if limit <= 0:
            return []
        bounds: dict = {"$gt": after}
        if before is not None:
            bounds["$lt"] = before
        cursor = (
            self._collection.find({**base, "random_key": bounds})
            .sort("random_key", ASCENDING)
            .limit(limit)
        )
        return [doc async for doc in cursor]

    # --- Browsing ---------------------------------------------------------

    async def browse(
        self,
        *,
        query: str | None = None,
        category: str | None = None,
        difficulty: str | None = None,
        max_cooking_time: int | None = None,
        max_calories: int | None = None,
        min_protein: int | None = None,
        created_by: str | None = None,
        sort: str = "recent",
        page: int = 1,
        page_size: int = 20,
    ) -> tuple[list[Recipe], int]:
        """Filtered, sorted, page-numbered browse over generated recipes.

        Page numbers rather than a cursor here: the sorts are deterministic,
        and a browse screen with filters wants a total and the ability to jump.
        """
        criteria: dict = {"is_public": True, "source": "generated"}

        if query:
            # Escaped, so a stray `(` in a search box is a character to match
            # rather than a regex the user has accidentally authored.
            pattern = re.escape(query.strip())
            criteria["$or"] = [
                {"name": {"$regex": pattern, "$options": "i"}},
                {"description": {"$regex": pattern, "$options": "i"}},
            ]
        if category:
            criteria["categories"] = category
        if difficulty:
            criteria["difficulty"] = difficulty
        if max_cooking_time:
            criteria["cooking_time"] = {"$lte": max_cooking_time}
        if max_calories:
            criteria["calories"] = {"$lte": max_calories}
        if min_protein:
            criteria["protein"] = {"$gte": min_protein}
        if created_by:
            criteria["created_by"] = created_by

        order = {
            "recent": [("created_at", DESCENDING), ("_id", DESCENDING)],
            "quick": [("cooking_time", ASCENDING), ("_id", ASCENDING)],
            "protein": [("protein", DESCENDING), ("_id", DESCENDING)],
            "calories": [("calories", ASCENDING), ("_id", ASCENDING)],
        }.get(sort, [("created_at", DESCENDING), ("_id", DESCENDING)])

        total = await self._collection.count_documents(criteria)

        page = max(1, page)
        cursor = (
            self._collection.find(criteria)
            .sort(order)
            .skip((page - 1) * page_size)
            .limit(page_size)
        )
        return [_to_recipe(doc) async for doc in cursor], total

    # --- Cache ------------------------------------------------------------

    async def find_by_fingerprint(
        self, fingerprint: str, limit: int = 3
    ) -> list[Recipe]:
        """Recipes a previous identical request already produced.

        Newest first: if the same inputs have been generated more than once,
        the most recent batch is the one to show.
        """
        cursor = (
            self._collection.find(
                {"input_fingerprint": fingerprint, "is_public": True}
            )
            .sort([("created_at", DESCENDING)])
            .limit(limit)
        )
        return [_to_recipe(doc) async for doc in cursor]

    # --- Reads ------------------------------------------------------------

    async def get(self, recipe_id: str) -> Recipe | None:
        doc = await self._collection.find_one({"_id": recipe_id})
        return _to_recipe(doc) if doc else None

    async def get_many(self, recipe_ids: list[str]) -> list[Recipe]:
        """Resolves a batch of ids in one round trip — used by the saved list
        so it never issues a query per saved recipe."""
        if not recipe_ids:
            return []

        cursor = self._collection.find({"_id": {"$in": recipe_ids}})
        found = {doc["_id"]: _to_recipe(doc) async for doc in cursor}
        # Preserve the caller's ordering (newest save first).
        return [found[rid] for rid in recipe_ids if rid in found]

    # --- Writes -----------------------------------------------------------

    def _decorate(
        self,
        doc: dict,
        *,
        created_by: str | None,
        fingerprint: str | None,
    ) -> dict:
        doc["random_key"] = random.random()
        doc["is_public"] = True
        doc["source"] = "generated"
        doc["created_by"] = created_by
        doc["input_fingerprint"] = fingerprint
        return doc

    async def insert(
        self,
        recipe: Recipe,
        created_by: str | None = None,
        fingerprint: str | None = None,
    ) -> Recipe:
        doc = self._decorate(
            _to_document(recipe), created_by=created_by, fingerprint=fingerprint
        )
        try:
            await self._collection.insert_one(doc)
        except DuplicateKeyError:
            await self._collection.replace_one({"_id": doc["_id"]}, doc)
        return recipe

    async def insert_many(
        self,
        recipes: list[Recipe],
        created_by: str | None = None,
        fingerprint: str | None = None,
    ) -> list[Recipe]:
        if not recipes:
            return []
        docs = [
            self._decorate(
                _to_document(recipe),
                created_by=created_by,
                fingerprint=fingerprint,
            )
            for recipe in recipes
        ]
        await self._collection.insert_many(docs)
        return recipes

    async def set_image(self, recipe_id: str, image_url: str) -> None:
        await self._collection.update_one(
            {"_id": recipe_id}, {"$set": {"image_url": image_url}}
        )

    async def count(self) -> int:
        return await self._collection.count_documents({})

    async def backfill_feed_fields(self) -> int:
        """Gives pre-existing documents the fields the feed now depends on.

        A recipe without a `random_key` sits outside the walk and would simply
        never be shown, so this runs at startup rather than as a migration
        somebody has to remember.
        """
        missing = self._collection.find(
            {"random_key": {"$exists": False}}, {"_id": 1, "ai_generated": 1}
        )
        updated = 0
        async for doc in missing:
            await self._collection.update_one(
                {"_id": doc["_id"]},
                {
                    "$set": {
                        "random_key": random.random(),
                        "is_public": True,
                        "source": (
                            "generated" if doc.get("ai_generated") else "seed"
                        ),
                    }
                },
            )
            updated += 1

        if updated:
            logger.info("Backfilled feed fields on %s recipes", updated)
        return updated
