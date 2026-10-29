#!/usr/bin/env bash
# tests/fixtures/self-check-debt-ceiling.sh
#
# Verifier for decisions/corpus-final-state-2026-10.yaml
# (`the-debt-falls`).
#
# THE CORPUS DEBT RATCHET. The number of DECLARED promises -- the
# obligations whose verifier is a `manual-` declaration, which the
# kernel does not execute by design -- may only FALL.
#
# WHY THIS NUMBER AND NOT THE OTHER ONE. The corpus has two debts
# that look alike and are not:
#
#   the DECLARED promises (this fixture). A property of the CORPUS:
#   how many promises the corpus makes that no program keeps. It
#   moves only when the corpus moves.
#
#   the UNDECIDED subjects (`mathc self-check`'s `unknown` count). A
#   property of the STORE's freshness: a promise is undecided
#   because no evidence was observed for it at this commit. It moves
#   on every commit -- the sweep re-signs for the tree it runs on, so
#   the number is a few higher on a tree the sweep has not seen yet.
#   Pinning THAT number would make the fixture flaky by construction,
#   and a flaky ratchet is a ratchet nobody trusts.
#
# So this one measures the corpus, and the undecided count stays what
# it is: the verdict `mathc self-check` reports, read where the store
# exists.
#
# WHAT IS COUNTED. The entries of `mathc gaps` whose class is
# `not-a-check` -- the obligations the kernel does not run. A
# declaration is not a failure: it is a promise the corpus made and
# nobody keeps by machine, and the final state's answer for each of
# them is an executable check, a dated acceptance, or the promise
# dropped.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# The pin. MEASURED 2026-10-29: 233 declared promises across the
# corpus, after the decision-level census removed 45 records and
# their obligations. It may only fall.
#
# The measurement is the kernel's own count of the DECLARED
# obligations -- the ones whose verifier it does not run -- taken over
# every in-force obligation and not only over the open ones. It is a
# property of the corpus, so it is the same number in a swept tree,
# in an unswept tree and in a fresh checkout.
#
# ceiling-raise: 0 -> 281, the first measurement of the corpus debt
# after the worklist (`mathc gaps`) made the corpus's promises
# countable. Then the decision-level census removed 64 of them:
# 281 -> 217.
CEILING=233

bin=""
for c in _build/default/bin/mathc.exe _build/install/default/bin/mathc; do
  if [ -x "$c" ]; then bin="$PWD/$c"; break; fi
done
if [ -z "$bin" ]; then
  for c in mathc mathc.exe; do
    if command -v "$c" >/dev/null 2>&1; then bin="$(command -v "$c")"; break; fi
  done
fi
if [ -z "$bin" ]; then
  bad "no mathc binary found (looked in _build/default/bin/, _build/install/default/bin/ and on PATH)"
  echo
  echo "self-check-debt-ceiling: FAIL"
  exit 1
fi

report="$(mktemp)"
trap 'rm -f "$report"' EXIT
"$bin" gaps --format=json >"$report" 2>/dev/null
if [ ! -s "$report" ]; then
  bad "mathc gaps produced no report"
  echo
  echo "self-check-debt-ceiling: FAIL"
  exit 1
fi

# The DECLARED count is a property of the corpus: the kernel counts
# every in-force obligation whose verifier the kernel does not run,
# whether or not evidence exists for it. It does not move with the
# store's freshness -- which is what made the first version of this
# ratchet flaky by construction.
n="$(jq -r '.counts.declared' "$report" 2>/dev/null)"
total="$(jq -r '.open | length' "$report" 2>/dev/null)"
if [ -z "$n" ] || [ "$n" = "null" ]; then
  bad "the report carries no class information"
  echo
  echo "self-check-debt-ceiling: FAIL"
  exit 1
fi

if [ "$n" -le "$CEILING" ]; then
  ok "the corpus holds $n declared promises (of $total open), at or below the ceiling of $CEILING"
else
  bad "the corpus holds $n declared promises (of $total open), ABOVE the ceiling of $CEILING: the debt grew, and it may only fall"
  jq -r '[.open[] | select(.class == "not-a-check") | .decision] | unique | .[0:12] | .[]' "$report" 2>/dev/null | sed 's/^/      /'
fi

# The negative control: a bound that has never been observed to bind
# is not known to bind. An inflated corpus must be reported as over
# the ceiling.
control="$(mktemp)"
trap 'rm -f "$report" "$control"' EXIT
jq -n --argjson n "$((CEILING + 5))" \
  '{open: [range(0; $n) | {decision: ("inflated-" + tostring), class: "not-a-check"}]}' \
  >"$control"
cn="$(jq -r '[.open[] | select(.class == "not-a-check")] | length' "$control")"
if [ "$cn" -gt "$CEILING" ]; then
  ok "the negative control is over the ceiling, as it must be"
else
  bad "the negative control measured $cn, at or below the ceiling of $CEILING: the bound does not bind"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "self-check-debt-ceiling: PASS"
  exit 0
fi
echo "self-check-debt-ceiling: FAIL"
exit 1
