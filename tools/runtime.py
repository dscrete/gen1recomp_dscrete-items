"""Engine-independent state rules shared by DScrete item adapters."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum, auto


class ApplyResult(Enum):
    CANCELLED = auto()
    INVALID_CONTEXT = auto()
    FAILED = auto()
    APPLIED = auto()


@dataclass
class SaveState:
    schema_version: int = 1
    permanent_unlocks: set[str] = field(default_factory=set)
    reusable_state: dict[str, int] = field(default_factory=dict)
    placed_beacon: tuple[str, int, int] | None = None


@dataclass
class RuntimeState:
    active_field_effect: str | None = None
    remaining_steps: int = 0
    selected_species: int | None = None
    pending_exp_multiplier: int | None = None
    debug_rolls: int = 0
    debug_successes: int = 0

    def clear(self) -> None:
        self.active_field_effect = None
        self.remaining_steps = 0
        self.selected_species = None
        self.pending_exp_multiplier = None
        self.debug_rolls = 0
        self.debug_successes = 0


@dataclass(frozen=True)
class Activation:
    result: ApplyResult
    replaced_effect: str | None = None


class FieldEffects:
    def __init__(self, state: RuntimeState):
        self.state = state

    def activate(self, effect_id: str, duration: int, *, replace: bool = False) -> Activation:
        if not effect_id or duration <= 0:
            return Activation(ApplyResult.INVALID_CONTEXT)
        current = self.state.active_field_effect
        if current is not None and not replace:
            return Activation(ApplyResult.CANCELLED)
        self.state.active_field_effect = effect_id
        self.state.remaining_steps = duration
        return Activation(ApplyResult.APPLIED, current)

    def on_step(self, *, eligible: bool) -> bool:
        if not eligible or self.state.active_field_effect is None:
            return False
        self.state.remaining_steps -= 1
        if self.state.remaining_steps > 0:
            return False
        self.state.active_field_effect = None
        self.state.remaining_steps = 0
        return True


def should_consume(result: ApplyResult) -> bool:
    return result is ApplyResult.APPLIED
