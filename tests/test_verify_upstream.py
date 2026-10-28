import os
import subprocess
import tempfile
import unittest
from contextlib import redirect_stderr
from io import StringIO
from pathlib import Path
from unittest.mock import patch

from tools import verify_upstream


class VerifyUpstreamTests(unittest.TestCase):
    def run_main(self, root: str | None, target: str | None = None, sha: str | None = None):
        environment = {} if root is None else {verify_upstream.ROOT_VARIABLE: root}
        stderr = StringIO()
        argv = [] if target is None else ["--target", target]
        with patch.dict(os.environ, environment, clear=True), redirect_stderr(stderr):
            with patch.object(
                verify_upstream.subprocess, "run",
                return_value=subprocess.CompletedProcess([], 0, stdout=sha or ""),
            ):
                result = verify_upstream.main(argv)
        return result, stderr.getvalue()

    def fixture(self, root: str):
        directory = Path(root)
        (directory / "docs").mkdir()
        (directory / "docs" / "modding.md").write_text("# Fixture\n", encoding="utf-8")
        (directory / "tools").mkdir()
        (directory / "tools" / "modkit.py").write_text("# Fixture\n", encoding="utf-8")

    def test_checkout_is_required(self):
        result, error = self.run_main(None)
        self.assertEqual(1, result)
        self.assertIn(verify_upstream.ROOT_VARIABLE, error)

    def test_checkout_must_be_a_directory(self):
        result, error = self.run_main("/definitely/not/a/gen1recomp/checkout")
        self.assertEqual(1, result)
        self.assertIn("is not a directory", error)

    def test_modding_docs_are_required(self):
        with tempfile.TemporaryDirectory() as directory:
            result, error = self.run_main(directory)
        self.assertEqual(1, result)
        self.assertIn("docs/modding.md", error)

    def test_modkit_is_required(self):
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / "docs").mkdir()
            (Path(directory) / "docs" / "modding.md").write_text("test")
            result, error = self.run_main(directory)
        self.assertEqual(1, result)
        self.assertIn("tools/modkit.py", error)

    def test_all_pinned_targets_are_accepted_at_the_exact_revision(self):
        for tag, sha in verify_upstream.TARGET_COMMITS.items():
            with self.subTest(tag=tag), tempfile.TemporaryDirectory() as directory:
                self.fixture(directory)
                self.assertEqual(self.run_main(directory, tag, sha)[0], 0)

    def test_wrong_revision_is_rejected_for_every_target(self):
        for tag in verify_upstream.TARGET_COMMITS:
            with self.subTest(tag=tag), tempfile.TemporaryDirectory() as directory:
                self.fixture(directory)
                result, error = self.run_main(directory, tag, "wrong-commit")
                self.assertEqual(result, 1)
                self.assertIn("expected commit", error)

    def test_default_target_matches_documented_integration_release(self):
        self.assertEqual(verify_upstream.DEFAULT_TARGET, "v0.2.74")
        with tempfile.TemporaryDirectory() as directory:
            self.fixture(directory)
            self.assertEqual(self.run_main(
                directory, sha=verify_upstream.TARGET_COMMITS["v0.2.74"]
            )[0], 0)

    def test_git_read_errors_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            self.fixture(directory)
            with patch.dict(os.environ, {verify_upstream.ROOT_VARIABLE: directory}, clear=True):
                with patch.object(
                    verify_upstream.subprocess, "run",
                    side_effect=subprocess.CalledProcessError(1, "git"),
                ):
                    with redirect_stderr(StringIO()):
                        self.assertEqual(verify_upstream.main([]), 1)


if __name__ == "__main__":
    unittest.main()
