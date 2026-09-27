"""User and saved-recipe persistence.

Password hashes live in the user document but never leave this module: every
return value is a `User`, which has no field to carry one.
"""

import uuid
from datetime import datetime, timezone

from pymongo import DESCENDING
from pymongo.errors import DuplicateKeyError

from db import SAVED_RECIPES, USERS, get_db
from models.user import User, UserPreferences


def _to_user(doc: dict) -> User:
    doc = dict(doc)
    doc["id"] = doc.pop("_id")
    doc.pop("password_hash", None)
    return User(**doc)


def normalise_email(email: str) -> str:
    """One canonical form, so `Ada@Example.COM` and `ada@example.com` are the
    same account rather than two."""
    return email.strip().lower()


class EmailAlreadyRegistered(Exception):
    pass


class UserRepository:
    @property
    def _users(self):
        return get_db()[USERS]

    @property
    def _saved(self):
        return get_db()[SAVED_RECIPES]

    # --- Accounts ---------------------------------------------------------

    async def create(
        self,
        *,
        email: str,
        password_hash: str,
        display_name: str,
        preferences: UserPreferences | None = None,
    ) -> User:
        """Registers an account. Raises if the address is already taken."""
        now = datetime.now(timezone.utc)
        doc = {
            "_id": uuid.uuid4().hex,
            "display_name": display_name,
            "email": normalise_email(email),
            "password_hash": password_hash,
            "preferences": (preferences or UserPreferences()).model_dump(),
            # Sign-up comes first and the preference steps follow, so a fresh
            # account has not finished onboarding unless it arrived with
            # preferences already answered.
            "onboarding_complete": preferences is not None,
            "created_at": now,
            "updated_at": now,
        }
        try:
            await self._users.insert_one(doc)
        except DuplicateKeyError as exc:
            raise EmailAlreadyRegistered(email) from exc
        return _to_user(doc)

    async def find_credentials(self, email: str) -> tuple[str, str] | None:
        """Returns `(user_id, password_hash)` for a login attempt.

        Deliberately narrow: the login path needs exactly these two fields and
        has no business loading preferences or anything else.
        """
        doc = await self._users.find_one(
            {"email": normalise_email(email)},
            {"password_hash": 1},
        )
        if doc is None or not doc.get("password_hash"):
            return None
        return doc["_id"], doc["password_hash"]

    async def get(self, user_id: str) -> User | None:
        doc = await self._users.find_one({"_id": user_id})
        return _to_user(doc) if doc else None

    async def email_exists(self, email: str) -> bool:
        return (
            await self._users.count_documents(
                {"email": normalise_email(email)}, limit=1
            )
            > 0
        )

    async def set_password_hash(self, user_id: str, password_hash: str) -> None:
        await self._users.update_one(
            {"_id": user_id},
            {
                "$set": {
                    "password_hash": password_hash,
                    "updated_at": datetime.now(timezone.utc),
                }
            },
        )

    # --- Preferences ------------------------------------------------------

    async def update_preferences(
        self,
        user_id: str,
        preferences: UserPreferences,
        onboarding_complete: bool | None = None,
    ) -> User | None:
        update: dict = {
            "preferences": preferences.model_dump(),
            "updated_at": datetime.now(timezone.utc),
        }
        if onboarding_complete is not None:
            update["onboarding_complete"] = onboarding_complete

        doc = await self._users.find_one_and_update(
            {"_id": user_id},
            {"$set": update},
            return_document=True,
        )
        return _to_user(doc) if doc else None

    # --- Saved recipes ----------------------------------------------------

    async def saved_recipe_ids(self, user_id: str) -> list[str]:
        """Newest first, matching how the saved grid reads."""
        cursor = self._saved.find({"user_id": user_id}).sort(
            "saved_at", DESCENDING
        )
        return [doc["recipe_id"] async for doc in cursor]

    async def save(self, user_id: str, recipe_id: str) -> None:
        try:
            await self._saved.insert_one(
                {
                    "user_id": user_id,
                    "recipe_id": recipe_id,
                    "saved_at": datetime.now(timezone.utc),
                }
            )
        except DuplicateKeyError:
            # The unique index makes saving twice a no-op rather than an error.
            pass

    async def unsave(self, user_id: str, recipe_id: str) -> None:
        await self._saved.delete_one(
            {"user_id": user_id, "recipe_id": recipe_id}
        )

    async def is_saved(self, user_id: str, recipe_id: str) -> bool:
        return (
            await self._saved.count_documents(
                {"user_id": user_id, "recipe_id": recipe_id}, limit=1
            )
            > 0
        )

    async def saved_ids_among(
        self, user_id: str, recipe_ids: list[str]
    ) -> set[str]:
        """Which of these does the user already have saved?

        One query for a whole page of feed cards, so the bookmark icons are
        correct on first paint instead of after a round trip each.
        """
        if not recipe_ids:
            return set()
        cursor = self._saved.find(
            {"user_id": user_id, "recipe_id": {"$in": recipe_ids}},
            {"recipe_id": 1},
        )
        return {doc["recipe_id"] async for doc in cursor}
