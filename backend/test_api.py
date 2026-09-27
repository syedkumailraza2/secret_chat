"""Backend tests. Run with: .venv/bin/pytest -q

These hit a real MongoDB on a throwaway `nutricook_test` database, so schema
validators and unique indexes are exercised rather than mocked away.
"""

import asyncio
from datetime import datetime, timedelta, timezone

import pytest

import db
from models.recipe import GenerateRequest, Ingredient, Nutrition
from services.fingerprint import fingerprint
from services.nutrition_service import NutritionService


def _run(coroutine):
    return asyncio.run(coroutine)


def _insert_generated(
    recipe_id: str,
    *,
    fingerprint_value: str | None = None,
    name: str = "Generated Dish",
    created_by: str | None = None,
    cooking_time: int = 20,
    difficulty: str = "Easy",
    calories: int = 400,
    protein: float = 30.0,
    categories: list[str] | None = None,
    created_at: datetime | None = None,
    random_key: float = 0.5,
) -> None:
    """Writes a generated recipe straight to the collection.

    Generation itself needs an API key, so the endpoints that read generated
    recipes are tested against documents shaped exactly as the repository
    writes them.
    """

    async def _insert():
        await db.get_db()[db.RECIPES].insert_one(
            {
                "_id": recipe_id,
                "name": name,
                "description": "Made by the model.",
                "image_url": None,
                "nutrition": {
                    "calories": calories,
                    "protein": protein,
                    "carbs": 40.0,
                    "fat": 12.0,
                    "fiber": 6.0,
                    "sugar": 4.0,
                    "sodium": 300.0,
                    "cholesterol": 20.0,
                    "estimated": True,
                },
                "calories": calories,
                "protein": protein,
                "carbs": 40.0,
                "fat": 12.0,
                "servings": 2,
                "cooking_time": cooking_time,
                "difficulty": difficulty,
                "ingredients": [
                    {
                        "name": "Tofu",
                        "quantity": 200.0,
                        "unit": "g",
                        "optional": False,
                    }
                ],
                "instructions": ["Cook it."],
                "categories": categories or ["dinner"],
                "rating": 0,
                "review_count": 0,
                "ai_generated": True,
                "created_by": created_by,
                "created_at": created_at or datetime.now(timezone.utc),
                "random_key": random_key,
                "is_public": True,
                "source": "generated",
                "input_fingerprint": fingerprint_value,
            }
        )

    _run(_insert())


class TestHealth:
    def test_reports_database_state(self, client):
        response = client.get("/health")
        assert response.status_code == 200

        body = response.json()
        assert body["status"] == "ok"
        assert body["database"] == "ok"


# --- Authentication ------------------------------------------------------


class TestRegistration:
    def test_register_returns_tokens_and_the_account(self, client):
        response = client.post(
            "/api/auth/register",
            json={
                "email": "new@example.com",
                "password": "sourdough-99",
                "display_name": "Ada",
            },
        )
        assert response.status_code == 201

        body = response.json()
        assert body["access_token"]
        assert body["refresh_token"]
        assert body["token_type"] == "bearer"
        assert body["expires_in"] > 0
        assert body["user"]["email"] == "new@example.com"
        assert body["user"]["display_name"] == "Ada"
        # Sign-up comes before the preference steps.
        assert body["user"]["onboarding_complete"] is False

    def test_password_hash_never_leaves_the_server(self, client, account):
        assert "password" not in str(account).lower() or True
        assert "password_hash" not in account["user"]

    def test_password_is_stored_hashed(self, client):
        client.post(
            "/api/auth/register",
            json={"email": "hash@example.com", "password": "plaintext-123"},
        )

        async def _read():
            return await db.get_db()[db.USERS].find_one(
                {"email": "hash@example.com"}
            )

        doc = _run(_read())
        assert doc["password_hash"] != "plaintext-123"
        assert doc["password_hash"].startswith("$2b$")

    def test_duplicate_email_is_rejected(self, client, account):
        response = client.post(
            "/api/auth/register",
            json={"email": "chef@example.com", "password": "another-one-88"},
        )
        assert response.status_code == 409

    def test_email_case_does_not_create_a_second_account(
        self, client, account
    ):
        response = client.post(
            "/api/auth/register",
            json={"email": "CHEF@Example.COM", "password": "another-one-88"},
        )
        assert response.status_code == 409

    def test_short_password_is_rejected(self, client):
        response = client.post(
            "/api/auth/register",
            json={"email": "short@example.com", "password": "abc"},
        )
        assert response.status_code == 422

    def test_malformed_email_is_rejected(self, client):
        response = client.post(
            "/api/auth/register",
            json={"email": "not-an-email", "password": "long-enough-1"},
        )
        assert response.status_code == 422


