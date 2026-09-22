"""Debug menu model; engine-facing registration belongs in a verified adapter."""

from __future__ import annotations

from dataclasses import asdict
from typing import Protocol

from tools.items import ItemDefinition
from tools.runtime import RuntimeState, SaveState

MAIN_COMMANDS = ("GET ITEMS", "WARP", "INSPECT", "RESET", "CANCEL")
WARP_DESTINATIONS = (
    "PALLET TOWN",
    "VIRIDIAN FOREST",
    "ROCK TUNNEL",
    "SAFARI ZONE",
    "SILPH CO.",
    "CINNABAR ISLAND",
    "RETURN",
)


class DebugAdapter(Protocol):
    def grant_consumable(self, item_id: str, quantity: int) -> bool: ...
    def warp(self, destination: str) -> bool: ...


class DebugHarness:
    def __init__(self, save: SaveState, runtime: RuntimeState, adapter: DebugAdapter):
        self.save = save
        self.runtime = runtime
        self.adapter = adapter

    def grant(self, item: ItemDefinition, quantity: int = 1) -> bool:
        if quantity <= 0:
            return False
        if item.ownership in {"PERMANENT", "REUSABLE"}:
            self.save.permanent_unlocks.add(item.id)
            return True
        return self.adapter.grant_consumable(item.id, quantity)

    def inspect(self) -> dict[str, object]:
        return {"save": asdict(self.save), "runtime": asdict(self.runtime)}

    def reset_runtime(self) -> None:
        self.runtime.clear()

    def reset_save(self) -> None:
        self.save.permanent_unlocks.clear()
        self.save.reusable_state.clear()
        self.save.placed_beacon = None
