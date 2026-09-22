import unittest
from dataclasses import replace
from pathlib import Path

from tools.items import ItemDefinitionError, load_items, validate_items


ROOT = Path(__file__).resolve().parents[1]


class ItemTests(unittest.TestCase):
    def setUp(self) -> None:
        self.items = list(load_items(ROOT / "data" / "items.json"))

    def test_catalogue_is_complete_and_unique(self) -> None:
        self.assertEqual(23, len(self.items))
        self.assertEqual(23, len({item.id for item in self.items}))
        self.assertIn("shiny_finder", {item.id for item in self.items})

    def test_unknown_labels_are_rejected(self) -> None:
        for field in ("ownership", "family", "effect_kind"):
            with self.subTest(field=field), self.assertRaises(ItemDefinitionError):
                validate_items([replace(self.items[0], **{field: "UNKNOWN"})])

    def test_duplicate_ids_are_rejected(self) -> None:
        with self.assertRaisesRegex(ItemDefinitionError, "duplicate item id"):
            validate_items([self.items[0], self.items[0]])
