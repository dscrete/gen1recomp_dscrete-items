import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


class RepositoryBoundaryTests(unittest.TestCase):
    def test_engine_is_not_vendored(self) -> None:
        forbidden_roots = {
            "gen1recomp",
            "engine",
            "vendor",
            "third_party",
            "submodules",
        }
        present = {
            path.name
            for path in REPOSITORY_ROOT.iterdir()
            if path.is_dir() and path.name != ".git"
        }
        self.assertFalse(
            forbidden_roots & present,
            f"engine-like repository roots found: {sorted(forbidden_roots & present)}",
        )

    def test_no_git_submodules_are_configured(self) -> None:
        self.assertFalse((REPOSITORY_ROOT / ".gitmodules").exists())
