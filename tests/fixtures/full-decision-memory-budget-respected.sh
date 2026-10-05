#!/usr/bin/env bash
# tests/fixtures/full-decision-memory-budget-respected.sh
#
# Verifier for decisions/full-decision-memory.yaml obligation
# `capsule-still-respects-budget` (positive case).
#
# Confirms that `mc context` continues to enforce the byte
# budget after the load_decisions expansion. With a small
# budget (e.g. 1024 bytes) the capsule must report
# `truncated: true` and `total_bytes <= budget`. With a
# generous budget (e.g. 64KB) the capsule must report
# `truncated: false`.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0

# Small budget -> truncated
out_small=$(MATH_CODING_ROOT="$PWD" _build/default/bin/mathc.exe \
             context HEAD HEAD --budget 1024 2>&1)
total_small=$(echo "$out_small" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
print(data['total_bytes'])
")
truncated_small=$(echo "$out_small" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
print(str(data['truncated']).lower())
")

if [ "$total_small" -gt 1024 ]; then
  echo "FAIL: small-budget total_bytes $total_small > 1024"
  fail=1
else
  echo "ok: small-budget total_bytes=$total_small <= 1024"
fi

if [ "$truncated_small" != "true" ]; then
  echo "FAIL: small-budget expected truncated=true, got $truncated_small"
  fail=1
else
  echo "ok: small-budget truncated=true"
fi

# Generous budget -> not truncated
out_big=$(MATH_CODING_ROOT="$PWD" _build/default/bin/mathc.exe \
           context HEAD HEAD --budget 65536 2>&1)
total_big=$(echo "$out_big" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
print(data['total_bytes'])
")
truncated_big=$(echo "$out_big" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
print(str(data['truncated']).lower())
")

if [ "$truncated_big" != "false" ]; then
  echo "FAIL: big-budget expected truncated=false, got $truncated_big"
  fail=1
else
  echo "ok: big-budget truncated=false"
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "ok: full-decision-memory budget still respected"
exit 0
