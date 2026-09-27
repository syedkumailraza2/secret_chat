"""Request and response shapes for registration, login and refresh."""

from pydantic import BaseModel, EmailStr, Field, field_validator

from models.user import User, UserPreferences


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=72)
    display_name: str = Field(default="NutriCook Chef", max_length=60)

    # Onboarding runs after sign-up, so this is normally absent — but keeping
    # it accepted means a client can create the account and store the first
    # answers in one round trip.
    preferences: UserPreferences | None = None

    @field_validator("display_name")
    @classmethod
    def _tidy_name(cls, value: str) -> str:
        cleaned = value.strip()
        return cleaned or "NutriCook Chef"

    @field_validator("password")
    @classmethod
    def _password_is_not_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Password cannot be blank")
        return value


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=72)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=1)


class TokenPair(BaseModel):
    """What the client stores after a successful register, login or refresh."""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int = Field(description="Access token lifetime in seconds")


class AuthResponse(TokenPair):
    """Tokens plus the account, so the app can render immediately without a
    follow-up call to /users/me."""

    user: User
