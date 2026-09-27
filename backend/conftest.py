"""Test fixtures.

Tests run against a real MongoDB on a throwaway database rather than a mock,
so the schema validators and unique indexes are exercised for real. If no
server is reachable the whole suite skips with a clear reason instead of
failing misleadingly.
"""

import asyncio

import pytest
from fastapi.testclient import TestClient

TEST_DB = "nutricook_test"


def _mongo_available() -> bool:
    import db

    return asyncio.run(db.ping())


@pytest.fixture(scope="session", autouse=True)
def mongo_test_db():
    """Point the app at a test database for the whole session."""
    from config import get_settings

    get_settings.cache_clear()
    settings = get_settings()
    settings.mongodb_db = TEST_DB

    # No test may reach OpenAI. A developer's real key sits in .env, and
    # without this the generation tests would spend money, take minutes and
    # assert against whatever the model happened to say that run.
    settings.openai_api_key = ""
    settings.mock_ai = True

    # Deterministic, and fast enough that the auth tests are not dominated by
    # key derivation. Production cost comes from the default.
    settings.jwt_secret = "test-secret-not-used-anywhere-real"

    import db

    # Drop any cached clients so they are rebuilt against the test database.
    db._clients.clear()

    if not _mongo_available():
        pytest.skip(
            "MongoDB is not reachable — start it, then re-run. "
            "See the README for options.",
            allow_module_level=True,
        )

    asyncio.run(db.init_db())
    yield
    # Leave nothing behind.
    asyncio.run(_drop())
    asyncio.run(db.close())


async def _drop():
    import db

    await db.get_client().drop_database(TEST_DB)


@pytest.fixture(autouse=True)
def clean_collections():
    """Each test starts from an empty database."""
    import db

    async def _clear():
        database = db.get_db()
        for name in (
            db.RECIPES,
            db.USERS,
            db.SAVED_RECIPES,
            db.REFRESH_TOKENS,
            db.SECRET_MESSAGES,
        ):
            await database[name].delete_many({})

    asyncio.run(_clear())
    yield


@pytest.fixture
def client():
    from main import app

    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def seeded():
    """Inserts the seed feed and returns it."""
    import db
    from seed_db import SEED_RECIPES

    async def _insert():
        await db.get_db()[db.RECIPES].insert_many(
            [dict(r) for r in SEED_RECIPES]
        )

    asyncio.run(_insert())
    return SEED_RECIPES


@pytest.fixture
def register(client):
    """Registers an account and returns its tokens and user document.

    Going through the real endpoint rather than writing the document directly
    means the tests exercise hashing, the unique index and token issue on
    every run.
    """

    def _register(
        email: str = "chef@example.com", password: str = "cast-iron-42"
    ) -> dict:
        response = client.post(
            "/api/auth/register",
            json={
                "email": email,
                "password": password,
                "display_name": "Test Chef",
            },
        )
        assert response.status_code == 201, response.text
        return response.json()

    return _register


@pytest.fixture
def account(register):
    return register()


@pytest.fixture
def auth_headers(account):
    return {"Authorization": f"Bearer {account['access_token']}"}


@pytest.fixture
def other_headers(register):
    """A second, unrelated account — for proving isolation between users."""
    second = register(email="other@example.com", password="second-chef-99")
    return {"Authorization": f"Bearer {second['access_token']}"}
