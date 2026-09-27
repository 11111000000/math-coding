#!/usr/bin/env bash
# math-coding 3.0-alpha: run all infrastructure-honesty and
# kernel-conformance-runner fixtures and report per-fixture status.
#
# Usage:
#   scripts/check.sh            — run all fixtures, exit 0 only if all pass
#   scripts/check.sh <name>     — run a single fixture by basename
#
# Each fixture in tests/fixtures/*.sh is a self-contained executable
# that asserts one obligation. This script is just the aggregator.
#
# Dune-lock handling: each fixture spawns `nix develop .#test`
# which runs dune. When a previous invocation is interrupted
# (timeout, harness kill, etc.) the inner dune process may
# outlive its parent and hold `_build/.lock`, causing the next
# fixture to fail with "Another Dune instance is currently
# running".
#
# Strategy: detect stale lock files BEFORE invoking the fixture,
# but do NOT pkill dune (race-killing the fixture's own dune).
# Only remove the lock file if no dune process is alive.

set -uo pipefail
cd "$(dirname "$0")/.."

fixture_dir="tests/fixtures"
fixtures=("$fixture_dir"/*.sh)

if [ "${1:-}" != "" ]; then
  fixtures=("$fixture_dir/$1.sh")
fi

pass=0
fail=0
failed_names=()

cleanup_dune() {
  # Surface a stale _build/.lock left by an interrupted previous
  # build. We DO NOT pkill dune processes here because the fixture
  # itself spawns its own dune, and pkill from inside the
  # aggregator would race-kill it. (Bug discovered 2026-09-27 when
  # `scripts/dev verify` flake-killed dune via pkill race; the
  # fix is to do only the lock-file cleanup here.)
  if [ -f _build/.lock ]; then
    if ! pgrep -f 'dune' >/dev/null 2>&1; then
      rm -f _build/.lock
    fi
  fi
}

for f in "${fixtures[@]}"; do
  cleanup_dune
  name=$(basename "$f" .sh)
  if "$f" >/dev/null 2>&1; then
    printf "  ok   %s\n" "$name"
    pass=$((pass + 1))
  else
    printf "  FAIL %s\n" "$name"
    fail=$((fail + 1))
    failed_names+=("$name")
  fi
done

cleanup_dune

echo
echo "summary: $pass passed, $fail failed"

if [ "$fail" -gt 0 ]; then
  echo "failed: ${failed_names[*]}"
  exit 1
fi
exit 0
