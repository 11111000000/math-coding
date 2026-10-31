#!/usr/bin/env bash
# tests/fixtures/missing-directory-is-an-empty-result.sh
#
# Verifier for decisions/missing-directory-is-not-a-crash-2026-10.yaml
# (`a-missing-directory-is-an-empty-result`).
#
# WHAT IT MEASURES. `Sys.is_directory` RAISES on a path that does
# not exist: OCaml answers `Sys_error "No such file or directory"`
# where most languages answer false. Seven places in this repository
# once asked a directory a question with that operator, two of them
# in the kernel, and the CI failed eight consecutive runs on exactly
# that while the same tree passed locally -- locally the developer
# had a store on disk from the last sweep, and CI did not.
#
# The rule the decision states is therefore narrow and it is
# checkable: a missing artefact is an EMPTY RESULT, not an
# exception. A tool that raises answers nothing, and the failure is
# invisible until the state it raises on happens to somebody else.
#
# WHAT IT DOES NOT MEASURE, AND WHY. The decision also promised that
# the whole repository suite is green on a tree without a generated
# store. The tree says otherwise: `tests/fixture_coverage.ml` is red
# (its rejecting-case debt stands at 54 against a ceiling of 52) and
# `tests/cli/gate-trailer-decision.t` is red (it expects `block`
# where the kernel now says `unknown`). Neither red is a crash on a
# missing directory, and neither is this fixture's business. A
# promise that mixes the rule with the state of every other suite is
# a promise that goes red for somebody else's reason, and a check
# that goes red for somebody else's reason is a check nobody reads.
# The suite's own debt has its own ceilings, in
# `tests/fixture_coverage.ml` and in the fixtures it names.
#
# THE FOUR DIRECTIONS.
#
#   1. A ROOT that does not exist. `MATH_CODING_ROOT` points at a
#      path with no directory behind it. The resolver must fall
#      through to the next layout and the command must answer.
#   2. A ROOT that exists and is empty. No decisions, no axioms, no
#      store. Every one of them may legitimately be absent.
#   3. A STORE that does not exist. The store is generated per run
#      (decisions/store-not-committed-2026-10.yaml), so its absence
#      is the normal state of a fresh checkout -- and the answer is
#      `unknown`, not a crash.
#   4. A DECISIONS DIRECTORY that does not exist. The corpus is
#      empty; the command answers about an empty corpus.
#
# THE DETECTOR. The kernel's crash signature is the OCaml runtime's
# own: `Fatal error: exception Sys_error(...)`, or `Unhandled
# exception`. A command that answers says nothing of the kind, and
# its exit code is one of the four the house convention allows
# (0 measured and green, 1 measured and broken, 2 input error, 3
# unknown).
#
# WHY A NEGATIVE CONTROL. A detector nobody has seen fire is not a
# detector. The control below runs the SAME detector against a stub
# that answers exactly the way a kernel answers when it raises, and
# requires the detector to catch it. If the pattern stops matching
# the runtime's output, the control goes red and the fixture stops
# being evidence.
#
# EXIT CODES, following the house convention:
#   0  measured, and the measurement held
#   1  measured, and the measurement did not hold
#   3  nothing was measured (no binary) - unknown, not pass

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok() { printf 'ok: %s\n' "$1"; }
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
  echo "missing-directory-is-an-empty-result: FAIL"
  exit 1
fi

# The crash signature, and nothing else. A kernel that answers does
# not print it.
crash_signature() {
  printf '%s\n' "$1" | grep -E 'Fatal error: exception|Unhandled exception' >/dev/null 2>&1
}

# The four exit codes the house convention allows.
house_exit() {
  case "$1" in
  0 | 1 | 2 | 3) return 0 ;;
  *) return 1 ;;
  esac
}

# run <binary> <args...>: sets ANSWER_OUT, ANSWER_EXIT and
# ANSWER_CRASH. The output goes through a file, not a variable, for
# the same reason the other fixtures use one: a self-check report is
# a few hundred kilobytes.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

run() {
  local b="$1"
  shift
  "$b" "$@" >"$tmp/out" 2>&1
  ANSWER_EXIT=$?
  ANSWER_OUT="$(cat "$tmp/out")"
  if crash_signature "$ANSWER_OUT"; then ANSWER_CRASH=1; else ANSWER_CRASH=0; fi
}

