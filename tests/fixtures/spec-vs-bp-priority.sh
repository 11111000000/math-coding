#!/usr/bin/env bash
# priority-drift: priority-drift-detector fixture
#
# Asserts that the priority-ordering line in spec/semantics.md
# ("context-prioritisation") is byte-equivalent (modulo whitespace)
# to the mirror line in OCAML_BEST_PRACTICES.md §10.5. The spec is
# the authoritative source per bootstrap/validate-and-context.md
# (line 124, countercase); the practices file mirrors the table for
# implementer convenience. A drift means one was edited without
# the other.
#
# This is the acceptance gate for obligation priority-drift-detector
# in bootstrap/priority-drift.yaml.
#
# Strategy: locate the line beginning with `RequiredForGate` in each
# file. That line is the normative ordering (six priority names
# separated by ` > `). Both files declare the table inside a
# ```text block, so the line starts at column 1 and is unique.
# Normalise whitespace (collapse runs of spaces, trim) and compare.
#
# Verdict:
#   exit 0 — both files contain the same priority-ordering line, OR
#            neither file contains one (no drift; presence is a
#            separate obligation).
#   exit 1 — files disagree, or exactly one of them is missing the
#            line. On failure, print a unified diff of the two
#            files' lines for the human reviewer.

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "spec-vs-bp-priority:"

spec=spec/semantics.md
bp=OCAML_BEST_PRACTICES.md

# Find the priority-ordering line: a line whose first non-space
# character is the start of the ordering (RequiredForGate). The
# six names are space-pipe-separated by ` > ` so the line is easy
# to recognise with grep.
spec_line=$(grep -E '^[[:space:]]*RequiredForGate\b.*>.*>.*>.*>.*>' "$spec" 2>/dev/null \
              | head -1 \
              | sed -E 's/^[[:space:]]+//; s/[[:space:]]+/ /g')
bp_line=$(grep -E '^[[:space:]]*RequiredForGate\b.*>.*>.*>.*>.*>' "$bp" 2>/dev/null \
            | head -1 \
            | sed -E 's/^[[:space:]]+//; s/[[:space:]]+/ /g')

# Both absent — no drift to detect. Per the parent task instruction
# for this fixture, the absence of a table in both files is not a
# drift condition (presence is enforced separately if at all).
if [ -z "$spec_line" ] && [ -z "$bp_line" ]; then
  echo "  ok   no priority-ordering line in either file (no drift)"
  exit 0
fi

# Exactly one missing — that is a drift (the spec and the practice
# disagree about whether the table exists).
if [ -z "$spec_line" ]; then
  echo "  FAIL priority-ordering line present in $bp but absent in $spec" >&2
  echo "  --- $bp" >&2
  echo "  +++ $spec (absent)" >&2
  exit 1
fi
if [ -z "$bp_line" ]; then
  echo "  FAIL priority-ordering line present in $spec but absent in $bp" >&2
  echo "  --- $bp (absent)" >&2
  echo "  +++ $spec" >&2
  echo "  $spec_line" >&2
  exit 1
fi

# Both present — compare the normalised lines.
if [ "$spec_line" = "$bp_line" ]; then
  echo "  ok   priority-ordering line matches: $spec_line"
  exit 0
fi

echo "  FAIL priority-ordering line drifted between $spec and $bp §10.5" >&2
diff <(printf '%s\n' "$spec_line") <(printf '%s\n' "$bp_line") >&2 || true
exit 1
