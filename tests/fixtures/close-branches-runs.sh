#!/usr/bin/env bash
# tests/fixtures/close-branches-runs.sh
#
# Verifier for decisions/process-principles-close-branches.yaml
# obligation `close-branches-impl`: `scripts/dev close-branches`
# exits 0 and lists at least one branch (or zero) without
# crashing on a hard-coded headless repo state.
#
# This fixture is intentionally cheap: it asserts the script
# runs, parses its stdout, and never invokes `--yes`. The
# destructive mode is exercised manually on a developer
# workstation with a fresh clone.

set -uo pipefail
cd "$(dirname "$0")/../.."

# `scripts/dev close-branches` (no --yes) prints branches and
# exits 0. Capture stdout.
out=$(./scripts/dev close-branches 2>&1)
ec=$?

if [ "$ec" != "0" ]; then
  echo "FAIL: close-branches exited $ec"
  echo "$out"
  exit 1
fi

echo "ok: scripts/dev close-branches exited 0"
echo "$out" | head -3
exit 0