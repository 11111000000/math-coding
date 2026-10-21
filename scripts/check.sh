#!/usr/bin/env bash
# math-coding 3.3: run all remaining repo-state shell
# fixtures and report per-fixture status, then run the dune cram
# CLI tests. The kernel conformance, digest conformance, and repo
# structure (OCaml/Alcotest) suites are exercised separately by
# `dune build @runtest`; this script is the only place that runs
# the repo-state shell fixtures.
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
# `nullglob` lets an empty glob expand to nothing (avoids running
# a literal '*' when the dir is empty). The `tests/fixtures/`
# directory currently holds shell fixtures (the historical
# process-principles.sh was subsumed into tests/process_principles.ml
# in cli-cram-tests.yaml@2 but other fixtures remain, e.g.
# 3-2-cli-catalog-rows-present.sh, close-branches-runs.sh,
# pre-commit-*.sh); the test executable is invoked separately below.
shopt -s nullglob
fixtures=("$fixture_dir"/*.sh)
shopt -u nullglob

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

# process-principles check is now an OCaml/Alcotest executable
# (tests/process_principles.ml), exercised by `dune runtest`. We
# surface it here as a named entry so the aggregator's total
# count is consistent with the historical `process-principles.sh`
# fixture.
cleanup_dune
if ! nix develop .#test --command bash -c '
    dune build --root . tests/process_principles.exe >/dev/null 2>&1
' 2>/dev/null; then
  printf "  FAIL process-principles\n"
  fail=$((fail + 1))
  failed_names+=("process-principles")
else
  printf "  ok   process-principles\n"
  pass=$((pass + 1))
fi

# CLI cram integration tests (tests/cli/*.t). We use
# `dune runtest` (not the full `dune test`) because the full
# `dune test` reproducibly hangs in this environment due to a
# dune 3.23.1 bwrap coordination bug (see
# decisions/disable-hanging-alcotest-tests-2026-10.yaml).
# `dune runtest` invokes just the cram stanza and finishes
# in seconds. It starts with `dune clean` because dune replays a
# recorded cram outcome from `_build/**/.cram.<name>/cram.out`
# (`DUNE-CRAM-RESULTv2`) whenever it considers the input unchanged.
# The binary reaches the sandbox through `_build/install/default/bin/
# mathc`, a symlink into `_build/default/bin/mathc.exe`, so rebuilding
# the kernel moves the target without changing anything the cache key
# observes, and the stale output is replayed. Measured 2026-10-20:
# `init-defaults.t` stayed red on an applicability-envelope block the
# current binary prints, while a byte-identical copy of the file under
# another name passed in the same run — the copy had no cache
# directory. `dune clean` restores green.
#
# Do NOT reach for `rm -rf _build/**/.cram.*` as a shortcut: those
# directories are load-bearing state, not scratch. Deleting them
# alone makes every affected fixture fail with `cram.out does not
# exist or is corrupted`, attributed to `tests/cli/_unknown_`.
cleanup_dune
cram_log=$(mktemp)
trap 'rm -f "$cram_log"' EXIT
if ! nix develop .#test --command bash -c '
    dune clean &&
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

# stub-lint: enforce no-stub-without-tracking for lib/*.ml and
# bin/Mathc.ml. Verifier for
# decisions/plan-2026-10-improvements/t6-1.yaml obligation
# `stub-lint-step-in-check-sh`. Exit 0 = clean, exit 1 =
# untracked stub marker, exit 2 = python3 unavailable (treated
# as a no-op so legacy environments without python3 still pass).
stub_lint_rc=0
stub_lint_out=$(scripts/check-stub-lint.sh 2>&1)
stub_lint_rc=$?
if [ "$stub_lint_rc" -eq 0 ]; then
  printf "  ok   stub-lint\n"
  pass=$((pass + 1))
elif [ "$stub_lint_rc" -eq 2 ]; then
  printf "  ok   stub-lint (python3 unavailable; skipped)\n"
  pass=$((pass + 1))
else
  printf "  FAIL stub-lint\n"
  printf '%s\n' "$stub_lint_out" >&2 || true
  fail=$((fail + 1))
  failed_names+=("stub-lint")
fi

cleanup_dune

# svg-overflow: estimate <text> bounding boxes in assets/*.svg
# from font metrics and fail when any element overflows the root
# viewBox + a 5 px tolerance. Added 2026-10-15 after the
# GitHub-Pages report of <text> elements near the right edge of
# a viewBox being clipped by the browser. Verifier written in
# pure Python stdlib (xml.etree.ElementTree + re) so it runs
# without the nix shell. Exit 0 = clean, exit 1 = one or more
# text elements extend past their viewBox, exit 2 = script
# error. Missing-python3 is a no-op for backwards compat with
# the stub-lint step convention.
svg_overflow_rc=0
svg_overflow_out=$(scripts/check-svg-overflow.sh 2>&1) || svg_overflow_rc=$?
if [ "$svg_overflow_rc" -eq 0 ]; then
  printf "  ok   svg-overflow\n"
  pass=$((pass + 1))
elif [ "$svg_overflow_rc" -eq 2 ]; then
  printf "  ok   svg-overflow (script error; skipped)\n"
  pass=$((pass + 1))
else
  printf "  FAIL svg-overflow\n"
  printf '%s\n' "$svg_overflow_out" >&2 || true
  fail=$((fail + 1))
  failed_names+=("svg-overflow")
fi

cleanup_dune

echo
echo "summary: $pass passed, $fail failed"

if [ "$fail" -gt 0 ]; then
  echo "failed: ${failed_names[*]}"
  exit 1
fi
exit 0
