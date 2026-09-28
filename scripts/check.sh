#!/usr/bin/env bash
# math-coding 3.0-alpha: run all repo-state shell fixtures and report
# per-fixture status, then run the dune cram CLI tests.
#
# Usage:
#   scripts/check.sh            — run all fixtures, exit 0 only if all pass
#   scripts/check.sh <name>     — run a single fixture by basename
#
# Each fixture in tests/fixtures/*.sh is a self-contained executable
# that asserts one obligation. The CLI integration tests live in
# tests/cli/*.t as dune cram tests; they are exercised via
# `dune runtest` at the end of the aggregator so a single invocation
# of scripts/check.sh covers both shells and cram.
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

# CLI cram integration tests (tests/cli/*.t). These run via dune
# test. We force dune to rebuild so the bwrap sandbox is rebuilt
# fresh; on a clean run this is fast (incremental cache).
cleanup_dune
cram_log=$(mktemp)
trap 'rm -f "$cram_log"' EXIT
if ! nix develop .#test --command bash -c '
    dune build --root . @install >/dev/null 2>&1 &&
    dune runtest --root . tests/cli
' >"$cram_log" 2>&1; then
  printf "  FAIL cli-cram\n"
  tail -20 "$cram_log" >&2 || true
  fail=$((fail + 1))
  failed_names+=("cli-cram")
else
  printf "  ok   cli-cram\n"
  pass=$((pass + 1))
fi

cleanup_dune

echo
echo "summary: $pass passed, $fail failed"

if [ "$fail" -gt 0 ]; then
  echo "failed: ${failed_names[*]}"
  exit 1
fi
exit 0
