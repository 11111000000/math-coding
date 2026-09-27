#!/usr/bin/env bash
# validate-and-context: context-capsule-truncated fixture
#
# Asserts that when --budget is too small to fit all items, the
# capsule reports truncated=true and the omitted[] array contains
# items with an `expansion` field (an `mc explain ...` command) so
# an LLM agent can fetch the missing context on demand. Per
# spec/semantics.md "context-prioritisation":
#
#   "When the budget is exhausted, items are dropped in reverse
#    priority order. The dropped items appear in the JSON `omitted`
#    array with an `expansion` command (e.g., `"mc explain
#    decision:Foo"`) so an LLM agent can fetch the missing context
#    on demand."
#
# Strategy: invoke `mc context main HEAD --budget 200` and grep for:
#   - "truncated":true in the JSON body
#   - "omitted":[ ... non-empty ... ] in the JSON body
#   - "expansion":"mc explain " somewhere in the omitted array
#
# Budget 200 is small enough to force truncation on any non-trivial
# math-coding repository (a typical decision file is >1 KiB and the
# 96-byte framing overhead per item means even a single RequiredForGate
# item needs 100+ bytes to be carried).

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "context-capsule-truncated:"

log=$(mktemp)
trap 'rm -f "$log"' EXIT

if ! nix develop .#test --command bash -c '
  dune build --root . bin/mathc.exe || exit 99
  _build/default/bin/mathc.exe context main HEAD --budget 200
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

# truncated must be true under a 200-byte budget on any real
# math-coding tree.
if ! printf '%s' "$body" | grep -q '"truncated":true'; then
  echo "  FAIL expected truncated:true under --budget 200" >&2
  cat "$log" >&2
  exit 1
fi

# omitted must be non-empty when truncated is true.
# Look for any expansion field with a non-empty list of references.
if ! printf '%s' "$body" | grep -q '"expansion":"mc explain '; then
  echo "  FAIL omitted[] lacks expansion command" >&2
  cat "$log" >&2
  exit 1
fi

echo "  ok   truncated:true with expansion in omitted[]"
exit 0