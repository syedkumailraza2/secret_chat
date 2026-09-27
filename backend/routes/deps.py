"""Shared route dependencies."""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from security import TokenError, decode_access_token

# auto_error=False so a missing header reaches our own handler and gets the
# same shaped response as a malformed one.
_bearer = HTTPBearer(auto_error=False)

_UNAUTHORISED = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Not authenticated",
    # The app keys its silent-refresh off a 401, and this header is what tells
    # a browser client the same thing.
    headers={"WWW-Authenticate": "Bearer"},
)


async def current_user_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> str:
    """The signed-in account, from the `Authorization: Bearer <jwt>` header.

    Everything a user owns — preferences, saves, authorship — hangs off this,
    so an endpoint that takes it cannot be reached without a valid token.
    """
    if credentials is None or not credentials.credentials:
        raise _UNAUTHORISED

    try:
        return decode_access_token(credentials.credentials)
    except TokenError:
        raise _UNAUTHORISED


async def optional_user_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> str | None:
    """For endpoints that work signed out but personalise when signed in.

    An invalid token is treated as absent rather than as an error: the public
    feed should still render for someone whose session has just lapsed.
    """
    if credentials is None or not credentials.credentials:
        return None
    try:
        return decode_access_token(credentials.credentials)
    except TokenError:
        return None