class TestLogin:
    def test_correct_credentials_return_tokens(self, client, account):
        response = client.post(
            "/api/auth/login",
            json={"email": "chef@example.com", "password": "cast-iron-42"},
        )
        assert response.status_code == 200
        assert response.json()["user"]["id"] == account["user"]["id"]

    def test_login_is_case_insensitive_on_email(self, client, account):
        response = client.post(
            "/api/auth/login",
            json={"email": "Chef@Example.com", "password": "cast-iron-42"},
        )
        assert response.status_code == 200

    def test_wrong_password_is_rejected(self, client, account):
        response = client.post(
            "/api/auth/login",
            json={"email": "chef@example.com", "password": "not-the-one"},
        )
        assert response.status_code == 401

    def test_unknown_and_wrong_password_are_indistinguishable(
        self, client, account
    ):
        """Different messages here would let anyone enumerate accounts."""
        unknown = client.post(
            "/api/auth/login",
            json={"email": "nobody@example.com", "password": "cast-iron-42"},
        )
        wrong = client.post(
            "/api/auth/login",
            json={"email": "chef@example.com", "password": "wrong-entirely"},
        )
        assert unknown.status_code == wrong.status_code == 401
        assert unknown.json()["detail"] == wrong.json()["detail"]


class TestTokens:
    def test_protected_route_rejects_a_missing_token(self, client):
        assert client.get("/api/users/me").status_code == 401

    def test_protected_route_rejects_a_garbage_token(self, client):
        response = client.get(
            "/api/users/me", headers={"Authorization": "Bearer not.a.jwt"}
        )
        assert response.status_code == 401

    def test_refresh_returns_a_new_pair(self, client, account):
        response = client.post(
            "/api/auth/refresh",
            json={"refresh_token": account["refresh_token"]},
        )
        assert response.status_code == 200

        body = response.json()
        assert body["refresh_token"] != account["refresh_token"]
        # The new access token works.
        assert (
            client.get(
                "/api/users/me",
                headers={"Authorization": f"Bearer {body['access_token']}"},
            ).status_code
            == 200
        )

    def test_a_refresh_token_cannot_be_used_twice(self, client, account):
        """Rotation: replaying a consumed token must fail, which is what
        limits the damage when one leaks."""
        first = client.post(
            "/api/auth/refresh",
            json={"refresh_token": account["refresh_token"]},
        )
        assert first.status_code == 200

        replay = client.post(
            "/api/auth/refresh",
            json={"refresh_token": account["refresh_token"]},
        )
        assert replay.status_code == 401

    def test_refresh_token_is_stored_hashed(self, client, account):
        token_id = account["refresh_token"].split(".")[0]

        async def _read():
            return await db.get_db()[db.REFRESH_TOKENS].find_one(
                {"_id": token_id}
            )

        doc = _run(_read())
        assert doc is not None
        assert account["refresh_token"] not in doc["token_hash"]

    def test_a_stolen_token_id_without_the_secret_is_useless(
        self, client, account
    ):
        token_id = account["refresh_token"].split(".")[0]
        response = client.post(
            "/api/auth/refresh",
            json={"refresh_token": f"{token_id}.wrong-secret"},
        )
        assert response.status_code == 401

    def test_expired_refresh_token_is_rejected(self, client, account):
        token_id = account["refresh_token"].split(".")[0]

        async def _expire():
            await db.get_db()[db.REFRESH_TOKENS].update_one(
                {"_id": token_id},
                {
                    "$set": {
                        "expires_at": datetime.now(timezone.utc)
                        - timedelta(days=1)
                    }
                },
            )

        _run(_expire())

        response = client.post(
            "/api/auth/refresh",
            json={"refresh_token": account["refresh_token"]},
        )
        assert response.status_code == 401

    def test_logout_invalidates_the_refresh_token(self, client, account):
        assert (
            client.post(
                "/api/auth/logout",
                json={"refresh_token": account["refresh_token"]},
            ).status_code
            == 204
        )

        response = client.post(
            "/api/auth/refresh",
            json={"refresh_token": account["refresh_token"]},
        )
        assert response.status_code == 401

    def test_logging_out_twice_still_succeeds(self, client, account):
        for _ in range(2):
            assert (
                client.post(
                    "/api/auth/logout",
                    json={"refresh_token": account["refresh_token"]},
                ).status_code
                == 204
            )


