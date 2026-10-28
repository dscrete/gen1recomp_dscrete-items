#!/usr/bin/env python3
"""ROM-free modkit gate: accept only documented missing vanilla trainer fixture IDs.

This is NOT imported-base validation. A fixture cannot resolve real Gen1 data.
All unexpected MKxxx errors, modkit crashes and exit statuses fail CI.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

EXPECTED_MISSING_COUNT = 33
ERROR = re.compile(r"^MK\d+ ERROR .+$", re.MULTILINE)
KNOWN_FIXTURE_GAP = re.compile(
    r'^MK102 ERROR gen1recomp_dscrete_items: trainers\.OPP_DS_'
    r'(?:RONNIE|MILO|CASS)\.'
    r'(?:parties\[\d+\]\[\d+\]\.species|basePic): '
    r'unresolved reference to (?:pokemon "[A-Z0-9_]+"|trainers "OPP_ROCKET")$'
)


def accepted_output(status: int, combined: str) -> tuple[bool, str]:
    if status == 0 and "FAIL gen1recomp_dscrete_items invalid" not in combined:
        return True, "fixture loader returned clean success"
    errors = ERROR.findall(combined)
    # modkit reports validation failures with exit status 1; accept 2 as
    # well for builds that use the older CLI failure convention.
    if status not in (1, 2):
        return False, f"unexpected modkit exit status {status}"
    if "FAIL gen1recomp_dscrete_items invalid" not in combined:
        return False, "modkit did not complete normal validation"
    if "Traceback (most recent call last)" in combined or "stack traceback:" in combined:
        return False, "modkit crashed rather than validating"
    unexpected = [line for line in errors if not KNOWN_FIXTURE_GAP.fullmatch(line)]
    if unexpected:
        return False, f"unexpected validation errors: {unexpected[:5]}"
    if len(errors) != EXPECTED_MISSING_COUNT:
        return False, (
            f"expected {EXPECTED_MISSING_COUNT} known missing vanilla trainer "
            f"references; observed {len(errors)}"
        )
    return True, (
        f"{len(errors)} known missing vanilla trainer references only; "
        "imported-base validation is still required"
    )


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if len(args) != 2:
        print("usage: fixture_gate.py ENGINE_ROOT MOD_ROOT", file=sys.stderr)
        return 2
    engine, mod = (Path(x).expanduser().resolve() for x in args)
    command = [sys.executable, str(engine / "tools" / "modkit.py"),
               "validate", str(mod), "--base", "fixture"]
    try:
        completed = subprocess.run(
            command, cwd=engine, capture_output=True, text=True, check=False
        )
    except OSError as exc:
        print(f"cannot start modkit: {exc}", file=sys.stderr)
        return 1
    combined = completed.stdout + "\n" + completed.stderr
    print(combined, end="")
    ok, reason = accepted_output(completed.returncode, combined)
    print(("FIXTURE GATE PASS: " if ok else "FIXTURE GATE FAIL: ") + reason)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
