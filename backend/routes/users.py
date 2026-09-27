"""User profile, preferences and saved recipes.

Every endpoint here is behind a bearer token, so `user_id` is always a real
account rather than whatever id a client claimed to be.
"""

from fastapi import APIRouter, Depends, HTTPException

from models.recipe import RecipeListResponse
from models.user import SaveRecipeRequest, UpdatePreferencesRequest, User
from routes.deps import current_user_id
from services.recipe_service import (
    RecipeNotFound,
    RecipeService,
    get_recipe_service,
)
from services.user_repository import UserRepository

router = APIRouter(prefix="/api/users", tags=["users"])

_users = UserRepository()

_ACCOUNT_GONE = HTTPException(
    status_code=404, detail="This account no longer exists"
)


@router.get("/me", response_model=User)
async def get_me(user_id: str = Depends(current_user_id)) -> User:
    user = await _users.get(user_id)
    if user is None:
        # A valid token for a deleted account. 404 rather than 401: the
        # credential is fine, the thing it points at is not.
        raise _ACCOUNT_GONE
    return user


@router.put("/me/preferences", response_model=User)
async def update_preferences(
    request: UpdatePreferencesRequest,
    user_id: str = Depends(current_user_id),
) -> User:
    user = await _users.update_preferences(
        user_id,
        request.preferences,
        onboarding_complete=request.onboarding_complete,
    )
    if user is None:
        raise _ACCOUNT_GONE
    return user


@router.get("/me/saved", response_model=RecipeListResponse)
async def list_saved(
    user_id: str = Depends(current_user_id),
    service: RecipeService = Depends(get_recipe_service),
) -> RecipeListResponse:
    return RecipeListResponse(recipes=await service.saved_recipes(user_id))


@router.post("/me/saved", status_code=204)
async def save_recipe(
    request: SaveRecipeRequest,
    user_id: str = Depends(current_user_id),
    service: RecipeService = Depends(get_recipe_service),
) -> None:
    try:
        await service.save_recipe(user_id, request.recipe_id)
    except RecipeNotFound:
        raise HTTPException(status_code=404, detail="Recipe not found")


@router.delete("/me/saved/{recipe_id}", status_code=204)
async def unsave_recipe(
    recipe_id: str,
    user_id: str = Depends(current_user_id),
    service: RecipeService = Depends(get_recipe_service),
) -> None:
    await service.unsave_recipe(user_id, recipe_id)
