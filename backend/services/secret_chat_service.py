"""Unlocking the secret chat.

The room is guarded by one shared code. This module decides whether a guess
is right and whether the guesser has had too many goes; the socket layer only
ever sees the resulting token.
"""

import hmac
import logging
import time
from collections import deque

from config import get_settings
from models.secret_chat import UnlockResponse
from security import create_chat_token

logger = logging.getLogger(__name__)

# Five wrong guesses per address per ten minutes. The code is short and
# human-chosen, so without a limit it could simply be enumerated.
MAX_FAILURES = 5
FAILURE_WINDOW_SECONDS = 10 * 60


class ChatDisabled(Exception):
    """No code is configured, so there is no chat to unlock."""


class InvalidCode(Exception):
    pass


class TooManyAttempts(Exception):
    pass


class SecretChatService:
    def __init__(self) -> None:
        # In memory, per process: a restart forgives everyone, which is an
        # acceptable trade for a single-server hobby deployment.
        self._failures: dict[str, deque[float]] = {}

    def unlock(self, code: str, client_ip: str) -> UnlockResponse:
        expected = get_settings().secret_chat_code
        if not expected:
            raise ChatDisabled()

        now = time.monotonic()
        failures = self._failures.get(client_ip)
        if failures is not None:
            while failures and now - failures[0] > FAILURE_WINDOW_SECONDS:
                failures.popleft()
            # Checked before the code itself, so a locked-out caller learns
            # nothing — not even from a correct guess.
            if len(failures) >= MAX_FAILURES:
                raise TooManyAttempts()

        # Constant-time, over bytes so non-ASCII guesses cannot raise.
        if not hmac.compare_digest(code.encode("utf-8"), expected.encode("utf-8")):
            self._failures.setdefault(client_ip, deque()).append(now)
            logger.info("Wrong secret chat code from %s", client_ip)
            raise InvalidCode()

        self._failures.pop(client_ip, None)
        token, expires_in = create_chat_token()
        return UnlockResponse(token=token, expires_in=expires_in)

    def reset(self) -> None:
        """Forgets every recorded failure. Used by the tests."""
        self._failures.clear()


_service: SecretChatService | None = None


def get_secret_chat_service() -> SecretChatService:
    """FastAPI dependency."""
    global _service
    if _service is None:
        _service = SecretChatService()
    return _service
