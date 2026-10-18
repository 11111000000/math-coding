#!/usr/bin/env bash
# Verifier wrapper for ux-3-adoption-doc-freshen-2026-10.yaml.
# Closes the doc-freshening obligations by checking that
# adoption/SKILL.md and USAGE.md carry the schema-string bump
# and the mathc explain-diagnostic reference.
#
# Exits 0 on full pass, 1 on any failure.

set -eu

cd "$(git rev-parse --show-toplevel)"

fail=0
fail_msg=""

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    :
  else
    fail=1
    fail_msg="${fail_msg}FAIL: ${desc}\n"
  fi
}

# adoption/SKILL.md
check "adoption/SKILL.md missing 'math-coding/3.3'" \
      "grep -q 'math-coding/3\\.3' adoption/SKILL.md"

check "adoption/SKILL.md still contains 'math-coding/3.0-alpha' as a decision schema" \
      "! grep -q '^schema: math-coding/3\\.0-alpha' adoption/SKILL.md"

check "adoption/SKILL.md missing 'outcomes:' block in example" \
      "grep -q '^outcomes:' adoption/SKILL.md"

check "adoption/SKILL.md missing 'bootstrap-v3@3' pin" \
      "grep -q 'bootstrap-v3@3' adoption/SKILL.md"

check "adoption/SKILL.md missing 'mathc explain-diagnostic' reference" \
      "grep -q 'mathc explain-diagnostic' adoption/SKILL.md"

# ux-3-adoption-doc-freshen-2026-10@2: the literal 3.1.0-alpha-final is
# now absent (the install-tooling-2026-10 default tag moved to 'edge');
# the doc must reference the new URL.
check "adoption/SKILL.md still carries the legacy '3.1.0-alpha-final' tag" \
      "! grep -q '3\\.1\\.0-alpha-final' adoption/SKILL.md"
check "adoption/SKILL.md missing 'releases/download/edge/install.sh' URL" \
      "grep -q 'releases/download/edge/install.sh' adoption/SKILL.md"

# USAGE.md
check "USAGE.md missing 'mathc explain-diagnostic' reference" \
      "grep -q 'mathc explain-diagnostic' USAGE.md"

if [ "$fail" = "1" ]; then
  printf "$fail_msg" >&2
  exit 1
fi

echo "PASS: ux-3 adoption doc freshen verified (adoption/SKILL.md + USAGE.md)"
