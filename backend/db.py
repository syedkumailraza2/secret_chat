"""MongoDB connection, indexes and schema validators.

Uses PyMongo's native async client. (Motor, the old async driver, reached end
of life in 2026 — its functionality now lives in `pymongo.AsyncMongoClient`.)

Schema decisions follow from how the app actually reads:

- A recipe's ingredients, instructions and nutrition are always shown with the
  recipe and are bounded in size, so they are embedded. The detail screen is
  one document, one query.
- Preferences are 1:1 with a user and always loaded together, so they are
  embedded in the user document.
- Saves are a many-to-many that grows without bound, so they get their own
  collection rather than an ever-growing array on the user. The saved screen
  resolves them with a single `$in` on `_id`, which stays correct even when a
  recipe changes (an extended-reference cache would go stale).
"""

import asyncio
import logging

from pymongo import AsyncMongoClient
from pymongo.asynchronous.database import AsyncDatabase
from pymongo.errors import CollectionInvalid, ConnectionFailure

from config import get_settings

logger = logging.getLogger(__name__)

RECIPES = "recipes"
USERS = "users"
SAVED_RECIPES = "saved_recipes"
REFRESH_TOKENS = "refresh_tokens"
SECRET_MESSAGES = "secret_messages"

# AsyncMongoClient binds to the event loop it is created on, so the client is
# cached per loop rather than globally. A server has exactly one loop and so
# exactly one client; tests, which run setup and the app under different loops,
# get one each and still share the same database.
#
# Keyed by the loop object rather than its id(): ids are reused once a loop is
# collected, which would otherwise hand back a client bound to a dead loop.
_clients: dict[object, AsyncMongoClient] = {}

# Sentinel key for calls made outside any running loop.
_NO_LOOP = object()


def _loop_key() -> object:
    try:
        return asyncio.get_running_loop()
    except RuntimeError:
        return _NO_LOOP


def _prune_closed() -> None:
    """Drops clients whose loop has already been closed, so a long test run
    doesn't accumulate them."""
    for loop in [
        loop
        for loop in _clients
        if loop is not _NO_LOOP and getattr(loop, "is_closed", bool)()
    ]:
        _clients.pop(loop, None)


def get_client() -> AsyncMongoClient:
    key = _loop_key()
    client = _clients.get(key)
    if client is None:
        _prune_closed()
        settings = get_settings()
        client = AsyncMongoClient(
            settings.mongodb_uri,
            serverSelectionTimeoutMS=5000,
            uuidRepresentation="standard",
        )
        _clients[key] = client
    return client


def get_db() -> AsyncDatabase:
    return get_client()[get_settings().mongodb_db]


async def ping() -> bool:
    """True when the server is reachable. Used by /health."""
    try:
        await get_client().admin.command("ping")
        return True
    except ConnectionFailure:
        return False
    except Exception:  # noqa: BLE001 - health must never raise
        return False


async def close() -> None:
    """Closes the client belonging to the running loop."""
    client = _clients.pop(_loop_key(), None)
    if client is not None:
        await client.close()


# --- Validators ---------------------------------------------------------
#
# Applied at the database level so bad documents are rejected regardless of
# which client wrote them.

_NUTRITION_SCHEMA = {
    "bsonType": "object",
    "required": ["calories", "protein", "carbs", "fat"],
    "properties": {
        "calories": {"bsonType": ["int", "double"], "minimum": 0},
        "protein": {"bsonType": ["int", "double"], "minimum": 0},
        "carbs": {"bsonType": ["int", "double"], "minimum": 0},
        "fat": {"bsonType": ["int", "double"], "minimum": 0},
        "fiber": {"bsonType": ["int", "double"], "minimum": 0},
        "sugar": {"bsonType": ["int", "double"], "minimum": 0},
        "sodium": {"bsonType": ["int", "double"], "minimum": 0},
        "cholesterol": {"bsonType": ["int", "double"], "minimum": 0},
        "estimated": {"bsonType": "bool"},
    },
}

