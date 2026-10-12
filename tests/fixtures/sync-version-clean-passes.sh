#!/usr/bin/env bash
# tests/fixtures/sync-version-clean-passes.sh
#
# Verifier for decisions/version-sync-2026-10.yaml obligation
# `version-single-source-of-truth`. The fixture asserts that a
# tree whose `adoption/SKILL.md` is in sync with `VERSION`
# passes `scripts/sync-version.sh --check` with exit 0.
#
# Run from repo root after `scripts/sync-version.sh --write`
# has been applied. Authoritative attestation is the harness's
# observation that the script exits 0 on a clean tree; this
# fixture codifies the contract.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0

# Sync script exists and is executable.
if [ ! -x scripts/sync-version.sh ]; then
  echo "FAIL: scripts/sync-version.sh missing or not executable"
  exit 1
fi
echo "ok: scripts/sync-version.sh present and executable"

# VERSION file exists and is non-empty.
if [ ! -s VERSION ]; then
  echo "FAIL: VERSION missing or empty"
  exit 1
fi
echo "ok: VERSION file present and non-empty"

# Run --check. The script's exit code IS the verifier for the
# `version-single-source-of-truth` obligation; the fixture
# asserts the script's exit code.
if scripts/sync-version.sh --check >/dev/null 2>&1; then
  echo "ok: sync-version --check exited 0 on a clean tree"
else
  echo "FAIL: sync-version --check exited non-zero on a clean tree"
  echo "  (this means VERSION drifts from adoption/SKILL.md;"
  echo "   run scripts/sync-version.sh --write to repair)"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "ok: version-sync-clean-passes (all checks green)"
exit 0