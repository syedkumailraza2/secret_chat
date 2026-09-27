import logging

from fastapi import APIRouter, Depends, HTTPException, Query

from models.recipe import (
    BrowseResponse,
    FeedResponse,
    GenerateRequest,
    GenerateResponse,
    ImageResponse,
    Recipe,
)
from routes.deps import current_user_id, optional_user_id
from services.recipe_service import (
    AIUnavailable,
    GenerationFailed,
    RecipeNotFound,
    RecipeService,
    get_recipe_service,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/recipes", tags=["recipes"])

# The feed hands out ten at a time, which is roughly three screens of cards —
# enough that scrolling stays ahead of the next request.
DEFAULT_PAGE_SIZE = 10


@router.get("", response_model=FeedResponse)
async def list_recipes(
    category: str | None = Query(default=None),
    cursor: str | None = Query(
        default=None,
        description="From the previous page. Omit to start a new shuffle.",
    ),
    limit: int = Query(default=DEFAULT_PAGE_SIZE, ge=1, le=50),
    service: RecipeService = Depends(get_recipe_service),
) -> FeedResponse:
    """The public feed: seeded recipes and everything users have generated,
    shuffled per reader and paged. Never calls the AI."""
    page = await service.list_recipes(
        category=category, limit=limit, cursor=cursor
    )
    return FeedResponse(
        recipes=page.recipes,
        next_cursor=page.next_cursor,
        has_more=page.next_cursor is not None,
    )


@router.get("/browse", response_model=BrowseResponse)
async def browse_recipes(
    q: str | None = Query(default=None, max_length=120),
    category: str | None = Query(default=None),
    difficulty: str | None = Query(
        default=None, pattern="^(Easy|Medium|Hard)$"
    ),
    max_cooking_time: int | None = Query(default=None, ge=1, le=240),
    max_calories: int | None = Query(default=None, ge=0, le=5000),
    min_protein: int | None = Query(default=None, ge=0, le=500),
    mine: bool = Query(
        default=False, description="Only recipes the caller generated."
    ),
    sort: str = Query(
        default="recent", pattern="^(recent|quick|protein|calories)$"
    ),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=50),
    service: RecipeService = Depends(get_recipe_service),
    user_id: str | None = Depends(optional_user_id),
) -> BrowseResponse:
    """Everything the community has generated, filtered and sorted.

    Declared before `/{recipe_id}` so the literal path wins — otherwise
    "browse" would be read as a recipe id.
    """
    if mine and user_id is None:
        raise HTTPException(
            status_code=401, detail="Sign in to see your own recipes"
        )

    recipes, total = await service.browse(
        query=q,
        category=category,
        difficulty=difficulty,
        max_cooking_time=max_cooking_time,
        max_calories=max_calories,
        min_protein=min_protein,
        created_by=user_id if mine else None,
        sort=sort,
        page=page,
        page_size=page_size,
    )
    return BrowseResponse(
        recipes=recipes,
        page=page,
        page_size=page_size,
        total=total,
        has_more=page * page_size < total,
    )


@router.get("/{recipe_id}", response_model=Recipe)
async def get_recipe(
    recipe_id: str,
    service: RecipeService = Depends(get_recipe_service),
) -> Recipe:
    try:
        return await service.get_recipe(recipe_id)
    except RecipeNotFound:
        raise HTTPException(status_code=404, detail="Recipe not found")


@router.post("/generate", response_model=GenerateResponse)
async def generate_recipes(
    request: GenerateRequest,
    service: RecipeService = Depends(get_recipe_service),
    user_id: str = Depends(current_user_id),
) -> GenerateResponse:
    """Generate recipes from the user's ingredients and preferences.

    An identical earlier request is served from the cache, flagged with
    `cached` so the client can offer to generate fresh ones instead. Returns
    without images so results can render immediately; the client then requests
    each photo from the endpoint below.
    """
    try:
        recipes, cached = await service.generate(request, user_id=user_id)
    except AIUnavailable as exc:
        logger.error("Generation unavailable: %s", exc)
        raise HTTPException(
            status_code=503,
            detail="Recipe generation is not configured on this server",
        )
    except GenerationFailed as exc:
        # The provider's message is logged, never returned — the client shows
        # its own friendly copy.
        logger.error("Generation failed: %s", exc)
        raise HTTPException(
            status_code=503,
            detail="Recipe generation is unavailable right now",
        )
    return GenerateResponse(recipes=recipes, cached=cached)


@router.post("/{recipe_id}/generate-image", response_model=ImageResponse)
async def generate_image(
    recipe_id: str,
    service: RecipeService = Depends(get_recipe_service),
    user_id: str = Depends(current_user_id),
) -> ImageResponse:
    try:
        url = await service.generate_image(recipe_id)
    except RecipeNotFound:
        raise HTTPException(status_code=404, detail="Recipe not found")
    # A null url is a valid outcome: the client keeps its placeholder.
    return ImageResponse(recipe_id=recipe_id, image_url=url)
