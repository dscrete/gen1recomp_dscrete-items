import unittest
from pathlib import Path

from tools.debug_harness import MAIN_COMMANDS, WARP_DESTINATIONS, DebugHarness
from tools.items import load_items
from tools.runtime import RuntimeState, SaveState


ROOT = Path(__file__).resolve().parents[1]


class FakeAdapter:
    def __init__(self) -> None:
        self.grants = []

    def grant_consumable(self, item_id: str, quantity: int) -> bool:
        self.grants.append((item_id, quantity))
        return True

    def warp(self, destination: str) -> bool:
        return destination in WARP_DESTINATIONS


class DebugHarnessTests(unittest.TestCase):
    def setUp(self) -> None:
        self.items = {item.id: item for item in load_items(ROOT / "data" / "items.json")}
        self.save = SaveState()
        self.runtime = RuntimeState()
        self.adapter = FakeAdapter()
        self.harness = DebugHarness(self.save, self.runtime, self.adapter)

    def test_menu_contract(self) -> None:
        self.assertEqual(("GET ITEMS", "WARP", "INSPECT", "RESET", "CANCEL"), MAIN_COMMANDS)

    def test_grant_uses_ownership_path(self) -> None:
        self.assertTrue(self.harness.grant(self.items["shiny_finder"], 5))
        self.assertEqual([("shiny_finder", 5)], self.adapter.grants)
        self.assertTrue(self.harness.grant(self.items["silph_tracker"]))
        self.assertIn("silph_tracker", self.save.permanent_unlocks)

    def test_inspect_and_resets(self) -> None:
        self.save.permanent_unlocks.add("silph_tracker")
        self.runtime.active_field_effect = "shiny_finder"
        self.runtime.remaining_steps = 25
        snapshot = self.harness.inspect()
        self.assertEqual(25, snapshot["runtime"]["remaining_steps"])
        self.harness.reset_runtime()
        self.harness.reset_save()
        self.assertEqual(RuntimeState(), self.runtime)
        self.assertEqual(set(), self.save.permanent_unlocks)
