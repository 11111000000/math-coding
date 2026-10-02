#!/usr/bin/env python3
"""Tier 2 decision data migration: fix schema deviations across decisions/.

This is a one-shot script. The 28 decisions/*.yaml files were authored
across many v3.x batches and accumulated the following schema deviations
per the post-v3.1.0 deep analysis:

- countercase: field (23 files) - should be counterexample:
  (per schemas/decision.json and algebra §11)
- missing risk.owner (10 files) - A4 Care requires owner
- malformed risk: blocks (5 files) - reversal_condition instead
  of declared_triggers, counterexample: as a list item
- self-reference in algebra-3.2.yaml: lists itself in scope.paths
- stale path: algebra-3.2.yaml:59 lists lib/attestations.ml (file
  was moved to lib/attestations/attestations.ml in v3.0.0.20)
- 6 files lack counterexample/countercase entirely
- 10 files use bare bootstrap-v3 (no rev) in addresses
- time-honesty.yaml has state: declared (invalid)

This script applies the safe renames and adds missing required
fields. Decisions that already conform are skipped.
"""
import re
import sys
from pathlib import Path

DECISIONS_DIR = Path(__file__).parent.parent / "decisions"
SKIP = {"obligations.yaml", "ONBOARDING.md", "rationale.md"}

# Default risk.owner if missing
DEFAULT_OWNER = "human:maintainer"


def migrate(file: Path) -> list[str]:
    """Apply fixes. Returns list of fix descriptions."""
    text = file.read_text()
    fixes = []
    original = text

    # 1. Rename countercase: -> counterexample: (only at risk-block level)
    # The risk block can have:
    #   risk:
    #     declared_triggers: [...]
    #     owner: ...
    #   - counterexample: |   (list item)
    # We rename both top-level field and list-item key
    new = re.sub(r"^(\s*)countercase:", r"\1counterexample:",
                 text, flags=re.MULTILINE)
    if new != text:
        fixes.append("renamed countercase: -> counterexample:")
        text = new

    # 2. Fix malformed risk: blocks (reversal_condition -> declared_triggers)
    new = re.sub(r"^(\s*)reversal_condition:",
                 r"\1declared_triggers:", text, flags=re.MULTILINE)
    if new != text:
        fixes.append("replaced reversal_condition: -> declared_triggers:")
        text = new

    # 3. Add risk.owner if missing in a risk: block
    # We look for: "  risk:\n    declared_triggers:" (or similar)
    # without an "owner:" line. Add owner after declared_triggers.
    risk_pattern = re.compile(
        r"(^risk:\n(?:\s+declared_triggers:[^\n]*\n)+)(?!\s+owner:)",
        re.MULTILINE)
    if risk_pattern.search(text) and "  owner:" not in text.split("risk:")[1][:500]:
        new = risk_pattern.sub(r"\1    owner: " + DEFAULT_OWNER + "\n", text, count=1)
        if new != text:
            fixes.append(f"added risk.owner = {DEFAULT_OWNER}")
            text = new

    # 4. algebra-3.2.yaml: remove self-reference + fix stale path
    if file.name == "algebra-3.2.yaml":
        # Remove own file from its own scope.paths
        new = re.sub(
            r"^(    - \"decisions/algebra-3\.2\.yaml\"\n)",
            "", text, flags=re.MULTILINE)
        if new != text:
            fixes.append("removed self-reference: decisions/algebra-3.2.yaml")
            text = new
        # Fix stale path: lib/attestations.ml -> lib/attestations/attestations.ml
        new = re.sub(r"^(    - \"lib/attestations\.ml\")$",
                     r"    - \"lib/attestations/attestations.ml\"",
                     text, flags=re.MULTILINE)
        if new != text:
            fixes.append("fixed stale path: lib/attestations.ml")
            text = new

    # 5. time-honesty.yaml: fix invalid state: declared
    if file.name == "time-honesty.yaml":
        new = re.sub(r"^(\s*)state: declared\s*$",
                     r"\1state: assumed", text, flags=re.MULTILINE)
        if new != text:
            fixes.append("fixed state: declared -> assumed")
            text = new

    if text != original:
        file.write_text(text)

    return fixes


def main() -> int:
    print(f"Migrating decisions in {DECISIONS_DIR}")
    total_files = 0
    total_fixes = 0
    for filepath in sorted(DECISIONS_DIR.iterdir()):
        if filepath.name in SKIP:
            continue
        if filepath.suffix != ".yaml":
            continue
        fixes = migrate(filepath)
        if fixes:
            total_files += 1
            total_fixes += len(fixes)
            print(f"  {filepath.name}: {len(fixes)} fix(es)")
            for f in fixes:
                print(f"    - {f}")
    print(f"\nTotal: {total_fixes} fix(es) across {total_files} file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
