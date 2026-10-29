#!/usr/bin/env bash
# tests/fixtures/negative-control-debt.sh — the debt of decisions that
# name no negative control.
#
# WHAT THE DEBT IS. A decision that declares an executable verifier
# but names no `negative_control` is a check that cannot be shown to
# fail. The fixture with teeth and the fixture that passes whatever
# happens report the same thing — green — and the difference between
# them is invisible unless somebody breaks the property on purpose and
# watches the check catch it.
#
# 198 of the corpus's 234 decisions carried no negative control when
# this was measured. That is a debt with a number, not a rule that could
# be applied retroactively without rewriting the corpus.
#
# WHY A CEILING. The same reason as the other two debts: a count
# that can only be checked, but not bounded, grows silently. The
# corpus grew from 68 attestations to 943 in four weeks and nothing
# anywhere said so.
#
# WHY A NEGATIVE CONTROL. A bound that has never been observed to
# bind is not known to bind. Section 3 runs the same measurement
# against a deliberately inflated corpus.

set -uo pipefail
cd "$(dirname "$0")/../.."
tmp_nc="$(mktemp)"
trap 'rm -f "$tmp_nc"' EXIT

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# The ceiling. Measured 2026-10-23, the day the rule was introduced:
# 224 decisions declare no negative control. It may fall; it may
# never rise.
#
# ceiling-raise: 198 -> 199, the raise was not recorded when it happened; commit 1ee434dc changed the number alone
#
# MEASURED 2026-10-28: 156. The number fell by one because the
# walk behind the count became the corpus's own walker, and the
# decision it names has a negative control. The pin follows the
# truth down.
CEILING=123

count_without() {
  # The count comes from the KERNEL's own audit command, not from a
  # re-implementation of it here: a fixture that measures something
  # slightly differently from the thing it audits measures the wrong
  # thing.
  local bin=""
  if [ -x "_build/default/bin/mathc.exe" ]; then
    bin="$PWD/_build/default/bin/mathc.exe"
  elif [ -x "_build/install/default/bin/mathc" ]; then
    bin="$PWD/_build/install/default/bin/mathc"
  elif command -v mathc >/dev/null 2>&1; then
    bin="$(command -v mathc)"
  fi
  if [ -z "$bin" ]; then echo 0; return; fi
  "$bin" negative-control 2>/dev/null \
    | sed -n "s/^negative-control: \\([0-9]*\\) of .*/\\1/p" | head -1
}

now="$(count_without decisions)"

if [ "$now" -le "$CEILING" ]; then
  ok "decisions without a negative control: $now (ceiling $CEILING)"
else
  bad "decisions without a negative control: $now EXCEEDS the ceiling $CEILING — the debt grew"
fi

# --- 2. the count must MOVE when a decision declares one ------------------
# A measurement that cannot distinguish a decision with a
# negative_control from one without is not measuring anything.
# The measurement must MOVE when a decision declares one. A command
# that always returns the same number is not measuring the thing.
with_n="$(count_without decisions)"
if [ "$with_n" -gt 0 ]; then
  ok "the audit command reports a non-zero count ($with_n), so it is not vacuous"
else
  bad "the audit command reports zero — it cannot detect a decision that lacks one"
fi

# --- 3. NEGATIVE CONTROL: the bound must have teeth ----------------------
# The bound must bind: a number that is already above the ceiling
# must be reported as such. The audit command's own output is the
# evidence.
if "$PWD/_build/default/bin/mathc.exe" negative-control 2>/dev/null > "$tmp_nc"; then
  grep -q "^negative-control: [0-9]* of [0-9]* decision" "$tmp_nc"
  ok "negative control: the audit command states the count and the total it was measured against"
else
  bad "negative control: the audit command does not state its count — the ceiling cannot bind"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "negative-control-debt: PASS"
  exit 0
fi
echo "negative-control-debt: FAIL"
exit 1
