import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock

from tools.imported_matrix import TARGETS, run_matrix


class ImportedMatrixTests(unittest.TestCase):
    def test_all_three_environment_roots_are_required(self):
        with tempfile.TemporaryDirectory() as folder:
            called = Mock()
            self.assertFalse(run_matrix({}, Path(folder), called))
            called.assert_not_called()

    def test_each_engine_must_pass_verification_and_imported_validation(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            checkouts = {}
            for tag, _ in TARGETS:
                directory = root / tag
                directory.mkdir()
                checkouts[tag] = str(directory)
            calls = []

            def run(argv, **kwargs):
                calls.append((argv, kwargs))
                return subprocess.CompletedProcess(argv, 0)

            self.assertTrue(run_matrix(checkouts, root, run))
            self.assertEqual(len(calls), 6)
            for i, (tag, _) in enumerate(TARGETS):
                self.assertEqual(calls[i*2][0][-2:], ["--target", tag])
                self.assertEqual(calls[i*2+1][0][-3:],
                                 [str(root), "--base", "imported"])
                self.assertEqual(calls[i*2+1][1]["cwd"], Path(checkouts[tag]))

    def test_refuses_to_validate_a_wrong_checkout_and_fails_closed(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            checkouts = {}
            for tag, _ in TARGETS:
                directory = root / tag
                directory.mkdir()
                checkouts[tag] = str(directory)
            calls = []

            def run(argv, **kwargs):
                calls.append(argv)
                if argv[-2:] == ["--target", "v0.2.74"]:
                    return subprocess.CompletedProcess(argv, 1)
                return subprocess.CompletedProcess(argv, 0)

            self.assertFalse(run_matrix(checkouts, root, run))
            self.assertEqual(len(calls), 5)
            self.assertFalse(any(
                "modkit.py" in " ".join(args)
                and "v0.2.74" in " ".join(args)
                for args in calls
            ))


if __name__ == "__main__":
    unittest.main()