RECIPE_VALIDATOR = {
    "$jsonSchema": {
        "bsonType": "object",
        "required": ["_id", "name", "nutrition", "servings", "cooking_time"],
        "properties": {
            "_id": {"bsonType": "string"},
            "name": {"bsonType": "string", "minLength": 1},
            "description": {"bsonType": "string"},
            "image_url": {"bsonType": ["string", "null"]},
            "nutrition": _NUTRITION_SCHEMA,
            "servings": {"bsonType": "int", "minimum": 1, "maximum": 12},
            "cooking_time": {"bsonType": "int", "minimum": 1, "maximum": 240},
            "difficulty": {"enum": ["Easy", "Medium", "Hard"]},
            "ingredients": {
                "bsonType": "array",
                "items": {
                    "bsonType": "object",
                    "required": ["name"],
                    "properties": {
                        "name": {"bsonType": "string"},
                        "quantity": {"bsonType": ["int", "double"], "minimum": 0},
                        "unit": {"bsonType": "string"},
                        "optional": {"bsonType": "bool"},
                    },
                },
            },
            "instructions": {
                "bsonType": "array",
                "items": {"bsonType": "string"},
            },
            "categories": {
                "bsonType": "array",
                "items": {"bsonType": "string"},
            },
            "rating": {"bsonType": ["int", "double"], "minimum": 0, "maximum": 5},
            "review_count": {"bsonType": "int", "minimum": 0},
            "ai_generated": {"bsonType": "bool"},
            "created_by": {"bsonType": ["string", "null"]},
            "sort_order": {"bsonType": "int"},
            "created_at": {"bsonType": "date"},
            # Fixed random position in [0, 1). The feed pages through this
            # space from a random start, which is how it is shuffled without
            # re-sorting the collection on every request.
            "random_key": {
                "bsonType": ["int", "double"],
                "minimum": 0,
                "maximum": 1,
            },
            # Generated recipes join the public feed; the flag is the seam for
            # ever making one private.
            "is_public": {"bsonType": "bool"},
            # SHA-256 of the normalised generation inputs. Null on seeds.
            "input_fingerprint": {"bsonType": ["string", "null"]},
            "source": {"enum": ["seed", "generated"]},
        },
    }
}

USER_VALIDATOR = {
    "$jsonSchema": {
        "bsonType": "object",
        "required": ["_id"],
        "properties": {
            "_id": {"bsonType": "string"},
            "display_name": {"bsonType": "string"},
            "email": {"bsonType": ["string", "null"]},
            # bcrypt modular crypt string. Never leaves the repository layer.
            "password_hash": {"bsonType": ["string", "null"]},
            "preferences": {
                "bsonType": "object",
                "properties": {
                    "goal": {"bsonType": ["string", "null"]},
                    "diet": {"bsonType": ["string", "null"]},
                    "allergies": {
                        "bsonType": "array",
                        "items": {"bsonType": "string"},
                    },
                    "cuisines": {
                        "bsonType": "array",
                        "items": {"bsonType": "string"},
                    },
                    "default_servings": {
                        "bsonType": "int",
                        "minimum": 1,
                        "maximum": 12,
                    },
                    "default_cooking_time": {"bsonType": "int", "minimum": 1},
                },
            },
            "onboarding_complete": {"bsonType": "bool"},
            "created_at": {"bsonType": "date"},
            "updated_at": {"bsonType": "date"},
        },
    }
}

SAVED_VALIDATOR = {
    "$jsonSchema": {
        "bsonType": "object",
        "required": ["user_id", "recipe_id", "saved_at"],
        "properties": {
            "user_id": {"bsonType": "string"},
            "recipe_id": {"bsonType": "string"},
            "saved_at": {"bsonType": "date"},
        },
    }
}

