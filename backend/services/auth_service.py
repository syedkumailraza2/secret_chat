"""Registration, login, refresh and logout.

Routes call into here; nothing above this layer touches password hashes or
token rows.
"""

import logging

import bcrypt

from models.auth import AuthResponse, RegisterRequest
from models.user import User
from security import create_access_token, hash_password, verify_password
from services.token_repository import RefreshTokenRepository
from services.user_repository import EmailAlreadyRegistered, UserRepository

logger = logging.getLogger(__name__)


class EmailTaken(Exception):
    pass


class InvalidCredentials(Exception):
    """Wrong address or wrong password — the caller must not be told which."""


class InvalidRefreshToken(Exception):
    pass


# Comparing against a real hash when no account exists keeps a failed login
# the same shape, and roughly the same duration, whether the address is
# registered or not. Without it, response time alone enumerates accounts.
_DUMMY_HASH = bcrypt.hashpw(b"timing-equaliser", bcrypt.gensalt()).decode(
    "ascii"
)


class AuthService:
    def __init__(self) -> None:
        self.users = UserRepository()
        self.tokens = RefreshTokenRepository()

    async def register(self, request: RegisterRequest) -> AuthResponse:
        try:
            user = await self.users.create(
                email=request.email,
                password_hash=hash_password(request.password),
                display_name=request.display_name,
                preferences=request.preferences,
            )
        except EmailAlreadyRegistered as exc:
            raise EmailTaken(request.email) from exc

        logger.info("Registered account %s", user.id)
        return await self._issue(user)

    async def login(self, email: str, password: str) -> AuthResponse:
        found = await self.users.find_credentials(email)
        user_id, password_hash = found or (None, _DUMMY_HASH)

        if not verify_password(password, password_hash) or user_id is None:
            raise InvalidCredentials()

        user = await self.users.get(user_id)
        if user is None:
            # The row vanished between the two reads. Treat as a failed login
            # rather than a 500.
            raise InvalidCredentials()

        return await self._issue(user)

    async def refresh(self, refresh_token: str) -> AuthResponse:
        """Exchanges a refresh token for a new pair, burning the old one."""
        user_id = await self.tokens.consume(refresh_token)
        if user_id is None:
            raise InvalidRefreshToken()

        user = await self.users.get(user_id)
        if user is None:
            raise InvalidRefreshToken()

        return await self._issue(user)

    async def logout(self, refresh_token: str) -> None:
        """Best effort: a token that is already gone is still a valid logout,
        so this never reports failure."""
        await self.tokens.revoke(refresh_token)

    async def _issue(self, user: User) -> AuthResponse:
        access_token, expires_in = create_access_token(user.id)
        refresh_token = await self.tokens.issue(user.id)
        return AuthResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_in=expires_in,
            user=user,
        )


_service: AuthService | None = None


def get_auth_service() -> AuthService:
    """FastAPI dependency."""
    global _service
    if _service is None:
        _service = AuthService()
    return _service
