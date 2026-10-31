#!/usr/bin/env bash
# The applicability rule has one home: spec/algebra-3.2.md §28.
#
# Three surfaces carry it — the normative algebra, the agent-facing
# skill, and the envelope `mathc init` prints at deploy time. A rule
# stated three times is a rule that will drift, and the drift is
# invisible to a gate that verifies each surface separately: two
# mutually exclusive policies can both be green at the same time.
# This script is the invariant that makes the drift visible.
#
# Exits 0 on full pass, 1 on any failure.

set -eu

cd "$(git rev-parse --show-toplevel)"

fail=0

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    :
  else
    fail=1
    printf 'FAIL: %s\n' "$desc" >&2
  fi
}

# 1. The normative text still states the default-on rule.
check "spec/algebra-3.2.md §28 no longer states default_path(P) = Path A unless throwaway" \
  "grep -q 'default_path(P) ≔ Path A unless P ∈ prototype_or_throwaway(P)' spec/algebra-3.2.md"

# 2. The skill states the same default and cites the authority instead
#    of restating a second rule.
check "adoption/SKILL.md does not state the default-on rule" \
  "grep -q 'Default: apply\.' adoption/SKILL.md"

check "adoption/SKILL.md does not cite spec/algebra-3.2.md" \
  "grep -q 'spec/algebra-3.2.md' adoption/SKILL.md"

# 3. The CLI prints the envelope it claims to print.
check "lib/init/init.ml no longer prints the default-on envelope" \
  "grep -q 'Installed by default, a single maintainer included' lib/init/init.ml"

# 4. The superseded opt-in rule is gone from the skill. It is quoted in
#    the corpus decisions; in the skill it would be a second live rule.
check "adoption/SKILL.md still carries the superseded opt-in rule" \
  "! grep -q 'burden of proof sits on the application' adoption/SKILL.md"

if [ "$fail" = "1" ]; then
  exit 1
fi

echo "PASS: the applicability rule is stated once, and the three surfaces agree"
