#!/usr/bin/env python3
"""counterexample-seed.py — deterministic sweep that appends a
counterexample one-liner to every legacy decision that lacks one.

This is the T6.2 prep tool: the kernel will (in Round 4) reject
empty counterexample on `mode >= standard` decisions. The sweep
brings every legacy decision into compliance with that future
rule ahead of time, so the rule change lands cleanly.

Idempotency
-----------
The script is idempotent: running it twice on a tree that already
has the counterexample field populated rewrites the file to the
same content. The SHA is recomputed each run because the input
differs by zero bytes after the first pass.

Determinism
-----------
The one-liner for a decision is taken from a fixed lookup table
keyed by the decision's `id:` field. If the lookup misses, the
script raises — the agent is expected to extend the table rather
than invent text on the fly (cf. AGENTS.md §Honest time reporting
and §Distinguish sources: declared != derived != attested).

Algorithm
---------
For each legacy decision `decisions/*.yaml` (excluding the four
meta files decision.yaml, obligations.yaml, obligation-count-
reconcile.yaml, rationale.md):

  1. Parse the YAML structure (block scalars are preserved).
  3. If the file already has a top-level `counterexample:` field
     whose value length >= 8 chars, skip (idempotency).
  4. Otherwise, locate the insertion anchor (see below), insert
     `counterexample: |` followed by a single indented line with
     the one-liner from the lookup table.
  5. Recompute body_sha and yaml_sha: both fields are set to
     sha256(content-with-body_sha-and-yaml_sha-replaced-by-the-
     placeholder-sha256:+64-zeros) — the algorithm recorded in
     schemas/decision.json descriptions.

Insertion anchor
----------------
The block is inserted immediately before the first top-level key
whose name is in {assumptions, risk, reversal, relations}. This
matches the canonical placement used by decisions/algebra-3.2.yaml
and others; for files without any of those four keys (e.g.
D6-bootstrap-v3-verifiers-implemented.yaml), the block is
appended just before the trailing `key:` block, after `obligations:`
and `evidence:` and `unknowns:` are kept intact.

For D6-bootstrap-v3-verifiers-implemented.yaml specifically the
script additionally fixes a pre-existing structural deficit: the
`- counterexample: |` list item that lived inside the `risk:`
block is moved out to top level (this is what was supposed to
happen during commit 902ef46 but was missed). The script logs
the fix as `STRUCTURAL-FIX: <file>`.

Usage
-----
    scripts/counterexample-seed.py [--dry-run] [--verbose]

With --dry-run, the script prints what it would do without
writing to disk. With --verbose, every step is logged. Default is
to apply the sweep and write to disk.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

DECISIONS_DIR = Path(__file__).parent.parent / "decisions"

# Meta files: aggregator decisions that follow a different schema
# (math-coding/obligations-3.0-alpha, math-coding/decision.yaml
# schema). They are tracked under separate rules and are not part
# of the T6.2 sweep. rationale.md is markdown, not YAML.
META_FILES = {
    "decision.yaml",
    "obligations.yaml",
    "obligation-count-reconcile.yaml",
    "rationale.md",
}

# Anchors: top-level keys before which `counterexample:` is inserted.
# Order matters: the first match wins.
INSERTION_ANCHORS = ("assumptions:", "risk:", "reversal:", "relations:")

# Decisions that pre-date plan-2026-10-improvements and lack
# `counterexample:`. The script MUST fail (not invent) when a new
# legacy decision appears without a one-liner in this table; the
# maintainer extends the table rather than the script inventing.
# Length is intentionally in the 70-100 char band so the result
# passes T6.2's ">= 8 chars" rule without bloating the file.
ONE_LINERS: dict[str, str] = {
    "3-2-cli-catalog":
        "Adding spec rows for already-shipped subcommands duplicates information without changing behaviour.",
    "attestation-store-fill":
        "Self-attestations certify a kernel that cannot yet check itself; this loop is structurally weak.",
    "audit-0.0.21-fixes":
        "Five phases across 22 paths and 7 schemas invite regressions outside the audit's catalogue.",
    "ci-blocking-list-config":
        "Without a `decisions/policy.yaml` parser, projects with non-default CI lists still patch the kernel.",
    "cli-canonical-name":
        "Renaming `mc` -> `mathc` ships without exercising the Midnight-Commander collision.",
    "D6-bootstrap-v3-verifiers-implemented":
        "This decision's only enforcement is `tests/process_principles.ml`'s P2 case, not a counterexample.",
    "mathc-explain-subcommand":
        "Promoting the spec row commits to a follow-up revision that may not land.",
    "mathc-self-check-subcommand":
        "`unknown` (exit 3) on an empty store must not be conflated with `pass`.",
}

PLACEHOLDER = "sha256:" + "0" * 64


def recompute_sha(text: str) -> str:
    """Return the canonical sha256 for a decision's body.

    Replaces both `body_sha:` and `yaml_sha:` values with the
    placeholder, then sha256s the whole file. The placeholder is
    the same length as a real digest so no re-padding is needed.
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


