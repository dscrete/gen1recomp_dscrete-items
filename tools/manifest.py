#!/usr/bin/env python3
"""Small standalone sanity check for fields verified in Gen1Recomp v0.2.74.

The authoritative validator remains Gen1Recomp's Manifest.validate/modkit; this
exists only so the standalone repository catches an obviously incomplete package.
"""

from __future__ import annotations

import json
from pathlib import Path

EXPECTED = {
    "id": "gen1recomp_dscrete_items",
    "name": "DScrete Items",
    "api": 2,
    "entry": "main.lua",
    "profile": "content",
    "games": ["gen1"],
    "game_version": ">=0.2.74 <0.3.0",
}
REQUIRED_TYPES = {
    "id": str,
    "name": str,
    "version": str,
    "entry": str,
    "api": int,
}


class ManifestError(ValueError):
    pass


def load_manifest(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ManifestError(str(exc)) from exc
    if not isinstance(value, dict):
        raise ManifestError("manifest root must be an object")
    return value


def validate_compatibility(document: dict) -> None:
    errors: list[str] = []
    for key, typ in REQUIRED_TYPES.items():
        if not isinstance(document.get(key), typ) or document.get(key) in (None, ""):
            errors.append(f"{key}: required {typ.__name__}")
    for key, expected in EXPECTED.items():
        if document.get(key) != expected:
            errors.append(f"{key}: expected {expected!r}, got {document.get(key)!r}")
    if errors:
        raise ManifestError("manifest compatibility mismatch:\n- " + "\n- ".join(errors))
