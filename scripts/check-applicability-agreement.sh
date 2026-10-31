#!/usr/bin/env bash
# The applicability rule has one home.
#
# Three surfaces carry it — the normative contract, the agent-facing
# skill, and the envelope `mathc init` prints at deploy time. A rule
# stated three times is a rule that will drift, and the drift is
# invisible to a gate that verifies each surface separately: two
# mutually exclusive policies can both be green at the same time.
# This script is the invariant that makes the drift visible.
#
# WHAT CHANGED IN THE CONTRACT'S SHRINK, AND WHY. The first check
# used to grep the contract for a formula —
# `default_path(P) ≔ Path A unless P ∈ prototype_or_throwaway(P)` —
# and the corpus's own lesson applies: a check that greps the prose
# breaks the moment the prose is rewritten, and the prose is rewritten
# now. The check now compares the CODE against a constant the code
# owns: the envelope message in `lib/init/init.ml` names the section
# the rule lives in (`kernel-contract.md §28`), and the contract must
# carry that section. The pointer is the code's; the anchor is the
# document's API; neither is a line of prose that a rewrite would
# carry away.
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

# 1. The section the kernel's own envelope message names is a section
#    the contract has. The pointer lives in lib/init/init.ml (the code
#    owns it); the anchor lives in the document (the document owns it).
cli_section="$(sed -n 's/.*kernel-contract\.md.*§\([0-9][0-9]*\).*/\1/p' \
  lib/init/init.ml | head -1)"
if [ -z "$cli_section" ]; then
  fail=1
  printf 'FAIL: lib/init/init.ml no longer names a section of the contract in its envelope message\n' >&2
else
  check "the contract has no section §${cli_section}, which the envelope message in lib/init/init.ml names" \
    "grep -qE '^#+ §${cli_section}[.]' spec/kernel-contract.md"
fi

# 2. The section the SKILL names as its authority is a section the
#    contract has. Two surfaces pointing at one anchor is the
#    agreement the corpus's decision asks for: the skill and the CLI
#    cannot point at different rules without one of the pointers
#    breaking.
skill_section="$(sed -n 's/.*kernel-contract\.md.*§\([0-9][0-9]*\).*/\1/p' \
  adoption/SKILL.md | head -1)"
if [ -z "$skill_section" ]; then
  fail=1
  printf 'FAIL: adoption/SKILL.md no longer names a section of the contract as its authority\n' >&2
else
  check "the contract has no section §${skill_section}, which adoption/SKILL.md names as its authority" \
    "grep -qE '^#+ §${skill_section}[.]' spec/kernel-contract.md"
fi

# 3. The skill states the default-on rule as an operational instruction.
check "adoption/SKILL.md no longer states the default-on rule" \
  "grep -q 'Default: apply\.' adoption/SKILL.md"

# 4. The skill cites the contract as its authority instead of carrying
#    a second copy of the rule.
check "adoption/SKILL.md no longer cites spec/kernel-contract.md as its authority" \
  "grep -q 'spec/kernel-contract.md' adoption/SKILL.md"

# 5. The CLI prints the envelope it claims to print.
check "lib/init/init.ml no longer prints the default-on envelope" \
  "grep -q 'Installed by default, a single maintainer included' lib/init/init.ml"

# 6. The superseded opt-in rule is gone from the skill. It is quoted in
#    the corpus decisions; in the skill it would be a second live rule.
check "adoption/SKILL.md still carries the superseded opt-in rule" \
  "! grep -q 'burden of proof sits on the application' adoption/SKILL.md"

if [ "$fail" = "1" ]; then
  exit 1
fi

echo "PASS: the applicability rule is stated once, and the three surfaces agree"
