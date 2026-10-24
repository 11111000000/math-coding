#!/usr/bin/env bash
# tests/fixtures/failing-subject-backlog.sh — the backlog of decisions
# whose obligations genuinely FAIL, as a bounded number.
#
# WHAT THIS IS. The attestation store used to say `pass` for 763
# obligations, and 765 of those attestations carried an EMPTY
# materials_digest — which the gate treats as a WILDCARD, fresh for
# every tree, for ever. So the store reported a corpus that was
# verified and was not.
#
# Re-signing every attestation by actually RUNNING the obligation's
# own verifier produced the first honest number the project has ever
# had: some obligations pass, some cannot be executed here, and some
# FAIL. The failing ones are this backlog.
#
# WHY A CEILING. A backlog that is only reported grows silently — the
# corpus went from 68 attestations to 943 in four weeks and nothing
# anywhere said so. A ceiling makes it monotone: the number may fall,
# it may never rise. And it makes the CI gate USABLE: while the
# backlog is being paid down the gate stays green, and the moment a
# NEW failure appears the gate goes red.
#
# WHY NOT A WAIVER. A waiver cannot cover a failed check. The
# constitution says so ("a waiver MUST NOT convert fail, unknown or
# missing into pass"), and the kernel enforces it: FailedEvidence is
# not waivable. The repo's own remedy list - "revert the change that
# broke this obligation, or add a waiver" - is wrong for a failed
# check, and this fixture exists to make the difference visible.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# The ceiling. Measured 2026-10-24, immediately after the
# per-obligation re-signing. It may only fall.
CEILING=37

bin="${MATHC_BIN:-}"
if [ -z "$bin" ]; then
  if [ -x "_build/default/bin/mathc.exe" ]; then
    bin="$PWD/_build/default/bin/mathc.exe"
  elif [ -x "_build/install/default/bin/mathc" ]; then
    bin="$PWD/_build/install/default/bin/mathc"
  elif command -v mathc >/dev/null 2>&1; then
    bin="$(command -v mathc)"
  fi
fi
if [ -z "$bin" ]; then
  bad "no mathc binary found"
  echo "failing-subject-backlog: FAIL"
  exit 1
fi

out="$("$bin" self-check 2>/dev/null)" || true
count="$(printf '%s' "$out" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print(-1); raise SystemExit
print(sum(1 for s in d.get("subjects", []) if s.get("verdict") == "fail"))
')"

if [ "$count" -lt 0 ]; then
  bad "could not read the self-check verdict"
  echo "failing-subject-backlog: FAIL"
  exit 1
fi

if [ "$count" -le "$CEILING" ]; then
  ok "failing subjects: $count (ceiling $CEILING)"
else
  bad "failing subjects: $count EXCEEDS the ceiling $CEILING — the backlog grew"
fi

# The negative control: a store that cannot be read must not be
# reported as zero failures.
if printf '%s' "$out" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print("unparseable"); raise SystemExit
print("ok" if isinstance(d.get("subjects"), list) else "unparseable")
' | grep -q ok; then
  ok "the measurement parses a real verdict, so the count is not vacuous"
else
  bad "the measurement could not parse a verdict — the count may be vacuous"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "failing-subject-backlog: PASS"
  exit 0
fi
echo "failing-subject-backlog: FAIL"
exit 1