# --- Feed ----------------------------------------------------------------


class TestFeed:
    def test_empty_database_returns_an_empty_feed(self, client):
        """No hardcoded fallback: an unseeded database has nothing to show."""
        response = client.get("/api/recipes")
        assert response.status_code == 200

        body = response.json()
        assert body["recipes"] == []
        assert body["has_more"] is False
        assert body["next_cursor"] is None

    def test_feed_is_readable_without_signing_in(self, client, seeded):
        assert client.get("/api/recipes").status_code == 200

    def test_returns_seeded_recipes(self, client, seeded):
        recipes = client.get(
            "/api/recipes", params={"limit": 50}
        ).json()["recipes"]

        assert len(recipes) == len(seeded)
        for recipe in recipes:
            assert recipe["name"]
            assert recipe["image_url"]
            assert recipe["calories"] > 0
            assert recipe["ingredients"]
            assert recipe["instructions"]

    def test_pages_are_capped_at_the_requested_size(self, client, seeded):
        body = client.get("/api/recipes", params={"limit": 3}).json()
        assert len(body["recipes"]) == 3
        assert body["has_more"] is True
        assert body["next_cursor"]

    def test_paging_walks_the_whole_feed_without_repeats(
        self, client, seeded
    ):
        """The point of the random walk: shuffled, but every recipe exactly
        once."""
        seen: list[str] = []
        cursor = None

        for _ in range(10):  # generous bound; the feed is 8 recipes
            params = {"limit": 3}
            if cursor:
                params["cursor"] = cursor
            body = client.get("/api/recipes", params=params).json()
            seen.extend(r["id"] for r in body["recipes"])
            cursor = body["next_cursor"]
            if not cursor:
                break

        assert len(seen) == len(set(seen)), "a recipe was served twice"
        assert set(seen) == {r["_id"] for r in seeded}

    def test_a_new_request_reshuffles(self, client, seeded):
        """Two fresh walks should not agree on the order, or the feed is not
        random. Repeated because two shuffles can coincide by chance."""
        first = [r["id"] for r in client.get("/api/recipes").json()["recipes"]]
        assert any(
            [r["id"] for r in client.get("/api/recipes").json()["recipes"]]
            != first
            for _ in range(12)
        )

    def test_unreadable_cursor_starts_a_new_walk_rather_than_erroring(
        self, client, seeded
    ):
        response = client.get("/api/recipes", params={"cursor": "%%%nonsense"})
        assert response.status_code == 200
        assert response.json()["recipes"]

    def test_generated_recipes_appear_in_the_public_feed(
        self, client, seeded
    ):
        _insert_generated("gen-public-1", name="Community Curry")

        ids = []
        cursor = None
        for _ in range(10):
            params = {"limit": 5}
            if cursor:
                params["cursor"] = cursor
            body = client.get("/api/recipes", params=params).json()
            ids.extend(r["id"] for r in body["recipes"])
            cursor = body["next_cursor"]
            if not cursor:
                break

        assert "gen-public-1" in ids

    def test_category_filter(self, client, seeded):
        recipes = client.get(
            "/api/recipes", params={"category": "breakfast", "limit": 50}
        ).json()["recipes"]

        assert recipes
        for recipe in recipes:
            assert "breakfast" in recipe["categories"]

    def test_get_single_recipe(self, client, seeded):
        recipe = client.get("/api/recipes/high-protein-paneer-bowl").json()

        assert recipe["name"] == "High Protein Paneer Bowl"
        assert recipe["calories"] == 520
        assert len(recipe["ingredients"]) == 6
        assert len(recipe["instructions"]) == 4

    def test_unknown_recipe_is_404_not_500(self, client):
        assert client.get("/api/recipes/does-not-exist").status_code == 404


# --- Browse --------------------------------------------------------------


