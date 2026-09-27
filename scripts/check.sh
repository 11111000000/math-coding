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
# Dune-lock cleanup: each fixture spawns `nix develop .#test` which
# runs dune. When a previous nix develop invocation is interrupted
# (timeout, ctrl-c, harness kill), the inner dune process can
# outlive its parent and hold `_build/.lock`. The next fixture
# then fails with "Another Dune instance is currently running".
# To break the deadlock we `pkill -f dune` between fixtures — fast,
# targeted, only kills processes matching "dune" not the aggregator
# itself.

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
  # Kill any leftover dune / nix-develop processes from the previous
  # fixture so the next fixture can acquire _build/.lock without
  # waiting for a parent shell that has already exited.
  pkill -9 -f 'dune build'  2>/dev/null || true
  pkill -9 -f 'dune test'   2>/dev/null || true
  pkill -9 -f 'nix develop .#test' 2>/dev/null || true
  # Best-effort: drop a stale _build/.lock if no dune is around.
  if [ -f _build/.lock ] && ! pgrep -f 'dune' >/dev/null 2>&1; then
    rm -f _build/.lock
  fi
  # Brief settle so dune's flock state clears before the next run.
  sleep 1
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
