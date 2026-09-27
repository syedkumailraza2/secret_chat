"""Recipe image generation.

Images are written to disk and served by this backend; what is stored on the
recipe is a short **relative** path like `/media/gen-abc123.png`.

Two decisions worth keeping:

- **Not a data URI.** The Images API hands back base64, and inlining that put
  a 2.4 MB string inside the recipe document — which then shipped in full with
  every feed page that happened to contain it. A ten-card page would have been
  roughly 24 MB.
- **Relative, not absolute.** The backend is reached at a different host from
  the simulator (`127.0.0.1`), the Android emulator (`10.0.2.2`) and a phone
  on the LAN, so it cannot know its own public address. The client already
  knows which base URL it used and resolves the path against it.

`_persist_bytes` is the seam for real object storage: upload there and return
the public URL instead.
"""

import base64
import logging
import re

import httpx
from openai import AsyncOpenAI

from config import get_settings
from models.recipe import Recipe
from prompts.image_prompt import build_image_prompt

logger = logging.getLogger(__name__)


class ImageServiceError(Exception):
    """Raised when an image could not be produced."""


# Recipe ids become filenames, so anything that could escape the media
# directory is stripped rather than trusted.
_UNSAFE = re.compile(r"[^A-Za-z0-9_-]")


def media_path_for(recipe_id: str) -> str:
    """The public path a recipe's photo is served at."""
    return f"/media/{_UNSAFE.sub('-', recipe_id)}.png"


class ImageService:
    def __init__(self) -> None:
        self.settings = get_settings()
        self._client: AsyncOpenAI | None = None

    def _get_client(self) -> AsyncOpenAI:
        if self._client is None:
            self._client = AsyncOpenAI(api_key=self.settings.openai_api_key)
        return self._client

    async def generate_for_recipe(self, recipe: Recipe) -> str:
        prompt = build_image_prompt(
            name=recipe.name,
            description=recipe.description,
            key_ingredients=[i.name for i in recipe.ingredients],
        )

        try:
            response = await self._get_client().images.generate(
                model=self.settings.openai_image_model,
                prompt=prompt,
                size="1024x1024",
                n=1,
            )
        except Exception as exc:  # noqa: BLE001
            logger.exception("Image generation failed for %s", recipe.id)
            raise ImageServiceError(str(exc)) from exc

        if not response.data:
            raise ImageServiceError("Image model returned no data")

        item = response.data[0]

        # The Images API may return either a hosted URL or inline base64
        # depending on the model, so handle both.
        if getattr(item, "url", None):
            return await self._persist(item.url, recipe.id)

        if getattr(item, "b64_json", None):
            return await self._persist_bytes(
                base64.b64decode(item.b64_json), recipe.id
            )

        raise ImageServiceError("Image model returned neither a URL nor data")

    async def _persist(self, url: str, recipe_id: str) -> str:
        """Downloads a provider-hosted image and stores it locally.

        The provider's own URLs expire within the hour, so keeping one would
        mean the photo silently disappears from the feed a little later.
        """
        try:
            async with httpx.AsyncClient(timeout=60) as client:
                response = await client.get(url)
                response.raise_for_status()
                return await self._persist_bytes(response.content, recipe_id)
        except Exception:  # noqa: BLE001
            logger.exception("Could not download the generated image")
            raise ImageServiceError("Image could not be downloaded")

    async def _persist_bytes(self, data: bytes, recipe_id: str) -> str:
        """Writes the image and returns the path it is served at.

        Local disk stands in for object storage. Swap the two lines that touch
        the filesystem for a bucket upload and the rest of the app is
        unaffected — callers only ever see the returned path.
        """
        root = self.settings.media_root
        root.mkdir(parents=True, exist_ok=True)

        path = media_path_for(recipe_id)
        (root / path.removeprefix("/media/")).write_bytes(data)

        logger.info("Stored %s (%.1f KB)", path, len(data) / 1024)
        return path
