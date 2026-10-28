#!/usr/bin/env python3
"""Verify an exact, reproducible supported Gen1Recomp checkout."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path


TARGET_COMMITS = {
    "v0.2.5": "74e04cb086d223bb84b52a4631cb6a6c10e0a948",
    "v0.2.74": "9545ebbb839a8a7ea28472b626681154ab222623",
    "v0.3.3": "07a3be67fd5186d74af265417c0d813dfee5e792",
}
DEFAULT_TARGET = "v0.2.74"
ROOT_VARIABLE = "GEN1RECOMP_ROOT"


def fail(message: str) -> int:
    print(f"upstream verification failed: {message}", file=sys.stderr)
    return 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--target", choices=sorted(TARGET_COMMITS), default=DEFAULT_TARGET,
        help="exact engine release to check (default: %(default)s)",
    )
    args = parser.parse_args(argv)

    configured_root = os.environ.get(ROOT_VARIABLE)
    if not configured_root:
        return fail(f"set {ROOT_VARIABLE} to the external Gen1Recomp {args.target} checkout")

    root = Path(configured_root).expanduser().resolve()
    if not root.is_dir():
        return fail(f"{root} is not a directory")

    documentation = root / "docs" / "modding.md"
    if not documentation.is_file():
        return fail(f"tagged Mod API documentation is missing: {documentation}")

    modkit = root / "tools" / "modkit.py"
    if not modkit.is_file():
        return fail(f"engine modkit is missing: {modkit}")

    try:
        commit = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "HEAD"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError) as error:
        return fail(f"cannot read the checkout revision: {error}")

    expected = TARGET_COMMITS[args.target]
    if commit != expected:
        return fail(f"{args.target}: expected commit {expected}, found {commit}")

    print(f"verified Gen1Recomp {args.target} at {commit}")
    print(f"public Mod API documentation: {documentation}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
