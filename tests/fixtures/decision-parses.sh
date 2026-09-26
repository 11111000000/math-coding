#!/usr/bin/env bash
# kernel-conformance-runner: parse-positive-and-negative-decision fixture
#
# Asserts that every fixture in fixtures/conformance/decision/ parses via
# Decision.parse_decision with the expected verdict:
#   - positive-*  -> parser must accept (Some _)
#   - negative-*  -> parser must reject (None)
#
# This fixture is the acceptance gate for obligation
# parse-positive-and-negative-decision in
# bootstrap/kernel-conformance-runner.yaml. Per-fixture pass/fail
# counting happens in OCaml (Alcotest summary), not in shell.
#
# Negative run (before this commit): positive-minimal.yaml is rejected
#   by Decision.parse_decision because the hand-rolled YAML loader in
#   tests/conformance.ml only handles flat top-level mappings, but the
#   fixture encodes a nested decision (intent, scope as list of
#   scope_target objects, obligations with nested acceptance).
#
# Positive run (after this commit): every decision fixture matches
#   its expected verdict and dune test exits 0 for the kernel
#   conformance suite.

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "decision-parses:"

# Build the runner executable first so failures here are surfaced
# immediately, not hidden behind dune test output.
log=$(mktemp)
trap 'rm -f "$log"' EXIT
if ! nix develop .#test --command bash -c 'dune build --root . tests/conformance.exe' \
     >"$log" 2>&1; then
  echo "  FAIL could not build tests/conformance.exe" >&2
  tail -30 "$log" >&2
  exit 1
fi

# Run the kernel conformance suite. Warnings during build are
# surfaced by the prior `dune build` step (with the default error
# mode); `dune test` itself has no --error-on-warnings flag.
if nix develop .#test --command bash -c \
     'dune test --root .' \
     >"$log" 2>&1; then
  echo "  ok   dune test passes the kernel conformance suite"
  exit 0
fi

# dune test failed. Find which decision fixture broke and surface it
# so the human knows where to look. The runner uses Alcotest test
# labels of the form "decision/<name> [expects=..., got=...]".
echo "  FAIL dune test reports a regression in the conformance runner" >&2

if grep -E '^\s*\[FAIL\]\s+fixtures\s+[0-9]+\s+decision/' "$log" >/dev/null; then
  failed=$(grep -E '^\s*\[FAIL\]\s+fixtures\s+[0-9]+\s+decision/' "$log" \
             | head -5)
  echo "       failing decision fixture(s):" >&2
  echo "$failed" | sed 's/^/         /' >&2
elif grep -E 'positive fixture.*was rejected by parser' "$log" >/dev/null; then
  offender=$(grep -E 'positive fixture.*was rejected by parser' "$log" \
               | head -1)
  echo "       $offender" >&2
elif grep -E 'negative fixture.*was accepted by parser' "$log" >/dev/null; then
  offender=$(grep -E 'negative fixture.*was accepted by parser' "$log" \
               | head -1)
  echo "       $offender" >&2
else
  echo "       (could not identify offending fixture; full log:)" >&2
  tail -40 "$log" >&2
fi
exit 1