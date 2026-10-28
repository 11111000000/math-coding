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

cleanup_dune() {
  # Surface a stale _build/.lock left by an interrupted previous
  # build. We DO NOT pkill dune processes here because the fixture
  # itself spawns its own dune, and pkill from inside the
  # aggregator would race-kill it. (Bug discovered 2026-09-27 when
  # `scripts/dev verify` flake-killed dune via pkill race; the
  # fix is to do only the lock-file cleanup here.)
  #
  # "Is a dune running?" is asked by the EXECUTABLE'S NAME, not by
  # the command line. `pgrep -f dune` answered the wrong question:
  # it matches every process whose command line CONTAINS the string
  # "dune" -- including the shell that is running this aggregator,
  # and including the `nix develop .#test --command bash -c 'dune
  # build ...'` wrapper of a fixture. Measured on 2026-10-27: a
  # dune left behind by an interrupted command kept the lock, and
  # the check that was supposed to remove it could never fire,
  # because the aggregator's own command line mentioned dune. The
  # suite then failed with "Another Dune instance is currently
  # running" -- a lock that was nobody's.
  #
  # The name is exact: the process's executable, not its arguments.
  local pid exe
  for pid in $(pgrep -x dune 2>/dev/null || true); do
    exe=$(readlink "/proc/$pid/exe" 2>/dev/null || true)
    case "$exe" in
      */dune) return 0 ;;
    esac
  done
  [ ! -f _build/.lock ] || rm -f _build/.lock || true
}

if [ "${1:-}" != "" ]; then
  fixtures=("$fixture_dir/$1.sh")
  # The documented contract of the single-fixture form is "run a
  # single fixture by basename". The other steps used to run anyway,
  # and the alcotest step -- which needs the test binaries BUILT --
  # reported 34 spurious "FAIL <binary> (no build target)" lines on
  # a tree where nothing had been built. Thirty-four failures that
  # say nothing about the fixture the caller asked about is a report
  # that lies, and it buries the one line that matters.
  #
  # So the single-fixture form runs that fixture, prints its reason
  # on failure, and exits with its status. Nothing else.
  if [ ! -f "${fixtures[0]}" ]; then
    printf "check.sh: no such fixture: %s\n" "$fixture_dir/$1.sh" >&2
    exit 2
  fi
  cleanup_dune
  name=$(basename "${fixtures[0]}" .sh)
  log=$(mktemp)
  trap 'rm -f "$log"' EXIT
  if "${fixtures[0]}" >"$log" 2>&1; then
    printf "  ok   %s\n" "$name"
    exit 0
  else
    printf "  FAIL %s\n" "$name"
    tail -20 "$log" >&2 || true
    exit 1
  fi
fi

# `skip` is tracked apart from `pass` on purpose. The stub-lint and
# svg-overflow verifiers exit 2 when python3 is missing or the script
# itself errors; that used to print `ok ... skipped` AND increment the
# pass counter, so a check that never executed was reported as a check
# that passed. Environments without python3 still exit 0 overall, so
# nothing is newly broken there - the summary just stops claiming a
# check ran.
pass=0
fail=0
skip=0
failed_names=()
# The per-fixture log. A fixture that fails must be able to say WHY,
# and the log is what carries that reason to the aggregator's output.
fixture_log=$(mktemp)


