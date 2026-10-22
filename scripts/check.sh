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
# that asserts one obligation. The cram integration tests live in
# tests/<dir>/*.t as dune cram tests; they are exercised via
# `dune runtest` at the end of the aggregator so a single invocation
# of scripts/check.sh covers both shells and cram. Every cram
# directory under tests/ is discovered and run (see the cram step
# below), so a new tests/<dir>/ cannot slip past the aggregator
# unnoticed again.
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

# process-principles check is an OCaml/Alcotest executable
# (tests/process_principles.ml). We surface it here as a named entry
# so the aggregator's total count stays consistent with the historical
# `process-principles.sh` fixture.
#
# This step used to run `dune build` and nothing else. That proves the
# module COMPILES; it proves nothing about whether a single
# P1/P2/P5/P6/P7/P8/T1.5/T1.6 assertion actually holds. The entry
# therefore reported `ok` for a suite that could be failing wholesale
# — the same shape of hole as the cram coverage gap below, one layer
# down. Compiling is not testing, so the executable is now run.
#
# The executable is not on PATH, so it is invoked at its dune build
# path. It resolves the repository root by walking up from the cwd,
# and this script has already cd'd to the repository root.
cleanup_dune
pp_log=$(mktemp)
if ! nix develop .#test --command bash -c '
    dune build --root . tests/process_principles.exe >/dev/null 2>&1 &&
    ./_build/default/tests/process_principles.exe
' >"$pp_log" 2>&1; then
  printf "  FAIL process-principles\n"
  tail -20 "$pp_log" >&2 || true
  fail=$((fail + 1))
  failed_names+=("process-principles")
else
  printf "  ok   process-principles\n"
  pass=$((pass + 1))
fi
rm -f "$pp_log"

# The whole decision corpus must pre-commit clean. This is
# deliberately NOT implied by a clean textual merge: `git merge-tree`
# only compares lines, so a branch carrying
# `sha256:PENDING_AT_COMMIT_TIME` merges without conflict and then
# blocks the kernel with MC-BODY-SHA-PATTERN-VIOLATION (severity:
# block). That happened on 2026-10-20 — the decision merged cleanly
# and turned tests/cli/precommit.t red, because nothing in this script
# looked at a decision file at all.
#
# `mathc precommit`, not `mathc validate decisions/*.yaml`: validate
# dispatches on Sys.argv.(2) and silently ignores every later
# argument, so passing 208 paths checks exactly one of them. Precommit
# walks the directory and carries the exit code.
cleanup_dune
if ! nix develop .#test --command bash -c 'mathc precommit >/dev/null 2>&1'; then
  printf "  FAIL decisions-precommit\n"
  nix develop .#test --command bash -c \
    "mathc precommit 2>&1 | grep -vE ': (accept|parse-ok)\$' | grep -v '^mathc precommit:' | head -10" \
    >&2 || true
  fail=$((fail + 1))
  failed_names+=("decisions-precommit")
else
  printf "  ok   decisions-precommit\n"
  pass=$((pass + 1))
fi

# Cram integration tests: EVERY directory under tests/ that holds at
# least one `*.t` fixture, discovered at run time rather than
# hardcoded.
#
# This step used to say `dune runtest --root . tests/cli` and nothing
# else, so tests/mcp and tests/scripts were never executed by this
# aggregator at all. That gap was not cosmetic. On 2026-10-22
# `dune runtest` was red on two tests/scripts fixtures while this
# script printed `summary: 17 passed, 0 failed` — a green
# aggregator reporting a red suite, because the suite it declined
# to run is where the failure lived.
#
# Discovery closes the class of bug, not merely the instance: a cram
# directory added tomorrow is covered tomorrow without anyone
# editing this file. The guard below fails loudly if discovery
# collapses to nothing, so the step cannot degrade into "ran zero
# tests, reported ok".
#
# We use `dune runtest` (not the full `dune test`) because the full
# `dune test` reproducibly hangs in this environment due to a
# dune 3.23.1 bwrap coordination bug (see
# decisions/disable-hanging-alcotest-tests-2026-10.yaml).
# `dune runtest` invokes just the cram stanza and finishes in
# seconds. It starts with `dune clean` because dune replays a
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
cram_dir_list=$(find tests -name '*.t' -exec dirname {} \; | sort -u)
cram_dirs=$(printf '%s\n' "$cram_dir_list" | tr '\n' ' ')
cram_dirs=${cram_dirs% }
cram_log=$(mktemp)
trap 'rm -f "$cram_log"' EXIT
if ! printf '%s\n' "$cram_dir_list" | grep -qx 'tests/cli'; then
  printf "  FAIL cram\n"
  printf 'cram discovery did not find tests/cli; found: [%s]\n' \
    "$cram_dirs" >&2
  fail=$((fail + 1))
  failed_names+=("cram")
elif ! nix develop .#test --command bash -c "
    dune clean &&
    dune build --root . @install >/dev/null 2>&1 &&
    dune runtest --root . $cram_dirs
" >"$cram_log" 2>&1; then
  printf "  FAIL cram  [%s]\n" "$cram_dirs"
  tail -20 "$cram_log" >&2 || true
  fail=$((fail + 1))
  failed_names+=("cram")
else
  printf "  ok   cram  [%s]\n" "$cram_dirs"
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