REFRESH_TOKEN_VALIDATOR = {
    "$jsonSchema": {
        "bsonType": "object",
        "required": ["_id", "user_id", "token_hash", "expires_at"],
        "properties": {
            # The token id the client carries alongside the secret.
            "_id": {"bsonType": "string"},
            "user_id": {"bsonType": "string"},
            # SHA-256 of the secret half — the secret itself is never stored,
            # so a dump of this collection cannot be replayed.
            "token_hash": {"bsonType": "string"},
            "expires_at": {"bsonType": "date"},
            "created_at": {"bsonType": "date"},
            "revoked_at": {"bsonType": ["date", "null"]},
        },
    }
}

SECRET_MESSAGE_VALIDATOR = {
    "$jsonSchema": {
        "bsonType": "object",
        "required": ["name", "text", "sent_at"],
        "properties": {
            # Nickname chosen on joining; nothing ties it to an account.
            "name": {"bsonType": "string", "minLength": 1, "maxLength": 24},
            # Stable per-device id, so a nickname change renames the sender
            # instead of making them a new person. Messages sent before ids
            # existed have none.
            "sender_id": {"bsonType": "string", "minLength": 8, "maxLength": 64},
            "text": {"bsonType": "string", "minLength": 1, "maxLength": 1000},
            "sent_at": {"bsonType": "date"},
        },
    }
}

_COLLECTIONS = {
    RECIPES: RECIPE_VALIDATOR,
    USERS: USER_VALIDATOR,
    SAVED_RECIPES: SAVED_VALIDATOR,
    REFRESH_TOKENS: REFRESH_TOKEN_VALIDATOR,
    SECRET_MESSAGES: SECRET_MESSAGE_VALIDATOR,
}


async def init_db() -> None:
    """Create collections, validators and indexes. Safe to run repeatedly."""
    db = get_db()
    existing = set(await db.list_collection_names())

    for name, validator in _COLLECTIONS.items():
        if name in existing:
            # Keep the validator current without touching the documents.
            await db.command("collMod", name, validator=validator)
        else:
            try:
                await db.create_collection(name, validator=validator)
            except CollectionInvalid:
                pass

    # Feed queries filter on category and order by the curated sort_order.
    await db[RECIPES].create_index("categories")
    await db[RECIPES].create_index("sort_order")

    # The randomised feed walks random_key ascending, optionally within one
    # category. The compound index serves the filtered walk; random_key alone
    # serves the unfiltered one.
    await db[RECIPES].create_index("random_key")
    await db[RECIPES].create_index([("categories", 1), ("random_key", 1)])

    # Generation looks a fingerprint up before calling the model, so this is
    # on the hot path of every create. Sparse: seeds have no fingerprint, and
    # there is no reason to index a few hundred nulls.
    await db[RECIPES].create_index("input_fingerprint", sparse=True)

    # Browse sorts by recency, and "my generated recipes" filters by author.
    await db[RECIPES].create_index([("created_at", -1)])
    await db[RECIPES].create_index("created_by", sparse=True)

    # One index serves both jobs: it rejects duplicate saves and answers
    # "what has this user saved" from its user_id prefix.
    await db[SAVED_RECIPES].create_index(
        [("user_id", 1), ("recipe_id", 1)], unique=True
    )

    # One account per address. Partial, because pre-auth device users have no
    # email at all and several nulls would collide on a plain unique index.
    await db[USERS].create_index(
        "email",
        unique=True,
        partialFilterExpression={"email": {"$type": "string"}},
    )

    # Refresh lookups go by user; expired rows are reaped by the server rather
    # than by anything we have to remember to run.
    await db[REFRESH_TOKENS].create_index("user_id")
    await db[REFRESH_TOKENS].create_index("expires_at", expireAfterSeconds=0)

    # Joining the secret chat replays the latest messages, newest first off
    # this index and then reversed.
    await db[SECRET_MESSAGES].create_index([("sent_at", -1)])
    # A rename rewrites every message from one sender.
    await db[SECRET_MESSAGES].create_index("sender_id", sparse=True)

    logger.info("MongoDB ready: %s", get_settings().mongodb_db)
