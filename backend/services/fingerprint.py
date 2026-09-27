"""Fingerprinting generation inputs so identical requests can be reused.

Two people who pick the same pantry and the same preferences should not each
pay for a model call. The fingerprint is what makes "the same" decidable, so
the normalisation below is the whole substance of the feature: too strict and
nothing ever matches, too loose and people get recipes that do not honour what
they asked for.
"""

import hashlib
import json

from models.recipe import GenerateRequest


def _normalise_terms(values: list[str]) -> list[str]:
    """Case, surrounding space, duplicates and order are all noise.

    "Chicken", "chicken " and "chicken" are one ingredient, and picking
    tomatoes before onions is the same pantry as the reverse.
    """
    cleaned = {value.strip().lower() for value in values if value.strip()}
    return sorted(cleaned)


def fingerprint(request: GenerateRequest) -> str:
    """A stable SHA-256 over everything that changes the resulting recipes.

    Servings and cooking time are included deliberately: the same ingredients
    for two people in fifteen minutes is a different dish from the same
    ingredients for six in an hour, so they must not share a cache entry.
    """
    payload = {
        "ingredients": _normalise_terms(request.ingredients),
        "goal": (request.goal or "").strip().lower(),
        "meal": (request.meal or "").strip().lower(),
        "max_cooking_time": int(request.max_cooking_time),
        "servings": int(request.servings),
        "diet": (request.diet or "").strip().lower(),
        "allergies": _normalise_terms(request.allergies),
        "cuisines": _normalise_terms(request.cuisines),
    }

    # sort_keys and a fixed separator so the same inputs always serialise to
    # the same bytes, whatever order the dict happened to be built in.
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()
