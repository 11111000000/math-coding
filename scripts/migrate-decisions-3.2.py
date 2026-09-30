#!/usr/bin/env python3
"""Migrate decisions/*.yaml to add 3.2 fields via text-based editing.

Preserves all comments, formatting, and field ordering by inserting
3 lines after the `revision:` line in each decision file.

Adds three optional fields per algebra §7:
- state: active (draft|active|retired|superseded)
- body_sha: "" (populated at commit time by future hook)
- yaml_sha: "" (populated at commit time by future hook)

Skips meta files (obligations.yaml, rationale.md, ONBOARDING.md).
"""

import re
import sys
from pathlib import Path

DECISIONS_DIR = Path(__file__).parent.parent / "decisions"

SKIP_FILES = {"obligations.yaml", "rationale.md", "ONBOARDING.md"}

# Match `revision:` line at start (no leading whitespace) and insert 3
# lines after it, preserving indentation if any.
REVISION_RE = re.compile(r"^revision:\s*(\S+)\s*$", re.MULTILINE)

NEW_LINES = "state: active\nbody_sha: \"\"\nyaml_sha: \"\""


def migrate(filepath: Path) -> bool:
    if filepath.name in SKIP_FILES:
        return False
    if filepath.suffix != ".yaml":
        return False

    text = filepath.read_text()

    # Skip if already migrated (state field present at top level)
    if re.search(r"^state:\s*(draft|active|retired|superseded)\s*$", text, re.MULTILINE):
        return False

    # Find revision: line at start (not nested)
    m = REVISION_RE.search(text)
    if not m:
        print(f"  WARN: no top-level revision: line in {filepath.name}")
        return False

    # Insert new lines after the revision line
    end = m.end()
    new_text = text[:end] + "\n" + NEW_LINES + text[end:]
    filepath.write_text(new_text)
    return True


def main() -> int:
    yaml_files = sorted(DECISIONS_DIR.glob("*.yaml"))
    print(f"Migrating decisions in {DECISIONS_DIR}")
    print(f"  Total yaml files: {len(yaml_files)}")

    migrated = []
    skipped_meta = []
    already = []
    warn = []

    for filepath in yaml_files:
        if filepath.name in SKIP_FILES:
            skipped_meta.append(filepath.name)
            continue
        if filepath.suffix != ".yaml":
            continue
        result = migrate(filepath)
        if result is True:
            migrated.append(filepath.name)
        elif result is False:
            text = filepath.read_text()
            if "state:" in text and "active" in text:
                already.append(filepath.name)
            else:
                warn.append(filepath.name)

    print(f"\nMigrated: {len(migrated)} files")
    for name in migrated:
        print(f"  + {name}")
    if already:
        print(f"\nAlready migrated: {len(already)}")
    if warn:
        print(f"\nWarnings (no revision line): {len(warn)}")
        for name in warn:
            print(f"  ! {name}")
    print(f"\nSkipped (meta files): {len(skipped_meta)}")
    for name in skipped_meta:
        print(f"  - {name}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
