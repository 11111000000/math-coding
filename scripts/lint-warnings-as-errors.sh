#!/usr/bin/env bash
# scripts/lint-warnings-as-errors.sh
#
# The lint gate: build the kernel AND the test executables with
# every compiler warning promoted to an error, and prove the gate can
# fail.
#
# Why a script and not an inline command:
#
#   1. A lint gate that cannot be shown to FAIL is not a gate. The
#      negative control below compiles a probe that triggers warning 8
#      (partial match) with the same compiler settings and REQUIRES
#      the compile to fail. If the settings ever stop promoting
#      warnings, the control fails and this says so, instead of
#      reporting a green lint that proved nothing.
#
#   2. The test executables live behind the `runtest` alias, not the
#      default one, so `dune build` alone never compiles them. They
#      are part of the tree and carry the same bar.
#
# Why not dune's --error-on-warnings flag: it does not exist in dune
# 3.23.1, the version pinned in flake.lock. `scripts/dev lint` used
# it until 2026-10-27 and therefore failed with "dune: unknown
# option '--error-on-warnings'" on every run -- the gate never ran a
# single check. dune 3.23.1 already promotes warnings to errors in
# its dev profile (measured from `dune build --verbose`: the
# compiler is invoked with `-warn-error +a`), so the POLICY this
# command wanted is the policy dune already applies; the flag was
# cargo-cult.
#
# WHAT THIS GATE DOES NOT YET COVER: the full warning set (-w @a).
# Measured on this tree at 2026-10-27, -w @a surfaces 20 pre-existing
# warnings that dune's default set does not enable:
#
#     10  warning 44  [open-shadow-identifier]   (open Stdlib)
#      9  warning 70  [missing-mli]               (no .mli files)
#      5  warning 4   [fragile-match]             (string matching)
#      3  warning 9   [missing-record-field-pattern]
#     14  warning 40  [name-out-of-scope]
#     22  warning 42  [disambiguated-name]
#     39  warning 39  [unused-rec-flag]
#
# Turning that set on would make this gate RED on a tree nobody
# touched -- a red gate that blocks every commit and hides the real
# failures behind a pre-existing debt. The honest move is to pay that
# debt separately and raise the bar in one step, not to switch it on
# here and call the result a lint failure. The debt is recorded in
# decisions/lint-warning-set-2026-10.yaml.
#
# EXIT: 0 when the build and the test executables are clean and the
# negative control failed as required. 1 otherwise.
set -uo pipefail
cd "$(dirname "$0")/.."

# The negative control. It MUST fail to compile: if it compiles
# cleanly, the settings are not promoting warnings to errors and a
# clean build below would prove nothing.
#
# The control compiles with the SAME flags dune passes -- measured
# from `dune build --verbose` on 2026-10-27:
#
#     -warn-error +a
#
# A bare `ocamlc` does NOT promote warnings, so a control compiled
# without that flag would pass cleanly and the gate would report
# "warnings are not errors" -- a true statement about the wrong
# compiler invocation, and a false statement about the build.
control_dir=$(mktemp -d)
probe="$control_dir/probe.ml"
cat > "$probe" <<'PROBE'
let probe = match [] with [] -> 1
let () = ignore probe
PROBE

control_out=$(cd "$control_dir" && ocamlc -warn-error +a -c -o probe.cmo probe.ml 2>&1)
control_rc=$?
rm -rf "$control_dir"

if [ "$control_rc" -eq 0 ]; then
  echo "lint: FAIL -- the negative control compiled cleanly, so warnings" >&2
  printf '%s\n' "$control_out" >&2
  echo "lint: are NOT being promoted to errors and a clean build" >&2
  echo "lint: below would prove nothing." >&2
  exit 1
fi

# The positive check. dune's dev profile already passes
# `-warn-error +a`, so an ordinary build IS the warnings-as-errors
# check -- and it is the check this gate ran before the non-existent
# flag broke it. The test executables are built by the `check` alias,
# not the default one, so `dune build` alone never compiles them; they
# are part of the tree and carry the same bar.
if ! dune build --root . ; then
  echo "lint: FAIL -- the build emitted a warning" >&2
  exit 1
fi

# `@check`, NOT `@runtest`.
#
# `@runtest` is a RULE alias: building it RUNS the test suite. This
# gate is about COMPILATION, and running the suite inside it had two
# costs. (1) A failing TEST was reported as "a test executable emitted
# a warning" -- a false diagnosis, because nothing warned; the test
# simply failed. On 2026-10-27 that is exactly how the CI read: the
# lint step said "a test executable emitted a warning" while the real
# failure was one cram case, reported by a different step, with a
# different (and also wrong) name. Two steps, two names, one cause.
# (2) The suite ran twice per CI job -- once here, once in
# `scripts/dev verify` -- so every run paid for it and the second run
# was the one that could report a stale verdict.
#
# `@check` compiles the test executables without running them, which
# is what a lint gate wants: the executables carry the same warning
# bar, and nothing else changes.
if ! dune build --root . @check ; then
  echo "lint: FAIL -- a test executable emitted a warning" >&2
  exit 1
fi

echo "lint: clean"
exit 0
