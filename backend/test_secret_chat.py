"""Secret chat tests. Run with: .venv/bin/pytest -q

The unlock endpoint goes through TestClient like the rest of the suite. The
socket tests need a real server — Socket.IO cannot be driven through
TestClient — so a uvicorn instance is started on a free port in a background
thread, against the same throwaway database.
"""

import asyncio
import socket
import threading
import time
import uuid
from datetime import datetime

import pytest
import socketio
import uvicorn

import db
from config import get_settings
from security import (
    TokenError,
    create_access_token,
    create_chat_token,
    decode_access_token,
    decode_chat_token,
)
from services.secret_chat_service import get_secret_chat_service

CODE = "open-sesame-test"


def _run(coroutine):
    return asyncio.run(coroutine)


@pytest.fixture(autouse=True)
def chat_enabled(monkeypatch):
    """Every test starts with the chat switched on and nobody locked out."""
    monkeypatch.setattr(get_settings(), "secret_chat_code", CODE)
    get_secret_chat_service().reset()
    yield
    get_secret_chat_service().reset()


# --- Unlock -------------------------------------------------------------


def test_unlock_with_the_right_code_returns_a_chat_token(client):
    response = client.post("/api/secret-chat/unlock", json={"code": CODE})

    assert response.status_code == 200, response.text
    body = response.json()
    assert set(body) == {"token", "expires_in"}
    assert body["expires_in"] == get_settings().chat_token_hours * 3600
    decode_chat_token(body["token"])  # does not raise


def test_unlock_with_a_wrong_code_is_401(client):
    response = client.post("/api/secret-chat/unlock", json={"code": "nope"})
    assert response.status_code == 401


def test_unlock_locks_out_after_five_failures(client):
    for _ in range(5):
        response = client.post("/api/secret-chat/unlock", json={"code": "nope"})
        assert response.status_code == 401

    response = client.post("/api/secret-chat/unlock", json={"code": "nope"})
    assert response.status_code == 429

    # Even the right code is refused while locked out, so a lockout cannot be
    # used to confirm a guess.
    response = client.post("/api/secret-chat/unlock", json={"code": CODE})
    assert response.status_code == 429


def test_unlock_is_404_when_no_code_is_configured(client, monkeypatch):
    monkeypatch.setattr(get_settings(), "secret_chat_code", "")
    response = client.post("/api/secret-chat/unlock", json={"code": ""})
    assert response.status_code == 404


# --- Token separation ---------------------------------------------------


def test_an_access_token_is_not_a_chat_token():
    access_token, _ = create_access_token("user-1")
    with pytest.raises(TokenError):
        decode_chat_token(access_token)


def test_a_chat_token_is_not_an_access_token(client):
    chat_token, _ = create_chat_token()
    with pytest.raises(TokenError):
        decode_access_token(chat_token)

    response = client.get(
        "/api/users/me", headers={"Authorization": f"Bearer {chat_token}"}
    )
    assert response.status_code == 401


# --- Socket -------------------------------------------------------------


def _free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


@pytest.fixture(scope="module")
def server_url(mongo_test_db):
    from main import app

    port = _free_port()
    server = uvicorn.Server(
        uvicorn.Config(app, host="127.0.0.1", port=port, log_level="warning")
    )
    thread = threading.Thread(target=server.run, daemon=True)
    thread.start()

    deadline = time.monotonic() + 15
    while not server.started:
        if not thread.is_alive() or time.monotonic() > deadline:
            pytest.fail("The test server did not start")
        time.sleep(0.05)

    yield f"http://127.0.0.1:{port}"

    server.should_exit = True
    thread.join(timeout=10)