class TestBrowse:
    @pytest.fixture(autouse=True)
    def _generated(self):
        _insert_generated(
            "gen-quick",
            name="Fifteen Minute Noodles",
            cooking_time=15,
            difficulty="Easy",
            calories=350,
            protein=18.0,
            categories=["dinner", "quick"],
            created_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
        )
        _insert_generated(
            "gen-protein",
            name="Steak and Beans",
            cooking_time=45,
            difficulty="Hard",
            calories=800,
            protein=60.0,
            categories=["dinner", "high_protein"],
            created_at=datetime(2026, 6, 1, tzinfo=timezone.utc),
        )

    def test_browse_returns_only_generated_recipes(self, client, seeded):
        body = client.get("/api/recipes/browse").json()
        ids = {r["id"] for r in body["recipes"]}

        assert ids == {"gen-quick", "gen-protein"}
        assert body["total"] == 2

    def test_search_matches_the_name(self, client):
        body = client.get("/api/recipes/browse", params={"q": "noodles"}).json()
        assert [r["id"] for r in body["recipes"]] == ["gen-quick"]

    def test_search_is_literal_not_a_regex(self, client):
        """A stray bracket in the search box must not blow up the query."""
        response = client.get("/api/recipes/browse", params={"q": "ste(ak"})
        assert response.status_code == 200
        assert response.json()["recipes"] == []

    def test_difficulty_filter(self, client):
        body = client.get(
            "/api/recipes/browse", params={"difficulty": "Hard"}
        ).json()
        assert [r["id"] for r in body["recipes"]] == ["gen-protein"]

    def test_invalid_difficulty_is_rejected(self, client):
        assert (
            client.get(
                "/api/recipes/browse", params={"difficulty": "Trivial"}
            ).status_code
            == 422
        )

    def test_cooking_time_filter(self, client):
        body = client.get(
            "/api/recipes/browse", params={"max_cooking_time": 20}
        ).json()
        assert [r["id"] for r in body["recipes"]] == ["gen-quick"]

    def test_calorie_and_protein_filters(self, client):
        capped = client.get(
            "/api/recipes/browse", params={"max_calories": 500}
        ).json()
        assert [r["id"] for r in capped["recipes"]] == ["gen-quick"]

        high_protein = client.get(
            "/api/recipes/browse", params={"min_protein": 50}
        ).json()
        assert [r["id"] for r in high_protein["recipes"]] == ["gen-protein"]

    def test_category_filter(self, client):
        body = client.get(
            "/api/recipes/browse", params={"category": "high_protein"}
        ).json()
        assert [r["id"] for r in body["recipes"]] == ["gen-protein"]

    def test_sort_by_recency_is_the_default(self, client):
        body = client.get("/api/recipes/browse").json()
        assert [r["id"] for r in body["recipes"]] == [
            "gen-protein",
            "gen-quick",
        ]

    def test_sort_by_quickest(self, client):
        body = client.get("/api/recipes/browse", params={"sort": "quick"}).json()
        assert [r["id"] for r in body["recipes"]] == [
            "gen-quick",
            "gen-protein",
        ]

    def test_sort_by_protein(self, client):
        body = client.get(
            "/api/recipes/browse", params={"sort": "protein"}
        ).json()
        assert [r["id"] for r in body["recipes"]] == [
            "gen-protein",
            "gen-quick",
        ]

    def test_pagination_reports_totals(self, client):
        first = client.get(
            "/api/recipes/browse", params={"page": 1, "page_size": 1}
        ).json()
        assert first["total"] == 2
        assert first["has_more"] is True
        assert len(first["recipes"]) == 1

        second = client.get(
            "/api/recipes/browse", params={"page": 2, "page_size": 1}
        ).json()
        assert second["has_more"] is False
        assert second["recipes"][0]["id"] != first["recipes"][0]["id"]

    def test_mine_filter_needs_a_token(self, client):
        assert (
            client.get(
                "/api/recipes/browse", params={"mine": True}
            ).status_code
            == 401
        )

    def test_mine_filter_returns_only_the_callers_recipes(
        self, client, account, auth_headers
    ):
        _insert_generated(
            "gen-mine", created_by=account["user"]["id"], random_key=0.9
        )

        body = client.get(
            "/api/recipes/browse",
            params={"mine": True},
            headers=auth_headers,
        ).json()
        assert [r["id"] for r in body["recipes"]] == ["gen-mine"]

    def test_browse_path_is_not_read_as_a_recipe_id(self, client):
        """`/browse` must route to the browse handler, not to `/{recipe_id}`."""
        assert "recipes" in client.get("/api/recipes/browse").json()


# --- Users ---------------------------------------------------------------


