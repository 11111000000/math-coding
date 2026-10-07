#!/usr/bin/env python3
"""axiom-link-seed.py — deterministic sweep that appends an
`axiom_link:` block to every legacy active decision that lacks
one. This is the T2.2 migration tool: the kernel will reject
active decisions with empty `axiom_link` per
spec/algebra-3.2.md §7 (T2.2 closes the contract).

Idempotency
-----------
Running the script twice on a tree that already has
`axiom_link` populated rewrites the file to the same content
(modulo whitespace). The SHA is recomputed each run because
the input differs by zero bytes after the first pass.

Determinism
-----------
The axiom IDs default to `["A0"]` (the A0-separation
meta-axiom applies universally). A human maintainer is
expected to refine the placeholder per decision over time
under the meta-decision's `axiom-link-review-cycle`. The
heuristic never invents content that violates the schema.

Algorithm
---------
For each decision file under decisions/*.yaml and
decisions/plan-2026-10-improvements/*.yaml:

  1. Skip the markdown file (rationale.md). Master-policy
     meta files (decision.yaml, obligations.yaml,
     obligation-count-reconcile.yaml) DO get axiom_link
     added because they are validated by `mathc validate` and
     the kernel treats them as ordinary active decisions.
  2. Skip retired/superseded decisions (no axiom_link
     required for those states).
  3. Skip files that already have a non-empty `axiom_link`
     list at the top level.
  4. Use the default placeholder list `["A0"]`.
  5. Insert `axiom_link:` (block form, NOT inline-flow) at
     the canonical anchor (immediately before `outcomes:`,
     matching the placement in decisions/algebra-3.2.yaml).
     Block form is the only one the kernel's hand-rolled YAML
     loader in lib/codec.ml reads as a list — inline-flow
     `axiom_link: [A0]` is parsed as Jsonl.String "[A0]".
  6. Recompute body_sha and yaml_sha via the standard
     placeholder-substitution algorithm.

Usage
-----
    scripts/axiom-link-seed.py [--dry-run] [--verbose]

With --dry-run, the script prints what it would do without
writing to disk. With --verbose, every step is logged. Default
is to apply the sweep and write to disk.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
DECISIONS_DIR = REPO_ROOT / "decisions"
TIER_DIR = DECISIONS_DIR / "plan-2026-10-improvements"

# The markdown notes file is not a decision. rationale.md
# stays as-is.
META_FILES_EXEMPT = {"rationale.md"}

# Per-file axiom_link for the three meta files. These are
# master-policy / aggregator decisions whose axiom is fixed by
# the project's design; A0 separation is the universal fit.
META_AXIOM_LINKS: dict[str, list[str]] = {
    "decision.yaml": ["A0"],
    "obligations.yaml": ["A0"],
    "obligation-count-reconcile.yaml": ["A0"],
}

# Anchor: top-level keys before which `axiom_link:` is
# inserted. Placement matches `decisions/algebra-3.2.yaml`:
# the block goes between `revision:` and the first anchor in
# {outcomes, scope, commitment}. If no anchor is present,
# append at the end.
INSERTION_ANCHORS = ("outcomes:", "commitment:", "scope:")

PLACEHOLDER = "sha256:" + "0" * 64

# Heuristic mapping of decision ids to axiom IDs. Decisions
# not listed here default to `["A0"]` (the A0 separation
# meta-axiom applies universally). The table is
# intentionally minimal — a full audit of "which axiom does
# each decision address?" is human-review work tracked
# separately under the meta-decision's
# `axiom-link-review-cycle`. This script only ensures schema
# compliance.
AXIOM_TABLE: dict[str, list[str]] = {
    # Tier-2 sub-decisions already have explicit axiom_link
    # in their text; the table is empty here because the
    # default `["A0"]` covers all sub-decisions. Kept as a
    # stub for future human curation.
}


def recompute_sha(text: str) -> str:
    """Return the canonical sha256 for a decision's body.

    Replaces both `body_sha:` and `yaml_sha:` values with the
    placeholder, then sha256s the whole file. The placeholder
    is the same length as a real digest so no re-padding is
    needed.
    """
    new = re.sub(
        r'body_sha: "sha256:[a-f0-9]{64}"',
        f'body_sha: "{PLACEHOLDER}"',
        text,
    )
    new = re.sub(
        r'yaml_sha: "sha256:[a-f0-9]{64}"',
        f'yaml_sha: "{PLACEHOLDER}"',
        new,
    )
    return hashlib.sha256(new.encode("utf-8")).hexdigest()


def has_top_level_axiom_link(text: str) -> bool:
    """True if the file already has a non-empty top-level
    `axiom_link:` list."""
    m = re.search(
        r"^axiom_link:\s*\n((?:[ \t]+-\s*[^\n]+\n?)+)",
        text,
        re.MULTILINE,
    )
    if not m:
        m = re.search(
            r"^axiom_link:\s*\[[^\]]+\]",
            text,
            re.MULTILINE,
        )
        return m is not None
    body = m.group(1)
    stripped = body.strip()
    return bool(stripped)


def extract_decision_id(text: str) -> str:
    m = re.search(r"^id:\s*(\S+)\s*$", text, re.MULTILINE)
    if not m:
        raise ValueError("decision file lacks top-level `id:` field")
    return m.group(1)


def extract_state(text: str) -> str:
    """Return the state field value, defaulting to 'active'
    when absent (per schemas/decision.json default)."""
    m = re.search(r"^state:\s*(\S+)\s*$", text, re.MULTILINE)
    return m.group(1) if m else "active"


def find_insertion_line(text: str) -> int:
    """Return the 0-based index of the line BEFORE which
    `axiom_link:` should be inserted."""
    lines = text.splitlines(keepends=True)
    for i, line in enumerate(lines):
        stripped = line.rstrip("\n").rstrip("\r")
        for anchor in INSERTION_ANCHORS:
            if stripped == anchor or stripped.startswith(anchor + " "):
                return i
    return len(lines)


def insert_axiom_link(text: str, axiom_ids: list[str]) -> str:
    """Insert `axiom_link:` (block form) at the canonical anchor.

    The kernel's hand-rolled YAML loader in lib/codec.ml does
    NOT support flow-style arrays (`axiom_link: [A0]`);
    inline-flow values are parsed as Jsonl.String "[A0]" rather
    than Jsonl.Array [Jsonl.String "A0"]. The block form
    `axiom_link:\n  - A0` is the only one the loader can read;
    this is also the form used by `relations.addresses` in the
    existing decisions.
    """
    lines = text.splitlines(keepends=True)
    idx = find_insertion_line(text)
    body = "".join(f"  - {a}\n" for a in axiom_ids)
    block = f"axiom_link:\n{body}"
    new_lines = lines[:idx] + [block] + lines[idx:]
    return "".join(new_lines)


def rewrite_sha_lines(text: str, new_sha: str) -> str:
    new = re.sub(
        r'body_sha: "sha256:[a-f0-9]{64}"',
        f'body_sha: "sha256:{new_sha}"',
        text,
    )
    new = re.sub(
        r'yaml_sha: "sha256:[a-f0-9]{64}"',
        f'yaml_sha: "sha256:{new_sha}"',
        new,
    )
    return new


def process_file(path: Path, dry_run: bool, verbose: bool) -> tuple[str, bool]:
    """Returns (status, modified). status is one of
    {'SKIP-META', 'SKIP-PRESENT', 'SKIP-RETIRED', 'OK'}."""
    if path.name in META_FILES_EXEMPT:
        return ("SKIP-META", False)

    text = path.read_text()

    try:
        decision_id = extract_decision_id(text)
    except ValueError:
        return ("SKIP-META", False)

    state = extract_state(text)
    if state in ("retired", "superseded"):
        if verbose:
            print(f"  SKIP-RETIRED: {path.name} (state={state})")
        return ("SKIP-RETIRED", False)

    if has_top_level_axiom_link(text):
        if verbose:
            print(f"  SKIP-PRESENT: {path.name} (axiom_link already populated)")
        return ("SKIP-PRESENT", False)

    if path.name in META_AXIOM_LINKS:
        axiom_ids = META_AXIOM_LINKS[path.name]
    else:
        axiom_ids = AXIOM_TABLE.get(decision_id, ["A0"])
    new_text = insert_axiom_link(text, axiom_ids)
    new_sha = recompute_sha(new_text)
    final_text = rewrite_sha_lines(new_text, new_sha)

    if verbose:
        ids_str = ", ".join(axiom_ids)
        print(
            f"  OK: {path.name} (id={decision_id}, axiom_link=[{ids_str}], "
            f"sha256={new_sha[:12]}...)"
        )

    if not dry_run:
        path.write_text(final_text)

    return ("OK", True)


def collect_files() -> list[Path]:
    files: list[Path] = []
    if DECISIONS_DIR.is_dir():
        files.extend(sorted(DECISIONS_DIR.glob("*.yaml")))
    if TIER_DIR.is_dir():
        files.extend(sorted(TIER_DIR.glob("*.yaml")))
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--dry-run", action="store_true",
                        help="Print what would change without writing")
    parser.add_argument("--verbose", action="store_true",
                        help="Log every decision")
    args = parser.parse_args()

    files = collect_files()
    print(f"axiom-link-seed: {len(files)} files")
    print(f"  top-level: {DECISIONS_DIR}")
    print(f"  tier sub-decisions: {TIER_DIR}")

    counts: dict[str, int] = {}
    for filepath in files:
        status, modified = process_file(filepath, args.dry_run, args.verbose)
        counts[status] = counts.get(status, 0) + 1

    print()
    print(f"  OK (axiom_link added):            {counts.get('OK', 0)}")
    print(f"  SKIP-PRESENT (idempotent):        {counts.get('SKIP-PRESENT', 0)}")
    print(f"  SKIP-RETIRED (state != active):   {counts.get('SKIP-RETIRED', 0)}")
    print(f"  SKIP-META:                        {counts.get('SKIP-META', 0)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())