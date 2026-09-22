#!/usr/bin/env python3
"""Verify an external Gen1Recomp checkout before integration testing."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


EXPECTED_COMMIT = "9545ebbb839a8a7ea28472b626681154ab222623"
ROOT_VARIABLE = "GEN1RECOMP_ROOT"


def fail(message: str) -> int:
    print(f"upstream verification failed: {message}", file=sys.stderr)
    return 1


def main() -> int:
    configured_root = os.environ.get(ROOT_VARIABLE)
    if not configured_root:
        return fail(f"set {ROOT_VARIABLE} to the external Gen1Recomp v0.2.74 checkout")

    root = Path(configured_root).expanduser().resolve()
    if not root.is_dir():
        return fail(f"{root} is not a directory")

    documentation = root / "docs" / "modding.md"
    if not documentation.is_file():
        return fail(f"tagged Mod API documentation is missing: {documentation}")

    try:
        commit = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError) as error:
        return fail(f"cannot read the checkout revision: {error}")

    if commit != EXPECTED_COMMIT:
        return fail(f"expected commit {EXPECTED_COMMIT}, found {commit}")

    print(f"verified Gen1Recomp v0.2.74 at {commit}")
    print(f"public Mod API documentation: {documentation}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