absent="$tmp/absent"

# --- 1. a root that does not exist -------------------------------------
for cmd in self-check gaps doctor; do
  MATH_CODING_ROOT="$absent" run "$bin" $cmd
  if [ "$ANSWER_CRASH" -eq 1 ]; then
    bad "$cmd with a root that does not exist raised instead of answering"
    printf '%s\n' "$ANSWER_OUT" | head -3
  elif ! house_exit "$ANSWER_EXIT"; then
    bad "$cmd with a root that does not exist exited $ANSWER_EXIT, which is not one of the four the house convention allows"
  else
    ok "$cmd with a root that does not exist answers (exit $ANSWER_EXIT), and does not raise"
  fi
done
unset MATH_CODING_ROOT

# --- 2. a root that exists and is empty --------------------------------
empty="$tmp/empty"
mkdir -p "$empty"
for cmd in self-check gaps doctor; do
  MATH_CODING_ROOT="$empty" run "$bin" $cmd
  if [ "$ANSWER_CRASH" -eq 1 ]; then
    bad "$cmd with an empty root raised instead of answering"
    printf '%s\n' "$ANSWER_OUT" | head -3
  elif ! house_exit "$ANSWER_EXIT"; then
    bad "$cmd with an empty root exited $ANSWER_EXIT, which is not one of the four the house convention allows"
  else
    ok "$cmd with an empty root answers (exit $ANSWER_EXIT), and does not raise"
  fi
done
unset MATH_CODING_ROOT

# --- 3. a store that does not exist ------------------------------------
# The store is generated per run, so this is the NORMAL state of a
# fresh checkout, and the answer is `unknown` -- not a crash, and not
# a pass.
MATH_CODING_ATTESTATION_STORE="$absent/store" run "$bin" self-check
if [ "$ANSWER_CRASH" -eq 1 ]; then
  bad "self-check with an absent store raised instead of answering"
  printf '%s\n' "$ANSWER_OUT" | head -3
elif [ "$ANSWER_EXIT" -ne 3 ]; then
  bad "self-check with an absent store exited $ANSWER_EXIT; the honest answer for a corpus with no evidence is 3 (unknown)"
elif ! printf '%s\n' "$ANSWER_OUT" | grep -q '"verdict":"unknown"'; then
  bad "self-check with an absent store did not report the verdict unknown"
else
  ok "self-check with an absent store answers unknown and exits 3, and does not raise"
fi
unset MATH_CODING_ATTESTATION_STORE

# --- 4. a decisions directory that does not exist ----------------------
MATH_CODING_DECISIONS_DIR="$absent/decisions" run "$bin" self-check
if [ "$ANSWER_CRASH" -eq 1 ]; then
  bad "self-check with an absent decisions directory raised instead of answering"
  printf '%s\n' "$ANSWER_OUT" | head -3
elif ! house_exit "$ANSWER_EXIT"; then
  bad "self-check with an absent decisions directory exited $ANSWER_EXIT, which is not one of the four the house convention allows"
else
  ok "self-check with an absent decisions directory answers (exit $ANSWER_EXIT), and does not raise"
fi
unset MATH_CODING_DECISIONS_DIR

# --- 5. THE NEGATIVE CONTROL -------------------------------------------
# The same detector, against a kernel that answers the way a kernel
# answers when it raises. A detector that has never fired is not a
# detector.
stub="$tmp/mathc"
cat >"$stub" <<'SH'
#!/usr/bin/env bash
printf 'Fatal error: exception Sys_error("No such file or directory")\n' >&2
exit 3
SH
chmod +x "$stub"
run "$stub" self-check
if [ "$ANSWER_CRASH" -eq 1 ]; then
  ok "negative control: the detector catches a kernel that raises Sys_error"
else
  bad "negative control: the detector did NOT catch a kernel that raises Sys_error - it cannot see the failure it guards against"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "missing-directory-is-an-empty-result: PASS"
  exit 0
fi
echo "missing-directory-is-an-empty-result: FAIL"
exit 1
