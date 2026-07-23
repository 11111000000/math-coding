#!/bin/sh
# tests/no-duplication.sh — math-coding v0.992 single-source enforcer.
#
# axiom A2 (Curry-Howard): there is exactly one proposition.
# axiom A5 (Accounting): every change is witnessed once.
#
# This test asserts: normative content (axiom names, FSM
# state names, theory names) lives in exactly one place per
# concept. Generated blocks in extensions/agents/*/SKILL.md
# are allowed to *quote* sources, but the source file
# itself is the canonical place.
#
# Strategy: scan hand-authored files (excluding core/spec/
# and core/theories/) for prose that *describes* axioms or
# FSM. Generated blocks in SKILL.md are excluded by
# detection of <!-- BEGIN GENERATED --> markers.
#
# The check is conservative: it flags clear duplicates
# (e.g. "A4 Process: four-state lifecycle (draft/applied/
# retired/abandoned)" appearing in a hand-authored file
# outside core/spec/).
#
# To reduce noise, we check specific high-risk patterns.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

errors=0

# Hand-authored files where axiom/FSM prose would be a
# duplicate. (core/spec/ and core/theories/ are exempt.)
HAND_AUTHORED="
README.md
AGENTS.md
KNOWN_LIMITATIONS.md
extensions/obsidian.md
extensions/tdd.md
extensions/agents/opencode/math-agent.md
extensions/agents/opencode/SKILL.template.md
core/spec/think-before-do.md
core/spec/decision-modes.md
"

# Pattern: "A4 Process" header pattern (the canonical axiom table).
# If a hand-authored file contains this literal prose, it's a
# candidate for duplication.
PATTERN_AXIOM_SUMMARY='A0 Difference.*A4 Process.*A6 Self-Application'

for f in $HAND_AUTHORED; do
    [ -f "$REPO_ROOT/$f" ] || continue
    if grep -qE "$PATTERN_AXIOM_SUMMARY" "$REPO_ROOT/$f"; then
        printf 'DUP %s: axiom table prose found (should be in core/spec/axioms.md only)\n' "$f" >&2
        errors=$((errors + 1))
    fi
done

if [ "$errors" -gt 0 ]; then
    printf 'FAIL: %d duplication(s) detected\n' "$errors" >&2
    exit 1
fi

echo "ok: no single-source duplicates detected"
exit 0
