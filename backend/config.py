"""Application configuration, loaded from the environment / .env.

Model IDs deliberately live here rather than in code so they can be changed
without touching the application (see section 14 of the brief).
"""

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # --- OpenAI ----------------------------------------------------------
    openai_api_key: str = ""

    # Text generation. gpt-5.6-terra balances intelligence and cost, which
    # suits structured recipe generation. Swap freely via the environment.
    openai_text_model: str = "gpt-5.6-terra"

    # Image generation.
    openai_image_model: str = "gpt-image-2"

    # Lower temperature keeps quantities and macros stable across runs.
    openai_temperature: float = 0.7

    # --- Generation behaviour --------------------------------------------
    recipes_per_request: int = 3

    # Forces generation off even when a key is present. The create flow then
    # reports that generation is unavailable, which is also what happens with
    # no key at all. Used by the test suite so no test can reach OpenAI.
    mock_ai: bool = False

    # --- Authentication ---------------------------------------------------

    # Signs access tokens. Generated per-process when unset, which is fine for
    # local development — but it means every restart invalidates outstanding
    # tokens, so production must set it explicitly.
    jwt_secret: str = ""

    # Short-lived, because it cannot be revoked once issued.
    access_token_minutes: int = 60

    # Long-lived, but revocable: it is stored server-side and rotated on every
    # use, so a stolen one stops working as soon as the real client refreshes.
    refresh_token_days: int = 30

    # Rejected below this length at registration.
    min_password_length: int = 8

    # --- Secret chat ------------------------------------------------------

    # The shared code that unlocks the hidden chat room. Empty turns the whole
    # feature off: the unlock endpoint answers 404, as if it did not exist.
    secret_chat_code: str = ""

    # How long an unlocked chat session lasts before the code is asked again.
    chat_token_hours: int = 12

    # Messages replayed to a client when it joins, newest last.
    chat_history_limit: int = 50

    # Longest message accepted, in characters after trimming.
    chat_max_message_length: int = 1000

    # --- Media ------------------------------------------------------------

    # Where generated recipe photos are written. Relative paths resolve
    # against the backend directory.
    #
    # Local disk is the MVP's object storage: it keeps multi-megabyte images
    # out of MongoDB documents and out of every feed response. Moving to S3
    # means rewriting `ImageService._persist_bytes` and nothing else.
    media_dir: str = "media"

    # --- MongoDB ----------------------------------------------------------
    mongodb_uri: str = "mongodb://localhost:27017"
    mongodb_db: str = "nutricook"

    # --- Server -----------------------------------------------------------
    host: str = "0.0.0.0"
    port: int = 8010

    # Permissive by default: this is a local development backend consumed by a
    # mobile client, which sends no browser Origin at all.
    cors_origins: list[str] = ["*"]

    @property
    def ai_enabled(self) -> bool:
        """True when real OpenAI calls should be attempted."""
        return bool(self.openai_api_key) and not self.mock_ai

    def model_post_init(self, _context) -> None:
        if not self.jwt_secret:
            # A random secret beats a hardcoded default that would ship as a
            # signing key everyone knows.
            import secrets

            object.__setattr__(self, "jwt_secret", secrets.token_urlsafe(48))


    @property
    def media_root(self) -> Path:
        path = Path(self.media_dir)
        if not path.is_absolute():
            path = Path(__file__).resolve().parent / path
        return path


@lru_cache
def get_settings() -> Settings:
    return Settings()