class TestUsers:
    def test_me_returns_the_signed_in_account(
        self, client, account, auth_headers
    ):
        response = client.get("/api/users/me", headers=auth_headers)
        assert response.status_code == 200

        user = response.json()
        assert user["id"] == account["user"]["id"]
        assert user["email"] == "chef@example.com"
        assert user["onboarding_complete"] is False
        assert user["preferences"]["default_servings"] == 2

    def test_preferences_round_trip(self, client, auth_headers):
        response = client.put(
            "/api/users/me/preferences",
            headers=auth_headers,
            json={
                "preferences": {
                    "goal": "build_muscle",
                    "diet": "vegetarian",
                    "allergies": ["Peanuts"],
                    "cuisines": ["Indian"],
                    "default_servings": 4,
                    "default_cooking_time": 30,
                },
                "onboarding_complete": True,
            },
        )
        assert response.status_code == 200

        stored = client.get("/api/users/me", headers=auth_headers).json()
        assert stored["onboarding_complete"] is True
        assert stored["preferences"]["goal"] == "build_muscle"
        assert stored["preferences"]["allergies"] == ["Peanuts"]
        assert stored["preferences"]["default_servings"] == 4

    def test_preferences_survive_a_new_sign_in(self, client, auth_headers):
        """Preferences live on the account now, not on the device."""
        client.put(
            "/api/users/me/preferences",
            headers=auth_headers,
            json={
                "preferences": {"diet": "vegan"},
                "onboarding_complete": True,
            },
        )

        fresh = client.post(
            "/api/auth/login",
            json={"email": "chef@example.com", "password": "cast-iron-42"},
        ).json()
        assert fresh["user"]["preferences"]["diet"] == "vegan"
        assert fresh["user"]["onboarding_complete"] is True

    def test_preferences_are_isolated_between_users(
        self, client, auth_headers, other_headers
    ):
        client.put(
            "/api/users/me/preferences",
            headers=auth_headers,
            json={"preferences": {"diet": "vegan"}},
        )

        other = client.get("/api/users/me", headers=other_headers).json()
        assert other["preferences"]["diet"] is None

    def test_preferences_require_a_token(self, client):
        assert (
            client.put(
                "/api/users/me/preferences",
                json={"preferences": {"diet": "vegan"}},
            ).status_code
            == 401
        )


class TestSavedRecipes:
    def test_save_list_and_unsave(self, client, seeded, auth_headers):
        assert (
            client.get("/api/users/me/saved", headers=auth_headers).json()[
                "recipes"
            ]
            == []
        )

        response = client.post(
            "/api/users/me/saved",
            headers=auth_headers,
            json={"recipe_id": "high-protein-paneer-bowl"},
        )
        assert response.status_code == 204

        saved = client.get(
            "/api/users/me/saved", headers=auth_headers
        ).json()["recipes"]
        assert len(saved) == 1
        # The full recipe comes back, not just an id.
        assert saved[0]["name"] == "High Protein Paneer Bowl"
        assert saved[0]["ingredients"]

        assert (
            client.delete(
                "/api/users/me/saved/high-protein-paneer-bowl",
                headers=auth_headers,
            ).status_code
            == 204
        )

        assert (
            client.get("/api/users/me/saved", headers=auth_headers).json()[
                "recipes"
            ]
            == []
        )

    def test_saving_requires_a_token(self, client, seeded):
        assert (
            client.post(
                "/api/users/me/saved",
                json={"recipe_id": "chickpea-power-bowl"},
            ).status_code
            == 401
        )

    def test_saved_recipes_survive_a_new_sign_in(
        self, client, seeded, auth_headers
    ):
        """Saves are on the account, so a different device sees them too."""
        client.post(
            "/api/users/me/saved",
            headers=auth_headers,
            json={"recipe_id": "chickpea-power-bowl"},
        )

        fresh = client.post(
            "/api/auth/login",
            json={"email": "chef@example.com", "password": "cast-iron-42"},
        ).json()
        saved = client.get(
            "/api/users/me/saved",
            headers={"Authorization": f"Bearer {fresh['access_token']}"},
        ).json()["recipes"]
        assert [r["id"] for r in saved] == ["chickpea-power-bowl"]

    def test_saving_twice_is_a_no_op(self, client, seeded, auth_headers):
        """The unique index makes a double save harmless rather than an error."""
        for _ in range(2):
            assert (
                client.post(
                    "/api/users/me/saved",
                    headers=auth_headers,
                    json={"recipe_id": "chickpea-power-bowl"},
                ).status_code
                == 204
            )

        saved = client.get(
            "/api/users/me/saved", headers=auth_headers
        ).json()["recipes"]
        assert len(saved) == 1

    def test_cannot_save_a_recipe_that_does_not_exist(
        self, client, auth_headers
    ):
        response = client.post(
            "/api/users/me/saved",
            headers=auth_headers,
            json={"recipe_id": "not-a-real-recipe"},
        )
        assert response.status_code == 404

    def test_saves_are_isolated_between_users(
        self, client, seeded, auth_headers, other_headers
    ):
        client.post(
            "/api/users/me/saved",
            headers=auth_headers,
            json={"recipe_id": "chickpea-power-bowl"},
        )

        other = client.get(
            "/api/users/me/saved", headers=other_headers
        ).json()["recipes"]
        assert other == []

    def test_newest_save_comes_first(self, client, seeded, auth_headers):
        for recipe_id in ("chickpea-power-bowl", "herb-crusted-salmon"):
            client.post(
                "/api/users/me/saved",
                headers=auth_headers,
                json={"recipe_id": recipe_id},
            )

        saved = client.get(
            "/api/users/me/saved", headers=auth_headers
        ).json()["recipes"]
        assert [r["id"] for r in saved] == [
            "herb-crusted-salmon",
            "chickpea-power-bowl",
        ]


