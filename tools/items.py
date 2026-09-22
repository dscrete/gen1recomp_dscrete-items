"""Declarative DScrete item definitions and validation."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

OWNERSHIPS = frozenset({"PERMANENT", "REUSABLE", "CONSUMABLE", "CONSUMABLE_PAIR"})
FAMILIES = frozenset(
    {"OAK_PALLET", "SILPH_CO", "CINNABAR_LAB", "SAFARI_ZONE", "ROCKET", "EXPLORATION"}
)
EFFECT_KINDS = frozenset({"FIELD_EFFECT", "TOOL", "TRAINER", "CAPTURE", "BATTLE", "POKEMON", "TRAVEL"})
ID_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")


class ItemDefinitionError(ValueError):
    pass


@dataclass(frozen=True)
class ItemDefinition:
    id: str
    name: str
    ownership: str
    family: str
    effect_kind: str


def load_items(path: Path) -> tuple[ItemDefinition, ...]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ItemDefinitionError(f"cannot load item definitions: {error}") from error
    if not isinstance(raw, list):
        raise ItemDefinitionError("item definitions must be a JSON array")
    required = set(ItemDefinition.__annotations__)
    items = []
    for index, entry in enumerate(raw):
        if not isinstance(entry, dict) or set(entry) != required:
            raise ItemDefinitionError(f"item {index} must contain exactly {sorted(required)}")
        items.append(ItemDefinition(**entry))
    validate_items(items)
    return tuple(items)


def validate_items(items: list[ItemDefinition]) -> None:
    seen: set[str] = set()
    for item in items:
        if not ID_PATTERN.fullmatch(item.id):
            raise ItemDefinitionError(f"invalid item id: {item.id!r}")
        if item.id in seen:
            raise ItemDefinitionError(f"duplicate item id: {item.id}")
        seen.add(item.id)
        if not item.name.strip():
            raise ItemDefinitionError(f"{item.id}: name is empty")
        if item.ownership not in OWNERSHIPS:
            raise ItemDefinitionError(f"{item.id}: unknown ownership {item.ownership!r}")
        if item.family not in FAMILIES:
            raise ItemDefinitionError(f"{item.id}: unknown family {item.family!r}")
        if item.effect_kind not in EFFECT_KINDS:
            raise ItemDefinitionError(f"{item.id}: unknown effect kind {item.effect_kind!r}")
