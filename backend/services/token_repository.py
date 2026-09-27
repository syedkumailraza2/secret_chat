"""Refresh token persistence.

A refresh token the client holds looks like `<id>.<secret>`. Only the id is
stored in the clear; the secret is stored as a SHA-256 hash. That split means
a lookup is a single indexed `_id` hit rather than a scan over every row
trying to find a match.
"""

import uuid
from datetime import datetime, timedelta, timezone

from config import get_settings
from db import REFRESH_TOKENS, get_db
from security import (
    generate_refresh_secret,
    hash_refresh_secret,
    refresh_secret_matches,
)

# The separator cannot appear in a urlsafe base64 secret, so splitting is
# unambiguous.
_SEPARATOR = "."


class RefreshTokenRepository:
    @property
    def _collection(self):
        return get_db()[REFRESH_TOKENS]

    async def issue(self, user_id: str) -> str:
        """Mints a token and returns the single string the client stores."""
        token_id = uuid.uuid4().hex
        secret = generate_refresh_secret()
        now = datetime.now(timezone.utc)

        await self._collection.insert_one(
            {
                "_id": token_id,
                "user_id": user_id,
                "token_hash": hash_refresh_secret(secret),
                "expires_at": now
                + timedelta(days=get_settings().refresh_token_days),
                "created_at": now,
                "revoked_at": None,
            }
        )
        return f"{token_id}{_SEPARATOR}{secret}"

    async def consume(self, token: str) -> str | None:
        """Validates a token and burns it, returning the owning user id.

        Rotation on every use: the row is deleted as part of the check, so a
        token that is replayed — by the legitimate client racing itself, or by
        someone who stole it — finds nothing and fails.
        """
        parsed = self._parse(token)
        if parsed is None:
            return None
        token_id, secret = parsed

        # find_one_and_delete is atomic, so two simultaneous refreshes cannot
        # both succeed and hand out two live token families.
        doc = await self._collection.find_one_and_delete({"_id": token_id})
        if doc is None:
            return None

        if doc.get("revoked_at") is not None:
            return None

        if not refresh_secret_matches(secret, doc.get("token_hash", "")):
            return None

        expires_at = doc.get("expires_at")
        if expires_at is None:
            return None
        # Mongo stores naive UTC; compare like with like.
        if expires_at.replace(tzinfo=timezone.utc) <= datetime.now(
            timezone.utc
        ):
            return None

        return doc["user_id"]

    async def revoke(self, token: str) -> bool:
        """Logout. Deletes the row so the token stops working immediately."""
        parsed = self._parse(token)
        if parsed is None:
            return False
        token_id, secret = parsed

        doc = await self._collection.find_one({"_id": token_id})
        if doc is None:
            return False
        # Check the secret before deleting: a bare id must not be enough to
        # log somebody else out.
        if not refresh_secret_matches(secret, doc.get("token_hash", "")):
            return False

        await self._collection.delete_one({"_id": token_id})
        return True

    async def revoke_all_for_user(self, user_id: str) -> int:
        """Every session, gone — the lever to pull after a password change."""
        result = await self._collection.delete_many({"user_id": user_id})
        return result.deleted_count

    @staticmethod
    def _parse(token: str) -> tuple[str, str] | None:
        token_id, separator, secret = token.partition(_SEPARATOR)
        if not separator or not token_id or not secret:
            return None
        return token_id, secret
