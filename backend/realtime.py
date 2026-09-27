"""The secret chat's live half: one Socket.IO room on the default namespace.

Protocol:

- Connect with `auth = {"token": <from /api/secret-chat/unlock>,
  "name": <nickname>, "client_id": <stable per-device id>}`. A bad token is
  refused with "unauthorized", a bad nickname with "invalid_name", a missing or
  malformed id with "invalid_client".
- On joining, the client receives `history` (the latest messages, oldest
  first) and everyone receives `presence` = {"online": n}.
- `send_message` {"text": ...} is saved and broadcast to everyone, sender
  included, as `message`. A rejected one gets `error` {"message": ...} back to
  the sender alone.
- `rename` {"name": ...} changes the sender's nickname without reconnecting:
  their past messages take the new name and everyone receives `renamed`
  {"sender_id", "name"}. The id, not the name, is who someone is.
- Leaving broadcasts `presence` again.

Everyone connected is in the one room, so there is no room management: a
broadcast on the namespace is the room.
"""

import logging
import re
import time
from collections import deque

import socketio
from socketio.exceptions import ConnectionRefusedError

from config import get_settings
from security import TokenError, decode_chat_token
from services.secret_chat_repository import SecretChatRepository

logger = logging.getLogger(__name__)

settings = get_settings()

MAX_NAME_LENGTH = 24

# Client-generated device ids: random hex/uuid-ish, never shown to anyone.
_CLIENT_ID = re.compile(r"^[A-Za-z0-9_-]{8,64}$")

# About five messages per five seconds per socket: enough for a quick burst of
# short replies, not enough to flood the room.
RATE_LIMIT_MESSAGES = 5
RATE_LIMIT_SECONDS = 5.0

sio = socketio.AsyncServer(
    async_mode="asgi",
    # python-engineio only treats the bare string "*" as "any origin"; a list
    # holding "*" would be compared literally.
    cors_allowed_origins=(
        "*" if "*" in settings.cors_origins else settings.cors_origins
    ),
)

_repository = SecretChatRepository()

# sid -> send times inside the current rate-limit window. Also the set of
# sockets that made it through the handshake.
_sends: dict[str, deque[float]] = {}

# sid -> client id. Presence counts people, not sockets, so a device that
# briefly holds two connections (a reconnect overlapping the old one) is one.
_clients: dict[str, str] = {}


def _online() -> dict:
    return {"online": len(set(_clients.values()))}


def _clean_name(raw) -> str | None:
    if not isinstance(raw, str):
        return None
    name = raw.strip()
    if not 1 <= len(name) <= MAX_NAME_LENGTH:
        return None
    return name


@sio.event
async def connect(sid, environ, auth):
    auth = auth if isinstance(auth, dict) else {}
    try:
        decode_chat_token(auth.get("token"))
    except TokenError:
        raise ConnectionRefusedError("unauthorized")

    name = _clean_name(auth.get("name"))
    if name is None:
        raise ConnectionRefusedError("invalid_name")

    client_id = auth.get("client_id")
    if not isinstance(client_id, str) or not _CLIENT_ID.match(client_id):
        raise ConnectionRefusedError("invalid_client")

    history = await _repository.recent(get_settings().chat_history_limit)
    await sio.save_session(sid, {"name": name, "client_id": client_id})
    _sends[sid] = deque()
    _clients[sid] = client_id

    # The CONNECT packet only goes out once this handler returns, and a client
    # may drop events that arrive before it. So the greeting is sent from a
    # task that runs after the handshake has completed.
    sio.start_background_task(_greet, sid, [m.model_dump(mode="json") for m in history])


async def _greet(sid: str, history: list[dict]) -> None:
    await sio.emit("history", history, to=sid)
    await sio.emit("presence", _online())


@sio.event
async def send_message(sid, data):
    if sid not in _sends:
        return

    text = data.get("text") if isinstance(data, dict) else None
    text = text.strip() if isinstance(text, str) else ""
    limit = get_settings().chat_max_message_length

    if not text:
        await sio.emit("error", {"message": "Message is empty"}, to=sid)
        return
    if len(text) > limit:
        await sio.emit(
            "error",
            {"message": f"Message is longer than {limit} characters"},
            to=sid,
        )
        return

    now = time.monotonic()
    window = _sends[sid]
    while window and now - window[0] > RATE_LIMIT_SECONDS:
        window.popleft()
    if len(window) >= RATE_LIMIT_MESSAGES:
        await sio.emit(
            "error", {"message": "You're sending messages too quickly"}, to=sid
        )
        return
    window.append(now)

    session = await sio.get_session(sid)
    try:
        message = await _repository.add(session["client_id"], session["name"], text)
    except Exception:  # noqa: BLE001 - one bad write must not kill the socket
        logger.exception("Could not save a secret chat message")
        await sio.emit("error", {"message": "Message could not be sent"}, to=sid)
        return

    await sio.emit("message", message.model_dump(mode="json"))


@sio.event
async def rename(sid, data):
    if sid not in _sends:
        return

    name = _clean_name(data.get("name") if isinstance(data, dict) else None)
    if name is None:
        await sio.emit(
            "error",
            {"message": f"Nicknames are 1 to {MAX_NAME_LENGTH} characters"},
            to=sid,
        )
        return

    session = await sio.get_session(sid)
    if name == session["name"]:
        return
    session["name"] = name
    await sio.save_session(sid, session)

    client_id = session["client_id"]
    # The same device may have a second socket open (a reconnect in flight);
    # it must send under the new name too.
    for other, cid in list(_clients.items()):
        if other != sid and cid == client_id:
            async with sio.session(other) as s:
                s["name"] = name

    try:
        await _repository.rename(client_id, name)
    except Exception:  # noqa: BLE001 - live rename still stands
        logger.exception("Could not rename past secret chat messages")

    await sio.emit("renamed", {"sender_id": client_id, "name": name})


@sio.event
async def disconnect(sid, reason=None):
    _clients.pop(sid, None)
    if _sends.pop(sid, None) is not None:
        await sio.emit("presence", _online())
