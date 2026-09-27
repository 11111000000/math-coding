#!/usr/bin/env bash
# time-honesty: time-storage subcommand fixture
#
# Asserts that `mc session-start`, `mc record`, and `mc stats`
# together form a complete pipeline. session-start writes a fixed
# ISO 8601 UTC anchor; record appends events to
# bootstrap/execution-logs.jsonl; stats emits an aggregate JSON.
# This is the acceptance gate for obligations cli-session-start,
# cli-record, cli-stats declared in bootstrap/time-honesty-storage.yaml.
#
# Strategy:
#   - Use MATH_CODING_FIXED_TIME to make session-start deterministic
#   - Verify record rejects --value for --scale wall-clock-minutes
#   - Verify record requires --value for --scale step-count
#   - Verify record emits MC-SESSION-MISSING without prior session-start
#   - Verify stats emits aggregate JSON with the expected shape

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "cli-time-storage:"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export MATH_CODING_ROOT=$PWD

# Clean any prior state in case a previous test left artifacts.
rm -f .local/session-start bootstrap/execution-logs.jsonl

BIN=$PWD/_build/default/bin/mathc.exe

# Build once.
nix develop .#test --command bash -c "dune build --root . bin/mathc.exe" >/dev/null 2>&1 || {
  echo "  FAIL dune build failed" >&2
  exit 1
}

# 1. session-start writes a deterministic timestamp.
MATH_CODING_FIXED_TIME=2026-09-27T07:07:17Z \
  MATH_CODING_USER=human:test@local \
  "$BIN" session-start >"$tmp/v1.out" 2>"$tmp/v1.err"
v1_ec=$?
v1=$(cat "$tmp/v1.out")
if [ "$v1_ec" != "0" ]; then
  echo "  FAIL session-start: exit $v1_ec (expected 0)" >&2
  echo "stderr: $(cat "$tmp/v1.err")" >&2
  exit 1
fi
if ! printf '%s' "$v1" | grep -q '"2026-09-27T07:07:17Z"'; then
  echo "  FAIL session-start did not echo MATH_CODING_FIXED_TIME" >&2
  echo "$v1" >&2
  exit 1
fi

# 2. record --scale wall-clock-minutes --value: rejected.
"$BIN" record --decision-id bootstrap-v3 \
  --scale wall-clock-minutes --value 5 >"$tmp/v2.out" 2>"$tmp/v2.err"
v2_ec=$?
v2_err=$(cat "$tmp/v2.err")
if [ "$v2_ec" != "2" ]; then
  echo "  FAIL wall-clock-value: exit $v2_ec (expected 2)" >&2
  exit 1
fi
if ! printf '%s' "$v2_err" | grep -q -- '--value rejected for --scale wall-clock-minutes'; then
  echo "  FAIL wall-clock-value: stderr must reject --value" >&2
  echo "$v2_err" >&2
  exit 1
fi

# 3. record without session-start: MC-SESSION-MISSING.
rm -f .local/session-start
"$BIN" record --decision-id bootstrap-v3 \
  --scale wall-clock-minutes --class feature-add >"$tmp/v3.out" 2>"$tmp/v3.err"
v3_ec=$?
v3_err=$(cat "$tmp/v3.err")
if [ "$v3_ec" != "2" ]; then
  echo "  FAIL missing-session: exit $v3_ec (expected 2)" >&2
  exit 1
fi
if ! printf '%s' "$v3_err" | grep -q 'MC-SESSION-MISSING'; then
  echo "  FAIL missing-session: stderr must include MC-SESSION-MISSING" >&2
  echo "$v3_err" >&2
  exit 1
fi

# 4. record --scale step-count: --value required.
"$BIN" record --decision-id bootstrap-v3 \
  --scale step-count >"$tmp/v4.out" 2>"$tmp/v4.err"
v4_ec=$?
v4_err=$(cat "$tmp/v4.err")
if [ "$v4_ec" != "2" ]; then
  echo "  FAIL step-count-required: exit $v4_ec (expected 2)" >&2
  exit 1
fi
if ! printf '%s' "$v4_err" | grep -q -- '--value is required for --scale step-count'; then
  echo "  FAIL step-count-required: stderr must flag --value as required" >&2
  echo "$v4_err" >&2
  exit 1
fi

# 5. stats with no events: n=0, warning set, quantiles omitted.
rm -f bootstrap/execution-logs.jsonl
"$BIN" stats >"$tmp/v5.out" 2>"$tmp/v5.err"
v5_ec=$?
v5=$(cat "$tmp/v5.out")
if [ "$v5_ec" != "0" ]; then
  echo "  FAIL stats-empty: exit $v5_ec (expected 0)" >&2
  exit 1
fi
if ! printf '%s' "$v5" | grep -q '"n":0'; then
  echo "  FAIL stats-empty: must report n:0" >&2
  echo "$v5" >&2
  exit 1
fi
if ! printf '%s' "$v5" | grep -q 'insufficient samples'; then
  echo "  FAIL stats-empty: must emit insufficient-samples warning" >&2
  echo "$v5" >&2
  exit 1
fi

# 6. stats with 36 sequential step-count writes: quantiles emitted.
for i in $(seq 1 36); do
  "$BIN" record --decision-id bootstrap-v3 \
    --scale step-count --value $i >/dev/null 2>&1
done
"$BIN" stats --scale step-count >"$tmp/v6.out" 2>"$tmp/v6.err"
v6_ec=$?
v6=$(cat "$tmp/v6.out")
if [ "$v6_ec" != "0" ]; then
  echo "  FAIL stats-36: exit $v6_ec (expected 0)" >&2
  exit 1
fi
if ! printf '%s' "$v6" | grep -q '"n":36'; then
  echo "  FAIL stats-36: must report n:36" >&2
  echo "$v6" >&2
  exit 1
fi
if ! printf '%s' "$v6" | grep -q '"p50":19'; then
  echo "  FAIL stats-36: p50 should be 19 (rounded from 18.5)" >&2
  echo "$v6" >&2
  exit 1
fi
if ! printf '%s' "$v6" | grep -q '"p99":36'; then
  echo "  FAIL stats-36: p99 should be 36" >&2
  echo "$v6" >&2
  exit 1
fi

# Clean up state we created.
rm -f .local/session-start bootstrap/execution-logs.jsonl

echo "  ok   session-start, record (3 rejection paths), stats (empty + 36)"
exit 0