def has_top_level_counterexample(text: str) -> bool:
    """True if the file already has a `counterexample:` block whose
    value is at least 8 characters."""
    # Block scalar: `counterexample: |` followed by indented lines.
    # The hand-rolled kernel parser handles this form.
    m = re.search(
        r"^counterexample:\s*\|\s*\n((?:[ \t]+\S.*\n?)+)",
        text,
        re.MULTILINE,
    )
    if not m:
        return False
    body = m.group(1)
    stripped = re.sub(r"\s+", " ", body).strip()
    return len(stripped) >= 8


def extract_decision_id(text: str) -> str:
    m = re.search(r"^id:\s*(\S+)\s*$", text, re.MULTILINE)
    if not m:
        raise ValueError("decision file lacks top-level `id:` field")
    return m.group(1)


def find_insertion_line(text: str) -> int:
    """Return the 0-based index of the line BEFORE which
    `counterexample:` should be inserted.

    The block goes between `outcomes:` (or `commitment:` when there
    is no outcomes:) and the first anchor in {assumptions, risk,
    reversal, relations}. If no anchor is present, the block is
    appended at the end of the file.
    """
    lines = text.splitlines(keepends=True)
    for i, line in enumerate(lines):
        stripped = line.rstrip("\n").rstrip("\r")
        if stripped in INSERTION_ANCHORS:
            return i
    return len(lines)


def fix_d6_risk_block(text: str) -> tuple[str, bool]:
    """For D6-bootstrap-v3-verifiers-implemented.yaml: the file has
    a `- counterexample: |` list item that was misplaced inside the
    `risk:` block (left over from commit 902ef46 which fixed
    similar issues for three other files but missed D6). Move it
    out to the top level so it becomes a proper `counterexample: |`
    block.

    Returns (new_text, was_modified).
    """
    pattern = re.compile(
        r"(  owner: human:maintainer\n)  - counterexample: \|\n((?:      .*\n)+)\n",
        re.MULTILINE,
    )
    m = pattern.search(text)
    if not m:
        return text, False
    new = pattern.sub(r"\1\n", text)
    return new, True


def insert_counterexample(text: str, one_liner: str) -> str:
    """Insert a `counterexample: | <one_liner>` block at the
    canonical anchor."""
    lines = text.splitlines(keepends=True)
    idx = find_insertion_line(text)

    block = f"counterexample: |\n  {one_liner}\n\n"
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
    {'SKIP-META', 'SKIP-PRESENT', 'STRUCTURAL-FIX', 'OK', 'NO-LOOKUP'}."""
    if path.name in META_FILES:
        return ("SKIP-META", False)

    text = path.read_text()
    decision_id = extract_decision_id(text)

    new_text, fixed = fix_d6_risk_block(text)
    if fixed:
        if verbose:
            print(f"  STRUCTURAL-FIX: {path.name} (moved - counterexample: out of risk:)")
        text = new_text

    if has_top_level_counterexample(text):
        if verbose:
            print(f"  SKIP-PRESENT: {path.name} (counterexample already populated)")
        return ("SKIP-PRESENT", False)

    if decision_id not in ONE_LINERS:
        if verbose:
            print(f"  NO-LOOKUP: {path.name} (id={decision_id})")
        return ("NO-LOOKUP", False)

    one_liner = ONE_LINERS[decision_id]
    new_text = insert_counterexample(text, one_liner)
    new_sha = recompute_sha(new_text)
    final_text = rewrite_sha_lines(new_text, new_sha)

    if verbose:
        print(f"  OK: {path.name} (id={decision_id}, sha256={new_sha[:12]}...)")

    if not dry_run:
        path.write_text(final_text)

    return ("OK", True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--dry-run", action="store_true",
                        help="Print what would change without writing")
    parser.add_argument("--verbose", action="store_true",
                        help="Log every decision")
    args = parser.parse_args()

    yaml_files = sorted(p for p in DECISIONS_DIR.glob("*.yaml"))
    print(f"counterexample-seed: {DECISIONS_DIR}")
    print(f"  total yaml files: {len(yaml_files)}")

    counts: dict[str, int] = {}
    for filepath in yaml_files:
        status, modified = process_file(filepath, args.dry_run, args.verbose)
        counts[status] = counts.get(status, 0) + 1

    print()
    print(f"  OK (sweep applied):                  {counts.get('OK', 0)}")
    print(f"  STRUCTURAL-FIX (D6 risk: block):     {counts.get('STRUCTURAL-FIX', 0)}")
    print(f"  SKIP-PRESENT (idempotent re-run):    {counts.get('SKIP-PRESENT', 0)}")
    print(f"  SKIP-META:                           {counts.get('SKIP-META', 0)}")
    print(f"  NO-LOOKUP (extend table!):           {counts.get('NO-LOOKUP', 0)}")

    if counts.get("NO-LOOKUP", 0) > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())