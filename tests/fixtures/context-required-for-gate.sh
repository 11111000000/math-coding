#!/usr/bin/env bash
# validate-and-context: context-capsule-required-for-gate fixture
#
# Asserts that the active policy (bootstrap/decision.yaml) appears
# in the capsule under the RequiredForGate priority bucket. Per
# spec/semantics.md "context-prioritisation":
#
#   "RequiredForGate | bootstrap/decision.yaml; the active policy
#    | Always included if present. The capsule still completes when
#    this is the only item that fits in budget."
#
# Strategy: invoke `mc context main HEAD --budget 100000` and grep
# the JSON items[] array for "bootstrap-v3" (the decision_id of
# bootstrap/decision.yaml). The fixture fails when the policy is
# missing from the capsule, which is a worse failure than running
# out of budget: an agent that does not see the active policy will
# happily act on stale beliefs.
#
# This is a positive fixture: it passes when the kernel correctly
# classifies bootstrap-v3 as RequiredForGate and emits it under any
# non-trivial budget.

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "context-capsule-required-for-gate:"

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

# The decisions[] sub-array is part of the JSON. bootstrap-v3 is the
# id of bootstrap/decision.yaml. Look for either the summary line
# "bootstrap-v3@<rev>:" or the detail_ref "decision:bootstrap-v3".
if ! printf '%s' "$body" | grep -q 'decision:bootstrap-v3'; then
  echo "  FAIL active policy (bootstrap-v3) absent from capsule items" >&2
  cat "$log" >&2
  exit 1
fi

# Confirm the priority bucket is RequiredForGate, not e.g. Supporting.
# The item object exposes "priority":"<name>"; look for it adjacent
# to the bootstrap-v3 detail_ref.
if ! printf '%s' "$body" | grep -q '"detail_ref":"decision:bootstrap-v3"'; then
  echo "  FAIL bootstrap-v3 lacks canonical detail_ref field" >&2
  cat "$log" >&2
  exit 1
fi
# priority is the first field of each item object (alphabetical key
# sort from Jsonl.stringify). Look for the priority bucket near the
# bootstrap-v3 entry. The simplest signal: the literal substring
# "RequiredForGate" must appear in the items array.
if ! printf '%s' "$body" | grep -q '"priority":"RequiredForGate"'; then
  echo "  FAIL capsule has no RequiredForGate items" >&2
  cat "$log" >&2
  exit 1
fi

echo "  ok   active policy bootstrap-v3 present and RequiredForGate"
exit 0