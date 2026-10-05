#!/usr/bin/env bash
# tests/fixtures/full-decision-memory-skips-retired.sh
#
# Verifier for decisions/full-decision-memory.yaml obligation
# `load-decisions-skips-retired` (positive case).
#
# Confirms that decisions whose top-level `state: retired`
# (currently only `portable-linux-musl@2`) do not appear in
# the capsule as decision items, even though they still appear
# in `mc packages` as enumerated obligations.

set -uo pipefail
cd "$(dirname "$0")/../.."

out=$(MATH_CODING_ROOT="$PWD" _build/default/bin/mathc.exe \
        context HEAD HEAD --budget 65536 2>&1)

# A retired decision would appear as `decision:portable-linux-musl`
# in either items[] or omitted[]. The state of HEAD is:
#   - decisions/portable-linux-musl.yaml: state: retired
# We assert that no `decision:portable-linux-musl` reference
# appears in the capsule.
if echo "$out" | grep -q 'decision:portable-linux-musl'; then
  echo "FAIL: retired 'portable-linux-musl' appears in capsule"
  echo "$out" | grep 'portable-linux-musl' | head -3
  exit 1
fi

echo "ok: retired 'portable-linux-musl' correctly excluded from capsule"
exit 0
