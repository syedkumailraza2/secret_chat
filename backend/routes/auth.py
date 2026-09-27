"""Registration, login, token refresh and logout."""

import logging

from fastapi import APIRouter, Depends, HTTPException, status

from models.auth import (
    AuthResponse,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
)
from services.auth_service import (
    AuthService,
    EmailTaken,
    InvalidCredentials,
    InvalidRefreshToken,
    get_auth_service,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/auth", tags=["auth"])

# One message for both "no such address" and "wrong password". Telling them
# apart would let anyone test whether an address has an account here.
_BAD_CREDENTIALS = "Email or password is incorrect"


@router.post(
    "/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED
)
async def register(
    request: RegisterRequest,
    service: AuthService = Depends(get_auth_service),
) -> AuthResponse:
    try:
        return await service.register(request)
    except EmailTaken:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="That email is already registered",
        )


@router.post("/login", response_model=AuthResponse)
async def login(
    request: LoginRequest,
    service: AuthService = Depends(get_auth_service),
) -> AuthResponse:
    try:
        return await service.login(request.email, request.password)
    except InvalidCredentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_BAD_CREDENTIALS,
        )


@router.post("/refresh", response_model=AuthResponse)
async def refresh(
    request: RefreshRequest,
    service: AuthService = Depends(get_auth_service),
) -> AuthResponse:
    """Rotates the pair. The presented token is burned whether or not it was
    still valid, so replaying one never works twice."""
    try:
        return await service.refresh(request.refresh_token)
    except InvalidRefreshToken:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Your session has expired. Please sign in again.",
        )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    request: RefreshRequest,
    service: AuthService = Depends(get_auth_service),
) -> None:
    """Idempotent: logging out twice, or with a token that has already
    expired, still succeeds."""
    await service.logout(request.refresh_token)
