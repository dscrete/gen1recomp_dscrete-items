import os
import tempfile
import unittest
from contextlib import redirect_stderr
from io import StringIO
from pathlib import Path
from unittest.mock import patch

from tools import verify_upstream


class VerifyUpstreamTests(unittest.TestCase):
    def run_main(self, root: str | None) -> tuple[int, str]:
        environment = {} if root is None else {verify_upstream.ROOT_VARIABLE: root}
        stderr = StringIO()
        with patch.dict(os.environ, environment, clear=True), redirect_stderr(stderr):
            result = verify_upstream.main()
        return result, stderr.getvalue()

    def test_checkout_is_required(self) -> None:
        result, error = self.run_main(None)
        self.assertEqual(1, result)
        self.assertIn(verify_upstream.ROOT_VARIABLE, error)

    def test_checkout_must_be_a_directory(self) -> None:
        result, error = self.run_main("/definitely/not/a/gen1recomp/checkout")
        self.assertEqual(1, result)
        self.assertIn("is not a directory", error)

    def test_tagged_documentation_is_required(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result, error = self.run_main(directory)
        self.assertEqual(1, result)
        self.assertIn("docs/modding.md", error)

    def test_non_git_directory_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            documentation = Path(directory) / "docs" / "modding.md"
            documentation.parent.mkdir()
            documentation.write_text("# Test fixture\n", encoding="utf-8")
            result, error = self.run_main(directory)
        self.assertEqual(1, result)
        self.assertIn("cannot read the checkout revision", error)
