"""NutriCook backend.

Run locally:
    cd backend
    .venv/bin/uvicorn main:app --reload --port 8010
"""

import logging
from contextlib import asynccontextmanager

import socketio

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pymongo.errors import PyMongoError

import db
from config import get_settings
from realtime import sio
from routes import auth, health, recipes, secret_chat, users

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s %(name)s  %(message)s",
)

logger = logging.getLogger(__name__)

settings = get_settings()


@asynccontextmanager
async def lifespan(_: FastAPI):
    if settings.ai_enabled:
        logger.info(
            "AI generation enabled - text: %s, image: %s",
            settings.openai_text_model,
            settings.openai_image_model,
        )
    else:
        logger.warning(
            "AI generation DISABLED (no OPENAI_API_KEY). The create flow will "
            "report that generation is unavailable."
        )

    # Creating collections, validators and indexes is idempotent, so it runs
    # on every boot rather than needing a separate migration step.
    if await db.ping():
        await db.init_db()

        # Recipes written before the feed was shuffled have no random_key and
        # would sit outside the walk entirely, so they are brought up to date
        # here rather than in a migration step someone has to remember.
        from services.recipe_repository import RecipeRepository

        await RecipeRepository().backfill_feed_fields()

        count = await db.get_db()[db.RECIPES].count_documents({})
        logger.info("MongoDB connected - %s recipes in the feed", count)
        if count == 0:
            logger.warning(
                "The recipes collection is empty. Run `python seed_db.py` to "
                "populate the home feed."
            )
    else:
        logger.error(
            "MongoDB unreachable at %s - the API will start but return no "
            "recipes. Start MongoDB, then restart this server.",
            settings.mongodb_uri,
        )

    yield

    await db.close()


api = FastAPI(
    title="NutriCook API",
    description="Recipe generation and feed for the NutriCook app.",
    version="1.0.0",
    lifespan=lifespan,
)

api.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

@api.exception_handler(PyMongoError)
async def database_unavailable(request: Request, exc: PyMongoError):
    """A database that is down is a 503, not an unhandled crash.

    The driver's message is logged rather than returned — it can carry
    connection strings and internal hostnames.
    """
    logger.error("Database error on %s: %s", request.url.path, exc)
    return JSONResponse(
        status_code=503,
        content={"detail": "The recipe database is unavailable right now"},
    )


# Generated recipe photos. Served from here rather than inlined into the
# recipe documents, which is what keeps a feed page a few kilobytes instead of
# a few dozen megabytes.
settings.media_root.mkdir(parents=True, exist_ok=True)
api.mount(
    "/media",
    StaticFiles(directory=settings.media_root),
    name="media",
)

api.include_router(health.router)
api.include_router(auth.router)
api.include_router(recipes.router)
api.include_router(users.router)
api.include_router(secret_chat.router)

# Socket.IO answers under /socket.io/ and hands everything else — HTTP routes
# and the lifespan events that open and close MongoDB — to the FastAPI app.
# `app` stays the name uvicorn and the tests import.
app = socketio.ASGIApp(sio, other_asgi_app=api)
