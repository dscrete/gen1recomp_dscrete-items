import tempfile
import unittest
from pathlib import Path

from tools.manifest import ManifestError, load_manifest, validate_compatibility

ROOT = Path(__file__).resolve().parents[1]


class ManifestTests(unittest.TestCase):
    def test_real_manifest_has_verified_load_fields(self) -> None:
        document = load_manifest(ROOT / "manifest.json")
        validate_compatibility(document)
        self.assertTrue((ROOT / document["entry"]).is_file())
        self.assertEqual(document["github"], "dscrete/gen1recomp_dscrete-items")
        self.assertEqual(document["game_version"], ">=0.2.5 <1.0.0")

    def test_missing_entry_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text('{"id":"gen1recomp_dscrete_items","name":"DScrete Items","version":"0.1.0","api":2,"profile":"content","games":["gen1"],"game_version":">=0.2.5 <1.0.0","github":"dscrete/gen1recomp_dscrete-items"}', encoding="utf-8")
            with self.assertRaises(ManifestError):
                validate_compatibility(load_manifest(path))

    def test_non_semver_version_is_rejected(self) -> None:
        document = load_manifest(ROOT / "manifest.json")
        document["version"] = "dev"
        with self.assertRaises(ManifestError):
            validate_compatibility(document)

    def test_wrong_update_repository_is_rejected(self) -> None:
        document = load_manifest(ROOT / "manifest.json")
        document["github"] = "someone/else"
        with self.assertRaises(ManifestError):
            validate_compatibility(document)


if __name__ == "__main__":
    unittest.main()
