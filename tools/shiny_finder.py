"""Engine-independent Shiny Finder rules with injected public-API adapters."""

from __future__ import annotations

import json
from dataclasses import dataclass, replace
from enum import Enum
from pathlib import Path
from random import Random
from typing import Callable

from tools.runtime import RuntimeState

SHINY_FINDER_ID = "shiny_finder"


class EncounterClass(Enum):
    WILD = "wild"
    GIFT = "gift"
    TRADE = "trade"
    STATIC = "static"
    OWNED = "owned"
    TRAINER = "trainer"


@dataclass(frozen=True)
class FinderConfig:
    duration_steps: int
    chance_numerator: int
    chance_denominator: int


@dataclass(frozen=True)
class Encounter:
    encounter_class: EncounterClass
    species: int
    level: int
    moves: tuple[int, ...]
    dvs: int


class ShinyFinderError(ValueError):
    pass


def load_config(path: Path) -> FinderConfig:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
        raw = document[SHINY_FINDER_ID]
        config = FinderConfig(**raw)
    except (OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        raise ShinyFinderError(f"cannot load Shiny Finder configuration: {error}") from error
    values = (config.duration_steps, config.chance_numerator, config.chance_denominator)
    if any(type(value) is not int for value in values):
        raise ShinyFinderError("duration and chance values must be integers")
    if config.duration_steps <= 0:
        raise ShinyFinderError("duration_steps must be positive")
    if not 0 < config.chance_numerator <= config.chance_denominator:
        raise ShinyFinderError("shiny chance must satisfy 0 < numerator <= denominator")
    return config


def valid_shiny_dvs(predicate: Callable[[int], bool]) -> tuple[int, ...]:
    """Ask the runtime predicate which packed 16-bit DV values are shiny."""
    candidates = tuple(dvs for dvs in range(1 << 16) if predicate(dvs))
    if not candidates:
        raise ShinyFinderError("runtime shiny predicate accepted no DV combinations")
    return candidates


class ShinyFinder:
    def __init__(
        self,
        config: FinderConfig,
        shiny_predicate: Callable[[int], bool],
        rng: Random,
    ):
        self.config = config
        self.shiny_predicate = shiny_predicate
        self.rng = rng
        self.candidates = valid_shiny_dvs(shiny_predicate)

    def apply(self, encounter: Encounter, state: RuntimeState) -> Encounter:
        if state.active_field_effect != SHINY_FINDER_ID:
            return encounter
        if encounter.encounter_class is not EncounterClass.WILD:
            return encounter

        state.debug_rolls += 1
        roll = self.rng.randrange(self.config.chance_denominator)
        if roll >= self.config.chance_numerator:
            return encounter

        shiny_dvs = self.candidates[self.rng.randrange(len(self.candidates))]
        state.debug_successes += 1
        return replace(encounter, dvs=shiny_dvs)
