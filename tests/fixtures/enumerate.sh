#!/usr/bin/env bash
# kernel-conformance-runner: enumerate-and-classify-fixtures fixture
#
# Asserts that:
#   - tests/conformance.ml exists
#   - tests/dune declares (test (name conformance))
#   - nix develop .#test can compile and run dune test
#   - dune test produces Alcotest output mentioning the conformance suite
#
# This fixture is intentionally a thin wrapper: the per-fixture
# classification logic lives in tests/conformance.ml (OCaml), not in
# shell. The shell fixture verifies the environment and the runner
# skeleton; per-fixture pass/fail verification is OCaml's job.
#
# Positive fixture for obligation enumerate-and-classify-fixtures
# in bootstrap/kernel-conformance-runner.yaml.

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "enumerate-and-classify-fixtures:"

# Source-level check: tests/conformance.ml must exist.
if [ ! -f tests/conformance.ml ]; then
  echo "  FAIL tests/conformance.ml does not exist" >&2
  exit 1
fi

# Source-level check: tests/dune must declare the conformance test.
# The stanza spans two lines, so we check the two-line pattern.
if ! awk '
  /^\(test$/ { saw_test = 1; next }
  saw_test && /^\s*\(name conformance\)$/ { found = 1; exit 0 }
  { saw_test = 0 }
  END { exit found ? 0 : 1 }
' tests/dune; then
  echo "  FAIL tests/dune does not declare (test (name conformance))" >&2
  exit 1
fi

# Behaviour-level check: dune test runs the conformance suite.
# We do NOT count cases (that's OCaml's job). We only verify that
# dune test runs at all AND emits Alcotest output naming the suite.
# --force forces dune to re-execute tests even when the build is
# cached, so the fixture's grep sees real output regardless of
# whether the per-fixture verdicts pass or fail.
log=$(mktemp)
trap 'rm -f "$log"' EXIT
nix develop .#test --command bash -c 'dune test --root . --force' >"$log" 2>&1 || true
# Note: || true because parser regressions are recorded by separate
# fixtures; this one verifies the runner is wired, not parser quality.

if ! grep -qE 'kernel conformance' "$log"; then
  echo "  FAIL dune test output does not mention kernel conformance" >&2
  tail -20 "$log" >&2
  exit 1
fi

echo "  ok   tests/conformance.ml exists"
echo "  ok   tests/dune declares (test (name conformance))"
echo "  ok   dune test runs and emits kernel conformance suite"
exit 0
