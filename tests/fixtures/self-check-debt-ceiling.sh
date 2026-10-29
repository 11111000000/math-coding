#!/usr/bin/env bash
# tests/fixtures/self-check-debt-ceiling.sh
#
# The CORPUS DEBT RATCHET. The number of undecided subjects in
# `mathc self-check` may only FALL.
#
# WHY THIS EXISTS. The corpus-wide self-check is an AUDIT, not the
# merge gate: the merge gate is `mathc gate` over the diff a push
# introduced (decisions/gate-by-diff-2026-10.yaml), and the audit
# answers a different question -- how much of the corpus is covered by
# evidence observed at this commit. A step that is red for the same
# unrelated reason on every push is a step nobody reads, so `unknown`
# does not block. But "does not block" is not "does not matter": if
# the debt may grow freely, the corpus rots in silence.
#
# So the debt is PINNED here, and the pin may only fall. The number
# is the truth as of the day it was written; every promise the corpus
# discharges lowers the truth, and a lower truth is a pin someone has
# to lower by hand -- which is the point: the debt is paid down in
# public.
#
# WHAT IS COUNTED. The subjects whose verdict is not `pass`: an
# `unknown` (no fresh evidence), a `fail` (a decisive failure), an
# `open-with-waiver` (a gap covered by a waiver until its expiry).
# The count is the corpus's debt, whatever class the debt is in.
#
# THE REPORT. The self-check's JSON may be passed as the first
# argument (the CI step has one); otherwise the command is run here.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# The pin. MEASURED 2026-10-29: 98 undecided subjects (63 pass of
# 161), after the decision-level census removed 45 records and their
# obligations. It may only fall.
#
# ceiling-raise: 0 -> 112, the first measurement of the corpus debt
# after the worklist (`mathc gaps`) made the corpus's promises
# countable. The number is the truth as of this date; a lower number
# is a pin someone has to lower by hand.
CEILING=98

report="${1:-}"
tmp=""
if [ -z "$report" ]; then
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
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  "$bin" self-check >"$tmp" 2>/dev/null
  report="$tmp"
fi

if [ ! -s "$report" ]; then
  bad "the self-check report is missing or empty: $report"
  echo
  echo "self-check-debt-ceiling: FAIL"
  exit 1
fi

n="$(jq -r '[.subjects[] | select(.verdict != "pass")] | length' "$report" 2>/dev/null)"
if [ -z "$n" ] || [ "$n" = "null" ]; then
  bad "the report does not carry a subjects array: $report"
  echo
  echo "self-check-debt-ceiling: FAIL"
  exit 1
fi

total="$(jq -r '.subjects | length' "$report" 2>/dev/null)"
verdict="$(jq -r '.verdict' "$report" 2>/dev/null)"

if [ "$n" -le "$CEILING" ]; then
  ok "the corpus debt is $n of $total subjects (verdict $verdict), at or below the ceiling of $CEILING"
else
  bad "the corpus debt is $n of $total subjects (verdict $verdict), ABOVE the ceiling of $CEILING: the debt grew, and it may only fall"
  jq -r '[.subjects[] | select(.verdict != "pass") | .name] | .[0:12] | .[]' "$report" 2>/dev/null | sed 's/^/      /'
fi

# The negative control: a bound that has never been observed to bind
# is not known to bind. An inflated corpus must be reported as over
# the ceiling.
control="$(mktemp)"
trap 'rm -f "$tmp" "$control"' EXIT
jq -n --argjson n "$((CEILING + 5))" \
  '{verdict: "unknown", subjects: [range(0; $n) | {name: ("inflated-" + tostring), verdict: "unknown"}]}' \
  >"$control"
cn="$(jq -r '[.subjects[] | select(.verdict != "pass")] | length' "$control")"
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
