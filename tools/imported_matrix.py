#!/usr/bin/env python3
"""Validate DScrete Items against actual imported game data in three pinned engines.

This gate intentionally requires user-owned imported Gen 1 caches. It does not
substitute fixtures, generate ROM-derived content or silently skip missing
checkouts. Use the exact three engine root environment variables below.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Callable

TARGETS = (
    ("v0.2.5", "GEN1RECOMP_V025_ROOT"),
    ("v0.2.74", "GEN1RECOMP_V0274_ROOT"),
    ("v0.3.3", "GEN1RECOMP_V033_ROOT"),
)


def run_matrix(
    roots: dict[str, str],
    mod_root: Path,
    run: Callable = subprocess.run,
) -> bool:
    if any(not roots.get(tag) for tag, _ in TARGETS):
        missing = [env for tag, env in TARGETS if not roots.get(tag)]
        print("Missing engine checkout environment: " + ", ".join(missing),
              file=sys.stderr)
        return False

    verified = True
    for tag, _ in TARGETS:
        root = Path(roots[tag]).expanduser().resolve()
        env = os.environ.copy()
        env["GEN1RECOMP_ROOT"] = str(root)
        print(f"\n=== {tag}: revision verification ===", flush=True)
        if not root.is_dir():
            print(f"{tag}: checkout directory missing: {root}", file=sys.stderr)
            verified = False
            continue
        check = run(
            [sys.executable, str(mod_root / "tools" / "verify_upstream.py"),
             "--target", tag],
            cwd=mod_root, env=env, check=False,
        )
        if check.returncode != 0:
            verified = False
            continue
        print(f"=== {tag}: imported-base engine validation ===", flush=True)
        validation = run(
            [sys.executable, str(root / "tools" / "modkit.py"),
             "validate", str(mod_root), "--base", "imported"],
            cwd=root, env=env, check=False,
        )
        if validation.returncode != 0:
            print(f"{tag}: imported-base validation FAILED", file=sys.stderr)
            verified = False
        else:
            print(f"{tag}: imported-base validation PASSED")
    return verified


def main() -> int:
    roots = {tag: os.environ.get(env, "") for tag, env in TARGETS}
    root = Path(__file__).resolve().parents[1]
    ok = run_matrix(roots, root)
    print("Imported compatibility matrix " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