for f in "${fixtures[@]}"; do
  cleanup_dune
  name=$(basename "$f" .sh)
  if "$f" >"$fixture_log" 2>&1; then
    printf "  ok   %s\n" "$name"
    pass=$((pass + 1))
  else
    printf "  FAIL %s\n" "$name"
    # The reason, not just the name. A fixture whose output is
    # discarded cannot say why it failed, and a red CI that cannot
    # name its cause is a red CI nobody can fix: on 2026-10-27 that is
    # how the project spent a month with a red main and no diagnosis.
    tail -20 "$fixture_log" >&2 || true
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
#
# SCOPE: every Alcotest executable in tests/, not just this one.
#
# The previous shape of this step ran `dune build` and nothing else,
# which proves the module COMPILES and nothing about whether a single
# assertion holds — it reported `ok` for a suite that could be failing
# wholesale. Fixing that for one binary left the hole one layer down:
# the `(tests ...)` stanza names 26 executables and `tests/gate/`
# names 2 more, and this step ran exactly one of the 28. That is how
# `counters_reference` was red on main for a full review cycle with
# the aggregator reporting green — the same fail-silently shape as the
# cram gap above, and the fix is the same: run what you claim to check.
#
# The list is derived from `tests/dune` and `tests/gate/dune` rather
# than hardcoded, so a binary added to either stanza is covered the
# next time this runs without editing this script. If a stanza lists a
# binary that has no build output, the step FAILS — a coverage guard
# that can itself silently shrink is worse than none.
cleanup_dune
alco_log=$(mktemp)
if ! nix develop .#test --command bash -c '
    set -u
    names=$(sed -n "/^(tests/,/^ (libraries/p" tests/dune \
              | grep -oE "^  [a-z][a-z0-9_]*" | tr -d " ")
    for d in tests/gate; do
        [ -f "$d/dune" ] || continue
        names="$names $(sed -n "/^(test/,/^$/p" "$d/dune" \
                  | grep -oE "\(name [a-z_]+\)" | tr -d "()" | awk "{print \$2}")"
    done
    built=""
    rc=0
    # ONE dune invocation for every test binary.
    #
    # The previous shape called `dune build` once per binary, and
    # each call re-evaluated the whole build context and took the
    # dune lock again. Measured on 2026-10-23: 28 binaries cost
    # 84.7 s, of which the repeated context evaluation was the
    # largest single term. One invocation builds them all, in
    # parallel, under one lock.
    targets=""
    for t in $names; do
        targets="$targets tests/$t.exe tests/gate/$t.exe"
    done
    # shellcheck disable=SC2086
    dune build --root . $targets >/dev/null 2>&1 || true
    for t in $names; do
        exe="./_build/default/tests/$t.exe"
        [ -x "$exe" ] || exe="./_build/default/tests/gate/$t.exe"
        if [ -x "$exe" ]; then
            built="$built $t"
            if ! timeout 120 "$exe" >/dev/null 2>&1; then
                printf "FAIL %s\n" "$t"
                rc=1
            fi
        else
            printf "FAIL %s (no build target)\n" "$t"
            rc=1
        fi
    done
    printf "ran %d of %d\n" "$(echo $built | wc -w)" "$(echo $names | wc -w)"
    exit $rc
' >"$alco_log" 2>&1; then
  printf "  FAIL alcotest\n"
  tail -30 "$alco_log" >&2 || true
  fail=$((fail + 1))
  failed_names+=("alcotest")
else
  ran=$(sed -n 's/^ran \([0-9]*\) of \([0-9]*\)$/\1 of \2/p' "$alco_log" | tail -1)
  printf "  ok   alcotest (%s)\n" "${ran:-?}"
  pass=$((pass + 1))
fi
rm -f "$alco_log"

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
#
# BARE `mathc` WAS THE BUG (2026-10-23). This block used to run
# `nix develop .#test --command bash -c 'mathc precommit'`, assuming
# `mathc` is on PATH inside the test shell. It is not: `mathc` exists
# only as `packages.default` (flake.nix:131), and `mkShell` does not
# put a package derivation on PATH — the devShell's `packages` list is
# `ocamlDeps ++ dune ++ buildTools`, none of which is the binary. On a
# developer machine the step passed only because a machine-local
# `~/.local/bin/mathc` existed, provisioned by nothing in the flake and
# nothing in CI. On a GitHub runner that artifact is absent, so the
# shell printed `mathc: command not found`, exited 127, and this step
# reported `FAIL decisions-precommit` for a corpus that is provably
# clean — 218/218 accepted. A check whose exit code proves "the binary
# is absent" while its label claims "the corpus is dirty" is worse than
# no check: it trains the reader to ignore the label.
#
# The fix follows the convention the rest of the repo already uses
# (`.github/workflows/ci.yml:125`, `scripts/ci-step-exit-sim.sh:226`):
# invoke the build-tree binary by its build path, `_build/install/
# default/bin/mathc`. That path is a symlink into
# `_build/default/bin/mathc.exe`, and `lib/check/check.ml::mathc_resolve`
# finds that same path from `Sys.executable_name` — so the per-file
# `mathc validate` subprocesses re-exec THIS binary, with no PATH
# lookup anywhere in the chain.
#
# The build is explicit and deliberate. `dune build --root .` (no
# target) is exactly what `scripts/dev verify` stage 1 runs before
# `check.sh`, and it is what creates `_build/install/...`; a bare
# `dune build @install` would also drag the cram stanza in, so this
# step would inherit every unrelated cram failure and re-introduce the
# same mislabelled-FAIL class under a new name. `cleanup_dune` above
# only removes a stale `_build/.lock`; it never wipes `_build`, so on a
# warm tree the build here is a no-op.
#
# The diagnostic re-run used to be a SECOND bare-`mathc` invocation
# (`mathc precommit 2>&1 | grep ...`), so on the failure path it
# printed `bash: line 1: mathc: command not found` — the same useless
# second command-not-found, hiding the real cause behind the first.
# Both stdout and stderr of the single gated invocation now go to one
# log, and the diagnostic is a `grep` over THAT log. There is exactly
# one binary invocation, so the reason printed is by construction the
# reason the step failed: a kernel diagnostic, or a dune build error.
cleanup_dune
precommit_log=$(mktemp)
if ! nix develop .#test --command bash -c '
    set -uo pipefail
    dune build --root . || exit 3
    _build/install/default/bin/mathc precommit
  ' >"$precommit_log" 2>&1; then
  printf "  FAIL decisions-precommit\n"
  grep -vE ': (accept|parse-ok)$' "$precommit_log" \
    | grep -v '^mathc precommit:' | head -10 >&2 || true
  fail=$((fail + 1))
  failed_names+=("decisions-precommit")
else
  printf "  ok   decisions-precommit\n"
  pass=$((pass + 1))
fi
rm -f "$precommit_log"

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
# `dune clean` is load-bearing for the cram phase - see the comment
# above: the cram cache replays a stale transcript when the kernel
# changed without changing anything the cache key observes. But it
# also forces a FULL rebuild of 27k lines of OCaml on every run, and
# measured on 2026-10-23 that rebuild was the single largest term in
# the cycle.
#
# The staleness can only bite when the KERNEL changed. So the clean
# is made CONDITIONAL on the kernel's own content digest having
# moved. A run that touched only decisions, fixtures or docs keeps
# the build cache and skips the rebuild entirely.
#
# The digest is computed by scripts/kernel-stamp.sh, which is the ONE
# definition of "has the code changed?". `scripts/dev verify` asks
# the same question before its first stage, and the two answers
# cannot disagree about what the current digest is.
if [ "$(scripts/kernel-stamp.sh changed 2>/dev/null || echo changed)" = "changed" ]; then
  cram_clean="dune clean &&"
else
  cram_clean=""
fi
scripts/kernel-stamp.sh record >/dev/null 2>&1 || true
cram_dir_list=$(find tests -name '*.t' -exec dirname {} \; | sort -u)
cram_dirs=$(printf '%s\n' "$cram_dir_list" | tr '\n' ' ')
cram_dirs=${cram_dirs% }
cram_log=$(mktemp)
cram_build_log=$(mktemp)
trap 'rm -f "$cram_log" "$cram_build_log" "$fixture_log"' EXIT
# The build's own output goes to its OWN log, not to /dev/null.
#
# The build used to be silenced with `>/dev/null 2>&1`, so when it
# failed the aggregator printed the tail of an EMPTY log and the CI
# log said only "FAIL cram" with no reason -- the failing build said
# nothing at all. A gate that cannot name its cause is not a gate;
# it is a red light. The build log is printed on failure, and the
# test log (which carries the cram diff) is printed too.
if ! printf '%s\n' "$cram_dir_list" | grep -qx 'tests/cli'; then
  printf "  FAIL cram\n"
  printf 'cram discovery did not find tests/cli; found: [%s]\n' \
    "$cram_dirs" >&2
  fail=$((fail + 1))
  failed_names+=("cram")
elif ! nix develop .#test --command bash -c "
    $cram_clean
    dune build --root . @install > '$cram_build_log' 2>&1 &&
    dune runtest --root . $cram_dirs
" >"$cram_log" 2>&1; then
  printf "  FAIL cram  [%s]\n" "$cram_dirs"
  printf '--- the build that preceded the test run ---\n' >&2
  tail -20 "$cram_build_log" >&2 || true
  printf '--- the test run ---\n' >&2
  tail -40 "$cram_log" >&2 || true
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
  printf "  SKIP stub-lint (python3 unavailable; verifier did not run)\n"
  skip=$((skip + 1))
  skipped_names+=("stub-lint")
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
  printf "  SKIP svg-overflow (verifier errored; check did not run)\n"
  skip=$((skip + 1))
  skipped_names+=("svg-overflow")
  pass=$((pass + 1))
else
  printf "  FAIL svg-overflow\n"
  printf '%s\n' "$svg_overflow_out" >&2 || true
  fail=$((fail + 1))
  failed_names+=("svg-overflow")
fi

cleanup_dune

echo
echo "summary: $pass passed, $fail failed, $skip skipped"

if [ "$skip" -gt 0 ]; then
  echo "skipped (NOT verified): ${skipped_names[*]}"
fi

if [ "$fail" -gt 0 ]; then
  echo "failed: ${failed_names[*]}"
  exit 1
fi
exit 0
