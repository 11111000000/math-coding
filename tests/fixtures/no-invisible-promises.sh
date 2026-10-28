#!/usr/bin/env bash
# tests/fixtures/no-invisible-promises.sh
#
# Verifier for decisions/verifier-strings-the-kernel-can-read-2026-10.yaml
# (`the-corpus-is-clean`).
#
# THE CLAIM. No promise in the corpus is invisible to the kernel.
# Two classes of promise break that, and both are spellings, not
# intentions:
#
#   cannot-be-set-up   the verifier names a scheme the kernel KNOWS
#                      and a string it cannot run (a path verifier
#                      with a trailing case label, a test selector
#                      with a trailing description). The promise is
#                      real and the check could not be set up.
#   unidentified       the obligation names no verifier the loader
#                      can read (the acceptance map form, or no
#                      acceptance at all).
#
# A promise the kernel cannot see is a promise no gate can hold, and
# it hides the promises the gate WOULD have held. So this fixture
# asks the kernel itself, through the same command a reader would
# use, and fails if either class is non-empty.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

bin=""
for c in _build/default/bin/mathc.exe _build/install/default/bin/mathc; do
  if [ -x "$c" ]; then bin="$PWD/$c"; break; fi
done
if [ -z "$bin" ]; then
  for c in mathc mathc.exe; do
    if command -v "$c" >/dev/null 2>&1; then bin="$(command -v "$c")"; break; fi
  done
fi
if [ -z "$bin" ]; then
  bad "no mathc binary found (looked in _build/default/bin/, _build/install/default/bin/ and on PATH)"
  echo
  echo "no-invisible-promises: FAIL"
  exit 1
fi

# The report goes through a FILE, not through a shell variable: the
# worklist of a real corpus is a few hundred kilobytes, and a shell
# variable that size is an argument list the kernel cannot exec.
out="$(mktemp)"
trap 'rm -f "$out"' EXIT
"$bin" gaps >"$out" 2>/dev/null
if [ ! -s "$out" ]; then
  bad "mathc gaps produced no output"
  echo
  echo "no-invisible-promises: FAIL"
  exit 1
fi

for cls in cannot-be-set-up unidentified; do
  n="$(jq -r --arg c "$cls" '[.open[] | select(.class == $c)] | length' "$out")"
  if [ "$n" = "0" ]; then
    ok "no promise is $cls"
  else
    bad "$n promise(s) are $cls:"
    jq -r --arg c "$cls" '.open[] | select(.class == $c) | "      \(.decision)/\(.obligation): \(.verifiers | join("; "))"' "$out"
  fi
done

echo
if [ "$fail" -eq 0 ]; then
  echo "no-invisible-promises: PASS"
  exit 0
fi
echo "no-invisible-promises: FAIL"
exit 1
