import json
import tempfile
import unittest
from pathlib import Path

from tools.manifest import (
    EXPECTED_COMPATIBILITY,
    ManifestError,
    load_manifest,
    validate_compatibility,
)


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


class ManifestTests(unittest.TestCase):
    def test_repository_manifest_has_pinned_compatibility(self) -> None:
        manifest = load_manifest(REPOSITORY_ROOT / "manifest.json")
        validate_compatibility(manifest)

    def test_required_fields_have_exact_types_and_values(self) -> None:
        manifest = load_manifest(REPOSITORY_ROOT / "manifest.json")
        self.assertEqual(EXPECTED_COMPATIBILITY, manifest)
        self.assertIs(type(manifest["api"]), int)
        self.assertIsInstance(manifest["games"], list)
        self.assertTrue(all(isinstance(game, str) for game in manifest["games"]))
        self.assertIsInstance(manifest["game_version"], str)

    def test_mismatch_reports_every_compatibility_field(self) -> None:
        with self.assertRaises(ManifestError) as context:
            validate_compatibility(
                {"api": 1, "games": ["gen2"], "game_version": "latest"}
            )

        message = str(context.exception)
        for field in EXPECTED_COMPATIBILITY:
            self.assertIn(field, message)

    def test_invalid_json_has_location(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text('{"api":', encoding="utf-8")

            with self.assertRaisesRegex(ManifestError, r"manifest\.json:1:8"):
                load_manifest(path)

    def test_non_object_manifest_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text(json.dumps([EXPECTED_COMPATIBILITY]), encoding="utf-8")

            with self.assertRaisesRegex(ManifestError, "root must be a JSON object"):
                load_manifest(path)
