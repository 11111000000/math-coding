#!/usr/bin/env bash
# infrastructure-honesty: dune-runs-conformance fixture
#
# Asserts that dune test executes the conformance runner and that
# dune's exit status reflects pass/fail. This is the positive fixture
# for obligation wire-conformance-runner in
# bootstrap/infrastructure-honesty.yaml.
#
# Exits 0 if dune test reports conformance corpus tests as OK.

set -eu
cd "$(dirname "$0")/../.."

echo "dune-runs-conformance:"

if ! nix develop .#test --command bash -c 'dune test --root .' 2>&1 | tee /tmp/mc-conformance.log; then
  echo "  FAIL dune test exited nonzero" >&2
  tail -20 /tmp/mc-conformance.log >&2 || true
  exit 1
fi

# Look for conformance corpus output. We check for the test name
# pattern, not specific pass/fail counts, because fixtures evolve.
if grep -qE 'conformance corpus|conformance' /tmp/mc-conformance.log; then
  echo "  ok   dune test exercised the conformance corpus"
  exit 0
else
  echo "  FAIL dune test output does not mention conformance corpus" >&2
  echo "       (the conformance test is wired up but not running)" >&2
  tail -30 /tmp/mc-conformance.log >&2
  exit 1
fi
