"""Unlocking the secret chat. The chat itself runs over Socket.IO — see
`realtime.py`."""

from fastapi import APIRouter, Depends, HTTPException, Request, status

from models.secret_chat import UnlockRequest, UnlockResponse
from services.secret_chat_service import (
    ChatDisabled,
    InvalidCode,
    SecretChatService,
    TooManyAttempts,
    get_secret_chat_service,
)

router = APIRouter(prefix="/api/secret-chat", tags=["secret-chat"])


@router.post("/unlock", response_model=UnlockResponse)
async def unlock(
    body: UnlockRequest,
    request: Request,
    service: SecretChatService = Depends(get_secret_chat_service),
) -> UnlockResponse:
    client_ip = request.client.host if request.client else "unknown"
    try:
        return service.unlock(body.code, client_ip)
    except ChatDisabled:
        # With no code configured the feature should look absent, not locked.
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not Found")
    except TooManyAttempts:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many attempts. Try again later.",
        )
    except InvalidCode:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="That code is not right",
        )