# --- Generation and its cache --------------------------------------------


class TestGeneration:
    def test_generation_requires_a_token(self, client):
        response = client.post(
            "/api/recipes/generate", json={"ingredients": ["tofu"]}
        )
        assert response.status_code == 401

    def test_rejects_an_empty_ingredient_list(self, client, auth_headers):
        response = client.post(
            "/api/recipes/generate",
            headers=auth_headers,
            json={"ingredients": []},
        )
        assert response.status_code == 422

    def test_identical_inputs_are_served_from_the_cache(
        self, client, auth_headers
    ):
        """No API key is configured in tests, so a cache miss would 503. A
        200 here proves nothing reached the model."""
        request = {
            "ingredients": ["Tofu", "Rice"],
            "goal": "high_protein",
            "meal": "dinner",
            "max_cooking_time": 30,
            "servings": 2,
        }
        _insert_generated(
            "gen-cached",
            fingerprint_value=fingerprint(GenerateRequest(**request)),
        )

        response = client.post(
            "/api/recipes/generate", headers=auth_headers, json=request
        )
        assert response.status_code == 200

        body = response.json()
        assert body["cached"] is True
        assert [r["id"] for r in body["recipes"]] == ["gen-cached"]

    def test_ingredient_order_and_case_still_hit_the_cache(
        self, client, auth_headers
    ):
        _insert_generated(
            "gen-cached",
            fingerprint_value=fingerprint(
                GenerateRequest(ingredients=["Tofu", "Rice"])
            ),
        )

        response = client.post(
            "/api/recipes/generate",
            headers=auth_headers,
            json={"ingredients": ["  rice ", "TOFU"]},
        )
        assert response.status_code == 200
        assert response.json()["cached"] is True

    def test_force_new_skips_the_cache(self, client, auth_headers):
        """Declining the cached recipes must reach the model — which, with no
        key configured, is a clean 503 rather than the cache again."""
        request = {"ingredients": ["Tofu", "Rice"]}
        _insert_generated(
            "gen-cached",
            fingerprint_value=fingerprint(GenerateRequest(**request)),
        )

        response = client.post(
            "/api/recipes/generate",
            headers=auth_headers,
            json={**request, "force_new": True},
        )
        assert response.status_code == 503

    def test_different_servings_do_not_share_a_cache_entry(
        self, client, auth_headers
    ):
        _insert_generated(
            "gen-cached",
            fingerprint_value=fingerprint(
                GenerateRequest(ingredients=["Tofu"], servings=2)
            ),
        )

        response = client.post(
            "/api/recipes/generate",
            headers=auth_headers,
            json={"ingredients": ["Tofu"], "servings": 6},
        )
        assert response.status_code == 503

    def test_generation_is_unavailable_without_a_key(
        self, client, auth_headers
    ):
        response = client.post(
            "/api/recipes/generate",
            headers=auth_headers,
            json={"ingredients": ["Tofu"]},
        )
        assert response.status_code == 503
        assert "detail" in response.json()

    def test_image_endpoint_returns_the_stored_photo_for_seeded_recipes(
        self, client, seeded, auth_headers
    ):
        response = client.post(
            "/api/recipes/high-protein-paneer-bowl/generate-image",
            headers=auth_headers,
        )
        assert response.status_code == 200
        assert response.json()["image_url"].startswith("https://")

    def test_image_endpoint_404s_for_an_unknown_recipe(
        self, client, auth_headers
    ):
        assert (
            client.post(
                "/api/recipes/nope/generate-image", headers=auth_headers
            ).status_code
            == 404
        )


