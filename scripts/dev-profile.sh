#!/usr/bin/env bash
# scripts/dev-profile.sh — where the verification cycle actually spends
# its time.
#
# WHY THIS EXISTS. Every claim about the cycle being slow has been an
# opinion until now: "the tests are slow", "dune hangs", "the nix
# shell is expensive". The cycle is a CHAIN - build, then the OCaml
# suites, then 128 cram transcripts, then the shell fixtures, then
# the pre-commit gate - and a chain is only as fast as its slowest
# link, which is not the one anybody guesses.
#
# This script times each link separately and prints the shares. It is
# the measurement that decides what to optimise; without it, the
# optimisation is a guess, and a guess costs a day.
#
# Usage: scripts/dev-profile.sh [--quick]
#   --quick  skip the cram phase (the long one) and report the rest

set -uo pipefail
cd "$(dirname "$0")/.."

QUICK=0
[ "${1:-}" = "--quick" ] && QUICK=1

BIN="${MATHC_BIN:-}"
if [ -z "$BIN" ]; then
  for c in _build/default/bin/mathc.exe _build/install/default/bin/mathc; do
    [ -x "$c" ] && BIN="$PWD/$c" && break
  done
  command -v mathc >/dev/null 2>&1 && [ -z "$BIN" ] && BIN="$(command -v mathc)"
fi

phase() {
  # phase <name> <command...>
  local name="$1"; shift
  local s e
  s=$(date +%s%N)
  "$@" >/tmp/dev-profile.$$ 2>&1
  local rc=$?
  e=$(date +%s%N)
  local ms=$(( (e - s) / 1000000 ))
  printf '  %-34s %7d ms   rc=%s\n' "$name" "$ms" "$rc"
}

echo "math-coding cycle profile — $(date -Iseconds)"
echo

# Phase 0: the dev shell itself. `nix develop` re-entered N times is
# the cost this measures.
phase "nix develop (one entry)" nix develop .#test --command true

# Phase 1: the build.
phase "dune build" nix develop .#test --command dune build --root .

# Phase 2: the OCaml suites (alcotest binaries).
phase "dune runtest (alcotest)" nix develop .#test --command dune build @runtest --root .

# Phase 3: the shell fixtures.
phase "scripts/check.sh (shell fixtures)" bash scripts/check.sh

# Phase 4: the pre-commit gate over the corpus.
phase "mathc precommit (corpus)" nix develop .#test --command bash -c \
  "'$BIN' precommit"

# Phase 5: the cram transcripts. This is the long one.
if [ "$QUICK" = "0" ]; then
  phase "dune runtest tests/cli (cram)" nix develop .#test --command \
    dune runtest --root . tests/cli
else
  printf '  %-34s %7s   (skipped: --quick)\n' "dune runtest tests/cli (cram)" "-"
fi

rm -f /tmp/dev-profile.$$
echo
echo "Read the shares, not the totals: the link that dominates is the one"
echo "worth fixing, and the others are not worth touching."
