"""Secret chat message persistence."""

from datetime import datetime, timezone

from pymongo import DESCENDING

from db import SECRET_MESSAGES, get_db
from models.secret_chat import ChatMessage


def _to_message(doc: dict) -> ChatMessage:
    return ChatMessage(
        id=str(doc["_id"]),
        name=doc["name"],
        sender_id=doc.get("sender_id"),
        text=doc["text"],
        sent_at=doc["sent_at"],
    )


class SecretChatRepository:
    @property
    def _messages(self):
        return get_db()[SECRET_MESSAGES]

    async def add(self, sender_id: str, name: str, text: str) -> ChatMessage:
        # Millisecond precision is all BSON dates keep, so the value is
        # truncated up front: what is broadcast now matches what history
        # replays later.
        now = datetime.now(timezone.utc)
        now = now.replace(microsecond=now.microsecond // 1000 * 1000)

        doc = {"name": name, "sender_id": sender_id, "text": text, "sent_at": now}
        result = await self._messages.insert_one(doc)
        doc["_id"] = result.inserted_id
        return _to_message(doc)

    async def rename(self, sender_id: str, name: str) -> int:
        """Puts the sender's new nickname on everything they have sent."""
        result = await self._messages.update_many(
            {"sender_id": sender_id}, {"$set": {"name": name}}
        )
        return result.modified_count

    async def recent(self, limit: int) -> list[ChatMessage]:
        """The latest `limit` messages, oldest first — the order a chat reads.

        Fetched newest first so the index bounds the read, then reversed.
        """
        cursor = (
            self._messages.find({})
            .sort([("sent_at", DESCENDING), ("_id", DESCENDING)])
            .limit(limit)
        )
        messages = [_to_message(doc) async for doc in cursor]
        messages.reverse()
        return messages
