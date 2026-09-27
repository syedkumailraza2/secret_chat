"""Prompt construction for recipe photography."""

STYLE = (
    "natural lighting, clean ceramic plate, appetizing presentation, "
    "realistic, premium food photography, shallow depth of field, "
    "warm off-white background, editorial cookbook aesthetic"
)


def build_image_prompt(
    *,
    name: str,
    description: str = "",
    key_ingredients: list[str] | None = None,
) -> str:
    """Describe one plated recipe for the image model.

    Built from the recipe itself so the photo matches the dish rather than
    being generic.
    """

    parts = [f"Professional food photography of {name}"]

    if key_ingredients:
        # A handful of ingredients grounds the image without over-constraining
        # the composition.
        parts.append(f"featuring {', '.join(key_ingredients[:4])}")

    if description:
        parts.append(description.rstrip("."))

    parts.append(STYLE)

    return ", ".join(parts) + "."
