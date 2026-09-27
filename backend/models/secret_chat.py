"""Request, response and message shapes for the secret chat."""

from datetime import datetime, timezone

from pydantic import BaseModel, Field, field_serializer


class UnlockRequest(BaseModel):
    # No minimum: an empty guess is just a wrong one, and answering it with
    # a 401 like any other keeps the endpoint's behaviour uniform.
    code: str = Field(max_length=256)


class UnlockResponse(BaseModel):
    """The bearer for the socket handshake. It names nobody — the nickname is
    chosen when connecting."""

    token: str
    expires_in: int = Field(description="Token lifetime in seconds")


class ChatMessage(BaseModel):
    """One message as every client sees it, over history and live alike."""

    id: str
    name: str
    # Null only on messages sent before sender ids existed.
    sender_id: str | None = None
    text: str
    sent_at: datetime

    @field_serializer("sent_at")
    def _utc_iso(self, value: datetime) -> str:
        # MongoDB hands back naive datetimes that are UTC by construction.
        # Stamping the zone makes the string unambiguous for any client.
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
