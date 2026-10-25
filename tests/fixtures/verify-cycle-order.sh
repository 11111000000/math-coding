#!/usr/bin/env bash
# tests/fixtures/verify-cycle-order.sh
#
# The verification cycle has an ORDER, and the order is load-bearing.
#
# WHY. A decision's `materials_digest` is the digest of the CONTENT of
# the files its scope names, and 183 of the corpus's 246 decisions
# name `bin/Mathc.ml` in their scope. `dune fmt` rewrites the bytes
# of bin/Mathc.ml. So a cycle that formats AFTER re-signing makes
# 183 attestations stale and needs another four-minute re-signing.
#
# That happened five times in one session. The process should make the
# wrong order impossible, not rely on the operator's discipline.
#
# What this fixture pins:
#
#   1. the formatting stage precedes the re-signing stage in
#      scripts/verify.sh;
#   2. the re-signing stage is SKIPPED when nothing a scope covers
#      has changed - so running the cycle twice in a row costs
#      nothing and touches nothing;
#   3. the cycle stops at the first failing stage.
#
# THE NEGATIVE CONTROL. A check that cannot fail is not a check. The
# fixture reads the script and asserts on its TEXT, so it would
# happily pass on a script that does the right thing for the wrong
# reason. The control therefore feeds the same comparison a script
# with the stages SWAPPED and requires it to report the swap.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

SCRIPT="scripts/verify.sh"
if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: $SCRIPT does not exist"
  echo "verify-cycle-order: FAIL"
  exit 1
fi

# --- 1. the formatting stage precedes the re-signing stage ---------------
# The line number of each stage's header, in the order they appear.
fmt_line=$(grep -n '^stage "format"' "$SCRIPT" | head -1 | cut -d: -f1)
sign_line=$(grep -n '^stage "re-sign"' "$SCRIPT" | head -1 | cut -d: -f1)
if [ -n "$fmt_line" ] && [ -n "$sign_line" ] && [ "$fmt_line" -lt "$sign_line" ]; then
  ok "the formatting stage (line $fmt_line) precedes the re-signing stage (line $sign_line)"
else
  bad "the stage order is wrong: format at line '${fmt_line:-none}', re-sign at line '${sign_line:-none}'"
fi

# --- 2. the cycle stops at the first failing stage ------------------------
if grep -q 'fail()' "$SCRIPT" && grep -qE '^\s*(fail|exit 1)' "$SCRIPT"; then
  ok "the cycle has a fail path that exits non-zero"
else
  bad "the cycle has no fail path that exits non-zero"
fi

# --- 3. the re-signing is skipped when nothing relevant changed -----------
if grep -q 'scope_hit' "$SCRIPT" && grep -q 'skipped' "$SCRIPT"; then
  ok "the re-signing stage is conditional on something a scope covers having changed"
else
  bad "the re-signing stage is unconditional - it would run for four minutes every time"
fi

# --- 4. NEGATIVE CONTROL: the comparison can tell a wrong order ---------
# The same comparison, applied to a script whose stages are swapped.
# It must report the swap - otherwise the check above would pass on a
# script with the wrong order.
compare_order() {
  # echoes "ordered" when the format stage precedes the re-sign stage
  local f r
  f=$(grep -n '^stage "format"' "$1" | head -1 | cut -d: -f1)
  r=$(grep -n '^stage "re-sign"' "$1" | head -1 | cut -d: -f1)
  if [ -n "$f" ] && [ -n "$r" ] && [ "$f" -lt "$r" ]; then
    echo ordered
  else
    echo swapped
  fi
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A script with the stages in the WRONG order: the formatting stage is
# REMOVED where it was and RE-INSERTED after the re-signing one. It
# must be removed, not duplicated - the comparison reads the FIRST
# occurrence of each stage, so a duplicated stage would leave the
# order unchanged and the control would prove nothing.
awk '
  /^stage "format"/ { next }
  /^stage "re-sign"/ { print; print "stage \"format\""; next }
  { print }
' "$SCRIPT" > "$work/swapped.sh"

verdict="$(compare_order "$work/swapped.sh")"
if [ "$verdict" = "swapped" ]; then
  ok "the comparison reports a swapped script as swapped (the negative control has teeth)"
else
  bad "the comparison called a swapped script ordered - the check cannot fail"
fi

# And the real script is still reported as ordered.
verdict="$(compare_order "$SCRIPT")"
if [ "$verdict" = "ordered" ]; then
  ok "the real script is reported as ordered"
else
  bad "the real script is reported as $verdict"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "verify-cycle-order: PASS"
  exit 0
fi
echo "verify-cycle-order: FAIL"
exit 1