class _Client:
    """A socket client that records what it receives."""

    def __init__(self, client_id: str | None = None) -> None:
        self.sio = socketio.AsyncClient(reconnection=False)
        self.client_id = client_id or uuid.uuid4().hex
        self.events: dict[str, list] = {}
        self._arrived = asyncio.Event()
        for name in (
            "history",
            "presence",
            "message",
            "renamed",
            "error",
            "connect_error",
        ):
            self.sio.on(name, self._recorder(name))

    def _recorder(self, name):
        async def record(data):
            self.events.setdefault(name, []).append(data)
            self._arrived.set()

        return record

    async def connect(
        self, url: str, token: str, name: str = "Ada", client_id: object = ...
    ) -> None:
        cid = self.client_id if client_id is ... else client_id
        await self.sio.connect(
            url,
            auth={"token": token, "name": name, "client_id": cid},
            transports=["websocket"],
            wait_timeout=5,
        )

    async def wait_for(self, name: str, count: int = 1, timeout: float = 5):
        deadline = asyncio.get_running_loop().time() + timeout
        while len(self.events.get(name, [])) < count:
            remaining = deadline - asyncio.get_running_loop().time()
            if remaining <= 0:
                raise AssertionError(
                    f"Timed out waiting for {count} {name!r}; got {self.events}"
                )
            self._arrived.clear()
            try:
                await asyncio.wait_for(self._arrived.wait(), remaining)
            except asyncio.TimeoutError:
                pass
        return self.events[name]

    async def close(self) -> None:
        if self.sio.connected:
            await self.sio.disconnect()


def _token() -> str:
    token, _ = create_chat_token()
    return token


async def _messages_in_db() -> list[dict]:
    cursor = db.get_db()[db.SECRET_MESSAGES].find({}).sort("sent_at", 1)
    try:
        return [doc async for doc in cursor]
    finally:
        await db.close()


def test_socket_refuses_a_bad_token(server_url):
    async def scenario():
        chat = _Client()
        access_token, _ = create_access_token("user-1")
        for bad in ("not-a-token", access_token):
            with pytest.raises(socketio.exceptions.ConnectionError):
                await chat.connect(server_url, bad)
            # The refusal reason reaches the client as connect_error data.
            assert chat.events["connect_error"][-1] == {"message": "unauthorized"}
        await chat.close()

    _run(scenario())


def test_socket_refuses_a_bad_name(server_url):
    async def scenario():
        chat = _Client()
        for bad in ("   ", "x" * 25):
            with pytest.raises(socketio.exceptions.ConnectionError):
                await chat.connect(server_url, _token(), name=bad)
            # The refusal reason reaches the client as connect_error data.
            assert chat.events["connect_error"][-1] == {"message": "invalid_name"}
        await chat.close()

    _run(scenario())


def test_socket_greets_with_history_and_presence(server_url):
    async def seed():
        await db.get_db()[db.SECRET_MESSAGES].insert_many(
            [
                {
                    "name": "Old",
                    "text": f"message {i}",
                    "sent_at": datetime(2026, 1, 1, 0, 0, i),
                }
                for i in range(get_settings().chat_history_limit + 5)
            ]
        )
        await db.close()

    _run(seed())

    async def scenario():
        chat = _Client()
        try:
            await chat.connect(server_url, _token())
            [history] = await chat.wait_for("history")
            [presence] = await chat.wait_for("presence")
        finally:
            await chat.close()

        limit = get_settings().chat_history_limit
        assert len(history) == limit
        # The newest `limit`, oldest first.
        assert history[0]["text"] == "message 5"
        assert history[-1]["text"] == f"message {limit + 4}"
        assert set(history[0]) == {"id", "name", "sender_id", "text", "sent_at"}
        # Seeded like messages sent before sender ids existed.
        assert history[0]["sender_id"] is None
        assert history[0]["sent_at"] == "2026-01-01T00:00:05Z"
        assert presence == {"online": 1}

    _run(scenario())


def test_a_message_is_broadcast_to_everyone_and_saved(server_url):
    async def scenario():
        ada, bo = _Client(), _Client()
        try:
            await ada.connect(server_url, _token(), name="  Ada  ")
            await ada.wait_for("history")
            await bo.connect(server_url, _token(), name="Bo")
            await bo.wait_for("history")
            presence = await ada.wait_for("presence", count=2)
            assert presence[-1] == {"online": 2}

            await ada.sio.emit("send_message", {"text": "  hello there  "})
            [to_bo] = await bo.wait_for("message")
            [to_ada] = await ada.wait_for("message")

            assert to_bo == to_ada
            assert to_bo["name"] == "Ada"
            assert to_bo["sender_id"] == ada.client_id
            assert to_bo["text"] == "hello there"
            assert to_bo["id"]
            assert to_bo["sent_at"].endswith("Z")

            await bo.close()
            presence = await ada.wait_for("presence", count=3)
            assert presence[-1] == {"online": 1}
        finally:
            await ada.close()
            await bo.close()

        return to_bo

    sent = _run(scenario())

    [saved] = _run(_messages_in_db())
    assert str(saved["_id"]) == sent["id"]
    assert saved["name"] == "Ada"
    assert saved["sender_id"] == sent["sender_id"]
    assert saved["text"] == "hello there"


