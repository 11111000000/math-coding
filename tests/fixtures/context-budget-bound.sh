#!/usr/bin/env bash
# validate-and-context: context-capsule-budget-bound fixture
#
# Asserts that when --budget is large enough to fit everything, the
# capsule reports truncated=false and total_bytes <= budget_bytes.
# This is the converse of context-truncated-omitted.sh and pins
# the invariant from spec/semantics.md:172-176:
#
#   "The capsule MUST log the byte count under `total_bytes` so the
#    budget is observable. The `truncated` flag MUST be `true` iff
#    the `omitted` array is non-empty."
#
# Strategy: invoke `mc context main HEAD --budget 100000` and grep
# for:
#   - "truncated":false in the JSON body
#   - "total_bytes":N where N <= 100000
#
# Budget 100000 (~100 KiB) is large enough that all known decisions,
# spec files, axioms, and OCAML_BEST_PRACTICES.md fit comfortably.
# If the corpus grows past this on a future PR, the budget can be
# raised; the invariant tested here is the inequality, not the
# specific number.

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "context-capsule-budget-bound:"

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

body=$(sed -n '/^INNER_EC=/!p' "$log")

# truncated must be false under a generous budget on this tree.
if ! printf '%s' "$body" | grep -q '"truncated":false'; then
  echo "  FAIL expected truncated:false under --budget 100000" >&2
  cat "$log" >&2
  exit 1
fi

# Extract total_bytes value (integer) and assert <= budget.
total_bytes=$(printf '%s' "$body" \
  | grep -oE '"total_bytes":[0-9]+' \
  | head -1 \
  | cut -d: -f2)
if [ -z "$total_bytes" ]; then
  echo "  FAIL total_bytes field not present or not an integer" >&2
  cat "$log" >&2
  exit 1
fi
if [ "$total_bytes" -gt 100000 ]; then
  echo "  FAIL total_bytes=$total_bytes exceeds budget 100000" >&2
  cat "$log" >&2
  exit 1
fi

echo "  ok   truncated:false and total_bytes=$total_bytes <= 100000"
exit 0