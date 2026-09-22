"""Validation helpers for the DScrete Items compatibility manifest."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


EXPECTED_COMPATIBILITY: dict[str, Any] = {
    "api": 2,
    "games": ["gen1"],
    "game_version": ">=0.2.74 <0.3.0",
}


class ManifestError(ValueError):
    """Raised when the mod manifest violates its pinned compatibility contract."""


def load_manifest(path: Path) -> dict[str, Any]:
    """Load a JSON manifest and require an object at its root."""
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise ManifestError(f"manifest not found: {path}") from error
    except json.JSONDecodeError as error:
        raise ManifestError(
            f"invalid JSON in {path}:{error.lineno}:{error.colno}: {error.msg}"
        ) from error

    if not isinstance(document, dict):
        raise ManifestError("manifest root must be a JSON object")
    return document


def validate_compatibility(document: dict[str, Any]) -> None:
    """Validate only the compatibility fields confirmed for the initial manifest.

    Other Mod API fields remain the responsibility of the tagged upstream schema.
    This intentionally avoids guessing at fields that have not been verified against
    Gen1Recomp v0.2.74.
    """
    errors = []
    for field, expected in EXPECTED_COMPATIBILITY.items():
        actual = document.get(field)
        if actual != expected:
            errors.append(f"{field}: expected {expected!r}, got {actual!r}")

    if errors:
        raise ManifestError("manifest compatibility mismatch:\n- " + "\n- ".join(errors))