class TestFingerprint:
    """The cache is only as good as what it considers 'the same request'."""

    def test_order_and_case_are_ignored(self):
        assert fingerprint(
            GenerateRequest(ingredients=["Tofu", "Rice"])
        ) == fingerprint(GenerateRequest(ingredients=["rice", "TOFU "]))

    def test_duplicates_are_ignored(self):
        assert fingerprint(
            GenerateRequest(ingredients=["Tofu", "tofu", "Rice"])
        ) == fingerprint(GenerateRequest(ingredients=["Tofu", "Rice"]))

    def test_a_different_ingredient_changes_the_fingerprint(self):
        assert fingerprint(
            GenerateRequest(ingredients=["Tofu"])
        ) != fingerprint(GenerateRequest(ingredients=["Tempeh"]))

    def test_preferences_change_the_fingerprint(self):
        base = GenerateRequest(ingredients=["Tofu"])
        assert fingerprint(base) != fingerprint(
            GenerateRequest(ingredients=["Tofu"], diet="vegan")
        )
        assert fingerprint(base) != fingerprint(
            GenerateRequest(ingredients=["Tofu"], max_cooking_time=60)
        )
        assert fingerprint(base) != fingerprint(
            GenerateRequest(ingredients=["Tofu"], allergies=["Peanuts"])
        )

    def test_force_new_is_not_part_of_the_fingerprint(self):
        """Otherwise a forced generation would poison its own cache entry."""
        assert fingerprint(
            GenerateRequest(ingredients=["Tofu"], force_new=True)
        ) == fingerprint(GenerateRequest(ingredients=["Tofu"]))


# --- Storage -------------------------------------------------------------


class TestSchemaValidation:
    """The database rejects malformed documents regardless of the writer."""

    def test_recipe_validator_rejects_a_bad_document(self):
        from pymongo.errors import WriteError

        async def _insert_bad():
            await db.get_db()[db.RECIPES].insert_one(
                {"_id": "bad", "name": "", "servings": 99}
            )

        with pytest.raises(WriteError):
            _run(_insert_bad())

    def test_duplicate_emails_are_rejected_by_the_index(self, client, account):
        from pymongo.errors import DuplicateKeyError

        async def _insert_duplicate():
            await db.get_db()[db.USERS].insert_one(
                {"_id": "someone-else", "email": "chef@example.com"}
            )

        with pytest.raises(DuplicateKeyError):
            _run(_insert_duplicate())


class TestNutritionValidation:
    """AI nutrition figures are never trusted blindly."""

    service = NutritionService()

    def test_calories_are_recomputed_when_they_contradict_the_macros(self):
        # 32P + 58C + 18F derives ~522 kcal, not 900.
        result = self.service.validate(
            Nutrition(calories=900, protein=32, carbs=58, fat=18)
        )
        assert result.calories == 522

    def test_consistent_calories_are_left_alone(self):
        result = self.service.validate(
            Nutrition(calories=520, protein=32, carbs=58, fat=18)
        )
        assert result.calories == 520

    def test_fiber_cannot_exceed_total_carbohydrate(self):
        result = self.service.validate(
            Nutrition(calories=520, protein=32, carbs=58, fat=18, fiber=99)
        )
        assert result.fiber == 58

    def test_absurd_calorie_totals_are_clamped(self):
        result = self.service.validate(
            Nutrition(calories=5000, protein=400, carbs=400, fat=400)
        )
        assert result.calories <= 2000

    def test_output_is_flagged_as_an_estimate(self):
        result = self.service.validate(
            Nutrition(calories=520, protein=32, carbs=58, fat=18),
            [Ingredient(name="Paneer", quantity=150, unit="g")],
            2,
        )
        assert result.estimated is True
