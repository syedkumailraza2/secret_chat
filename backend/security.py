"""Password hashing and JSON Web Tokens.

Kept deliberately small and free of database or FastAPI imports so it can be
reasoned about — and tested — on its own. Everything that decides *policy*
(lifetimes, the signing secret) comes from config; everything here is
mechanism.
"""

import hashlib
import hmac
import logging
import secrets
import uuid
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from config import get_settings

logger = logging.getLogger(__name__)

ALGORITHM = "HS256"

# bcrypt silently truncates at 72 bytes, which would make two long passwords
# sharing a prefix equivalent. Rejecting is honest; the limit is far above any
# reasonable password.
MAX_PASSWORD_BYTES = 72


class TokenError(Exception):
    """A token was missing, malformed, expired or of the wrong kind."""


# --- Passwords ----------------------------------------------------------


def hash_password(password: str) -> str:
    """bcrypt with a per-password salt, returned as the standard modular
    crypt string (which carries the salt and cost factor with it)."""
    encoded = password.encode("utf-8")
    if len(encoded) > MAX_PASSWORD_BYTES:
        raise ValueError("Password is too long")
    return bcrypt.hashpw(encoded, bcrypt.gensalt()).decode("ascii")


def verify_password(password: str, password_hash: str) -> bool:
    """Constant-time check. Never raises — a malformed stored hash is simply
    a failed login, not a 500."""
    try:
        return bcrypt.checkpw(
            password.encode("utf-8")[:MAX_PASSWORD_BYTES],
            password_hash.encode("ascii"),
        )
    except (ValueError, TypeError):
        logger.warning("Stored password hash could not be parsed")
        return False


# --- Refresh token secrets ----------------------------------------------


def generate_refresh_secret() -> str:
    """The half of a refresh token the client keeps. 256 bits from the OS."""
    return secrets.token_urlsafe(32)


def hash_refresh_secret(secret: str) -> str:
    """Refresh tokens are stored hashed, so a database leak cannot be replayed.

    Plain SHA-256 rather than bcrypt: these are already high-entropy random
    strings, so there is nothing to brute-force, and a refresh happens on a
    request path where a deliberately slow hash would be felt.
    """
    return hashlib.sha256(secret.encode("utf-8")).hexdigest()


def refresh_secret_matches(secret: str, stored_hash: str) -> bool:
    return hmac.compare_digest(hash_refresh_secret(secret), stored_hash)


# --- Access tokens ------------------------------------------------------


def create_access_token(user_id: str) -> tuple[str, int]:
    """Returns the encoded JWT and its lifetime in seconds."""
    settings = get_settings()
    lifetime = timedelta(minutes=settings.access_token_minutes)
    now = datetime.now(timezone.utc)

    payload = {
        "sub": user_id,
        "type": "access",
        "iat": now,
        "exp": now + lifetime,
        "jti": uuid.uuid4().hex,
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=ALGORITHM)
    return token, int(lifetime.total_seconds())


def decode_access_token(token: str) -> str:
    """Returns the user id, or raises TokenError.

    `require` forces the claims to be present rather than merely valid when
    absent, which is the difference between a check and the appearance of one.
    """
    try:
        payload = jwt.decode(
            token,
            get_settings().jwt_secret,
            algorithms=[ALGORITHM],
            options={"require": ["exp", "sub", "type"]},
        )
    except jwt.ExpiredSignatureError as exc:
        raise TokenError("Token has expired") from exc
    except jwt.InvalidTokenError as exc:
        raise TokenError("Token is not valid") from exc

    if payload.get("type") != "access":
        # A refresh token presented as a bearer credential must not work.
        raise TokenError("Wrong token type")

    user_id = payload.get("sub")
    if not isinstance(user_id, str) or not user_id:
        raise TokenError("Token carries no subject")

    return user_id


# --- Secret chat tokens -------------------------------------------------
#
# Signed with the same secret as access tokens but stamped `type="chat"`, and
# each decoder insists on its own type. Knowing the chat code therefore never
# yields an account session, and an account session never opens the chat.


def create_chat_token() -> tuple[str, int]:
    """Returns the encoded JWT and its lifetime in seconds.

    Carries no identity: the chat is anonymous, and the nickname is chosen
    per connection rather than baked into the token.
    """
    settings = get_settings()
    lifetime = timedelta(hours=settings.chat_token_hours)
    now = datetime.now(timezone.utc)

    payload = {
        "sub": "secret-chat",
        "type": "chat",
        "iat": now,
        "exp": now + lifetime,
        "jti": uuid.uuid4().hex,
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=ALGORITHM)
    return token, int(lifetime.total_seconds())


def decode_chat_token(token: str) -> None:
    """Returns quietly for a valid chat token, or raises TokenError."""
    if not isinstance(token, str) or not token:
        raise TokenError("Token is missing")

    try:
        payload = jwt.decode(
            token,
            get_settings().jwt_secret,
            algorithms=[ALGORITHM],
            options={"require": ["exp", "type"]},
        )
    except jwt.ExpiredSignatureError as exc:
        raise TokenError("Token has expired") from exc
    except jwt.InvalidTokenError as exc:
        raise TokenError("Token is not valid") from exc

    if payload.get("type") != "chat":
        raise TokenError("Wrong token type")
