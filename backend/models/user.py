"""User and saved-recipe schemas.

Identity for the MVP is a device-generated id the app sends as `X-User-Id`.
There is no auth yet; swapping in real accounts means changing how that id is
established, not how anything below is stored.
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class UserPreferences(BaseModel):
    """Embedded in the user document — 1:1 and always read together."""

    goal: Optional[str] = None
    diet: Optional[str] = None
    allergies: list[str] = []
    cuisines: list[str] = []
    default_servings: int = Field(default=2, ge=1, le=12)
    default_cooking_time: int = Field(default=30, ge=1, le=240)


class User(BaseModel):
    id: str
    display_name: str = "NutriCook Chef"
    email: Optional[str] = None
    preferences: UserPreferences = UserPreferences()
    onboarding_complete: bool = False
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class UpdatePreferencesRequest(BaseModel):
    preferences: UserPreferences
    onboarding_complete: Optional[bool] = None


class SaveRecipeRequest(BaseModel):
    recipe_id: str