def test_socket_refuses_a_missing_or_malformed_client_id(server_url):
    async def scenario():
        chat = _Client()
        for bad in (None, "short", "has spaces in it", "x" * 65):
            with pytest.raises(socketio.exceptions.ConnectionError):
                await chat.connect(server_url, _token(), client_id=bad)
            assert chat.events["connect_error"][-1] == {"message": "invalid_client"}
        await chat.close()

    _run(scenario())


def test_rename_keeps_the_person_and_renames_their_messages(server_url):
    async def scenario():
        ada, bo = _Client(), _Client()
        try:
            await ada.connect(server_url, _token(), name="Ada")
            await ada.wait_for("history")
            await bo.connect(server_url, _token(), name="Bo")
            await bo.wait_for("history")
            await ada.wait_for("presence", count=2)

            await ada.sio.emit("send_message", {"text": "before"})
            await bo.wait_for("message")

            await ada.sio.emit("rename", {"name": "  Ada L  "})
            [renamed] = await bo.wait_for("renamed")
            assert renamed == {"sender_id": ada.client_id, "name": "Ada L"}
            await ada.wait_for("renamed")

            await ada.sio.emit("send_message", {"text": "after"})
            after = (await bo.wait_for("message", count=2))[-1]
            assert after["name"] == "Ada L"
            assert after["sender_id"] == ada.client_id

            # Same socket throughout: no leave/join, presence untouched.
            assert ada.sio.connected
            assert len(bo.events["presence"]) == 1

            await ada.sio.emit("rename", {"name": ""})
            [error] = await ada.wait_for("error")
            assert "Nicknames" in error["message"]
        finally:
            await ada.close()
            await bo.close()

    _run(scenario())

    saved = _run(_messages_in_db())
    assert [m["name"] for m in saved] == ["Ada L", "Ada L"]
    assert len({m["sender_id"] for m in saved}) == 1


def test_two_sockets_from_one_device_are_one_person(server_url):
    async def scenario():
        first = _Client(client_id="device-0001")
        second = _Client(client_id="device-0001")
        try:
            await first.connect(server_url, _token())
            await first.wait_for("history")
            await second.connect(server_url, _token())
            await second.wait_for("history")
            [presence] = await second.wait_for("presence")
            assert presence == {"online": 1}
        finally:
            await first.close()
            await second.close()

    _run(scenario())


def test_empty_and_over_length_messages_are_rejected(server_url):
    async def scenario():
        chat = _Client()
        try:
            await chat.connect(server_url, _token())
            await chat.wait_for("history")

            await chat.sio.emit("send_message", {"text": "   "})
            await chat.sio.emit(
                "send_message",
                {"text": "x" * (get_settings().chat_max_message_length + 1)},
            )
            errors = await chat.wait_for("error", count=2)
            assert all(isinstance(e["message"], str) and e["message"] for e in errors)
            assert "message" not in chat.events
        finally:
            await chat.close()

    _run(scenario())
    assert _run(_messages_in_db()) == []


def test_sending_too_fast_is_rate_limited(server_url):
    async def scenario():
        chat = _Client()
        try:
            await chat.connect(server_url, _token())
            await chat.wait_for("history")
            for i in range(6):
                await chat.sio.emit("send_message", {"text": f"spam {i}"})
            await chat.wait_for("message", count=5)
            [error] = await chat.wait_for("error")
            assert "quickly" in error["message"]
        finally:
            await chat.close()

    _run(scenario())
    assert len(_run(_messages_in_db())) == 5
