#!/usr/bin/env bash
# validate-and-context: context-capsule-priority-order fixture
#
# Asserts that the top-level JSON items[] array is priority-ordered:
#   RequiredForGate > Changed > HighRisk > Unresolved >
#   Supporting > Historical
# Per spec/semantics.md "context-prioritisation":
#
#   "The order is normative; an agent MUST NOT silently reorder or
#    rebucket items."
#
# Strategy: invoke `mc context main HEAD --budget 100000`, then use
# `jq` to walk the items[] array, extract each item's `priority`
# field, and verify the sequence is monotonically non-decreasing
# under the rank:
#   RequiredForGate=0 < Changed=1 < HighRisk=2 < Unresolved=3 <
#   Supporting=4 < Historical=5
#
# The body has several arrays ("change.items", "decisions",
# "items"). Each is sorted by priority independently. We check
# ONLY the top-level "items" array; an earlier version of this
# fixture made the mistake of comparing positions across arrays.

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "context-capsule-priority-order:"

log=$(mktemp)
trap 'rm -f "$log"' EXIT

if ! nix develop .#test --command bash -c '
  dune build --root . bin/mathc.exe || exit 99
  _build/default/bin/mathc.exe context main HEAD --budget 100000
  echo INNER_EC=$?
' >"$log" 2>&1; then
  echo "  FAIL wrapper exited nonzero" >&2
  cat "$log" >&2
  exit 1
fi

inner_ec=$(grep '^INNER_EC=' "$log" | tail -1 | cut -d= -f2)
if [ "$inner_ec" != "0" ]; then
  echo "  FAIL mc context exited $inner_ec (expected 0)" >&2
  cat "$log" >&2
  exit 1
fi

# Strip everything from INNER_EC onward, leaving the JSON body.
# The wrapper also emits nix dev shell banner / warnings before the
# JSON; pick the first line that looks like the start of a JSON
# object ('{') and use that.
body=$(sed -n '/^INNER_EC=/!p' "$log" | grep -m1 '^{')

# Walk items[].priority and verify the sequence is monotonically
# non-decreasing under the rank function below.
ranks=$(printf '%s' "$body" \
  | jq -r '.items[].priority' 2>/dev/null)

if [ -z "$ranks" ]; then
  echo "  FAIL jq produced no items[]" >&2
  cat "$log" >&2
  exit 1
fi

priority_rank() {
  case "$1" in
    RequiredForGate) echo 0 ;;
    Changed)          echo 1 ;;
    HighRisk)         echo 2 ;;
    Unresolved)       echo 3 ;;
    Supporting)       echo 4 ;;
    Historical)       echo 5 ;;
    *)                echo 99 ;;
  esac
}

prev=-1
line=0
while IFS= read -r prio; do
  line=$((line + 1))
  rank=$(priority_rank "$prio")
  if [ "$rank" -lt "$prev" ]; then
    echo "  FAIL items[$line]=$prio (rank=$rank) follows a higher-priority item (rank=$prev)" >&2
    exit 1
  fi
  prev=$rank
done <<EOF_RANKS
$ranks
EOF_RANKS

echo "  ok   items[] priority ordering preserved ($line items)"
exit 0