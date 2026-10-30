#!/usr/bin/env bash
# scripts/ci-step-exit-sim.sh — prove that the CI steps that report a
# verdict report the verdict they are supposed to report.
#
# WHY THIS EXISTS
# ---------------
# The `.github/workflows/ci.yml` step `mathc self-check
# (bootstrap-gate block)` shipped with `set +e` and ended on a `jq`
# diagnostic dump, so the step's status was jq's status. `mathc
# self-check` returning exit 3 (verdict=unknown) produced a GREEN
# step: the blocking gate could not fail. `continue-on-error: false`
# did not help, because the step never failed.
#
# A comment asserting "PRs that produce verdict=fail or
# verdict=unknown block the merge" is not evidence. This script is
# the evidence: it extracts the step body from ci.yml, replays it
# VERBATIM against a stub `mathc`, and asserts the status the step
# MUST report in each case.
#
# TWO STEPS, TWO CONTRACTS.
#
# THE SELF-CHECK STEP IS AN AUDIT.
#
#   mathc exit 0 (verdict pass)    -> the step is GREEN.
#   mathc exit 1 (verdict fail)    -> the step is RED. A decisive
#                                     failure blocks, and nothing
#                                     else may stand in for it.
#   mathc exit 3 (verdict unknown) -> the step asks the CORPUS-DEBT
#                                     RATCHET
#                                     (tests/fixtures/self-check-debt-ceiling.sh)
#                                     and the step's status is the
#                                     RATCHET's: green while the
#                                     declared debt is under its
#                                     ceiling, red when it is over.
#                                     The verdict is `unknown`, not
#                                     `fail`, and the corpus's debt is
#                                     measured by a ceiling that may
#                                     only fall.
#   mathc crashes before emitting a verdict document
#                                  -> the diagnostic dump must not
#                                     become the step's status. The
#                                     status is still the ratchet's.
#
# THE GATE STEP IS THE WALL.
#
#   gate exit 0 (pass / open-with-waiver) -> the step is GREEN.
#   gate exit 1 (block)                   -> the step is RED.
#   gate exit 2 (input error)             -> the step is RED. A
#     ref that does not resolve is not a verdict, and a step that
#     cannot ask its question must not read as an answer.
#   gate exit 3 (unknown)                 -> the gate could not
#     conclude, and there are TWO reasons for that, told apart by the
#     gate's own `gaps_by_kind` histogram:
#       (a) the only gaps are `Unknown` -- the change touches a
#           promise the CORPUS does not keep by machine. That is the
#           corpus's own debt, and the RATCHET holds the line: the
#           step's status is the ratchet's.
#       (b) some gap is MissingEvidence, StaleEvidence or
#           NoAttestationStore -- THIS CHANGE IS NOT COVERED, and
#           the step is RED. It does not go to the ratchet: the
#           ratchet measures the corpus's debt, not this change's
#           evidence.
#   the gate produced no verdict document -> the step is RED: it
#     could not ask its question.
#
# So the rows below are FIVE for the self-check and EIGHT for the
# gate, and the gate's rows differ in the HISTOGRAM, not only in the
# exit code. A step that only knows "exit 3 means unknown" cannot
# tell a promise nobody keeps from a change nobody covered.
#
# TWO PROPERTIES MAKE THE REPLAY TRUSTWORTHY:
#   1. the body is read from ci.yml, never copied here, so the
#      simulation cannot drift away from the workflow it checks;
#   2. it runs under the same shell GitHub Actions uses for a `run:`
#      step on Linux — `bash --noprofile --norc -e -o pipefail {0}` —
#      because errexit and pipefail are part of the environment a
#      workflow step actually lives in.
#
# `nix` is stubbed with a shim that reproduces `nix develop .#test
# --command bash -c '<script>'` semantics (exec the inner bash,
# propagate its status). The corpus-debt ratchet is stubbed too: the
# real one measures the corpus, and the question here is what the step
# does with its answer. No nix store lock, no build, <2 s.
#
# NEGATIVE CONTROL
# ----------------
# A harness that cannot fail proves nothing. So the same run also
# replays the PRE-FIX step body — embedded verbatim below, taken from
# ci.yml at commit 817c545^ — and requires it to MISMATCH on mathc
# exits 1 and 3. A `pass` from this script therefore means two
# things at once: today's workflow carries the decision out, and the
# check is sharp enough to have caught the version that did not.
#
# Usage:  scripts/ci-step-exit-sim.sh [--verbose]
# Exit:   0 if every row of today's workflow agrees AND the pre-fix
#         control mismatches; 1 otherwise.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

# The steps this script replays. The self-check step was renamed from
# "mathc self-check (bootstrap-gate block)" to
# "mathc self-check (corpus audit)" on 2026-10-29, and this script
# kept the old name until 2026-10-30 -- so it failed on every run
# with "could not extract the run: block", and nothing ran it. A
# check that cannot find its subject is not a check.
STEP_SELF_CHECK='mathc self-check (corpus audit)'
STEP_GATE='mathc gate (merge verdict for the pushed diff)'
# $CI_YML overrides the workflow under test (a bare filename is resolved
# under .github/workflows/, an absolute or repo-relative path is used as
# given). Used to replay the check against a historical revision:
#   CI_YML=/tmp/ci-old.yml scripts/ci-step-exit-sim.sh
CI_YML="${CI_YML:-ci.yml}"
case "$CI_YML" in
  /*|.github/*) ;;
  *) CI_YML=".github/workflows/$CI_YML" ;;
esac
verbose=0
[ "${1:-}" = "--verbose" ] && verbose=1

fail=0

# --- 1. extract the step body from the workflow -----------------------
#
# A block scalar `run: |` continues while lines are either blank or
# indented deeper than the `run:` key itself. Stop at the first
# non-blank line that is not.
extract_step_body() {
  awk -v want="$1" '
    $0 == "      - name: " want { found = 1; next }
    found && /^[[:space:]]*run: \|[[:space:]]*$/ {
      inrun = 1
      # indentation of the `run:` key decides the block indentation
      match($0, /^ */)
      indent = RLENGTH
      next
    }
    found && inrun {
      if ($0 ~ /^[[:space:]]*$/) { print; next }
      match($0, /^ */)
      if (RLENGTH > indent) {
        line = substr($0, indent + 1)
        sub(/^  /, "", line)   # YAML strips one level of block indent
        print line
        next
      }
      exit
    }
  ' "$CI_YML"
}

self_check_body=$(extract_step_body "$STEP_SELF_CHECK")
if [ -z "$self_check_body" ]; then
  echo "FAIL: could not extract the run: block of step '$STEP_SELF_CHECK' from $CI_YML" >&2
  exit 1
fi
if ! grep -q 'mathc self-check' <<<"$self_check_body"; then
  echo "FAIL: extracted block does not mention 'mathc self-check'; wrong step matched" >&2
  exit 1
fi

gate_body=$(extract_step_body "$STEP_GATE")
if [ -z "$gate_body" ]; then
  echo "FAIL: could not extract the run: block of step '$STEP_GATE' from $CI_YML" >&2
  exit 1
fi
if ! grep -q 'mathc gate' <<<"$gate_body"; then
  echo "FAIL: extracted block does not mention 'mathc gate'; wrong step matched" >&2
  exit 1
fi
[ "$verbose" = 1 ] && { printf '%s\n' "$self_check_body"; printf '%s\n' "$gate_body"; }

# --- 2. build the sandbox ---------------------------------------------
sandbox=$(mktemp -d -t ci-step-exit-sim.XXXXXX)
trap 'rm -rf "$sandbox"' EXIT

mkdir -p "$sandbox/bin" "$sandbox/_build/install/default/bin" "$sandbox/tmp" \
         "$sandbox/tests/fixtures"

# Stub of the corpus-debt ratchet. The step runs it when the verdict
# is `unknown` and the only gaps are the corpus's declared promises,
# and the step's status IS the ratchet's status -- that is the audit
# shape. The stub answers with STUB_RATCHET_EXIT, so the replay can
# ask what the step does when the pin HOLDS and when it BITES.
cat > "$sandbox/tests/fixtures/self-check-debt-ceiling.sh" <<'STUB'
#!/usr/bin/env bash
# Stub: the corpus-debt ratchet. The real one measures the corpus;
# the question here is what the CI step does with its answer.
exit "${STUB_RATCHET_EXIT:-0}"
STUB
chmod +x "$sandbox/tests/fixtures/self-check-debt-ceiling.sh"

# Stub mathc: writes a verdict document, exits $STUB_EXIT.
cat > "$sandbox/_build/install/default/bin/mathc" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  self-check|gate) : ;;
  *) echo "stub mathc: unexpected argv: $*" >&2; exit 64 ;;
esac
case "${STUB_EXIT:-0}" in
  0) verdict=pass ;;
  1) verdict=fail ;;
  2) verdict=input-error ;;
  3) verdict=unknown ;;
  *) verdict=pass ;;
esac
if [ "${STUB_JSON:-yes}" = no ]; then
  # Crash-before-JSON case: nothing on stdout, a message on stderr. The
  # step must still report the verdict it must report, not the status
  # of the `cat` that prints the message.
  echo "stub mathc: fatal before emitting a verdict document" >&2
elif [ "${1:-}" = "gate" ]; then
  printf '{"verdict":"%s","obligations":4,"gaps_total":1,"gaps_by_kind":%s}\n' \
    "$verdict" "${STUB_GATE_KINDS:-{\}}"
else
  printf '{"verdict":"%s","kernel_digest":"stub","repository_digest":"stub","subjects":[]}\n' \
    "$verdict"
fi
exit "${STUB_EXIT:-0}"
STUB
chmod +x "$sandbox/_build/install/default/bin/mathc"

# Stub nix: `nix develop .#test --command bash -c '<script>'` must exec
# the script under bash and propagate its exit status verbatim.
cat > "$sandbox/bin/nix" <<'STUB'
#!/usr/bin/env bash
[ "${1:-}" = develop ] || { echo "stub nix: unsupported: $*" >&2; exit 64; }
shift
while [ $# -gt 0 ] && [ "$1" != "--command" ]; do shift; done
[ $# -gt 0 ] || { echo "stub nix: missing --command" >&2; exit 64; }
shift
[ "${1:-}" = bash ] || exec "$@"
shift
[ "$1" = "-c" ] || exec "$@"
shift
exec bash -c "${1:-}"
STUB
chmod +x "$sandbox/bin/nix"

# The steps write their scratch files to absolute paths under /tmp; keep
# them inside the sandbox so repeated runs cannot read each other's
# leftovers and so a real /tmp is not trashed. replay_block() does the
# rewrite per block.
# --- 3. replay one block for each verdict -----------------------------
#
#   $1 = row label        $2 = path to the block file
#   $3 = expect: agree | mismatch
#   $4 = the case list
#
# Each case is
#   "label|exit|emit JSON?|ratchet exit|expected step exit|gate kinds"
#
# The EXPECTED step exit is not always the kernel's exit: an `unknown`
# verdict with no missing evidence is delegated to the corpus-debt
# ratchet, and the step's status is the ratchet's. Two rows differ
# only in the ratchet's answer, because "unknown is green while the
# debt is under its ceiling" and "the pin can still make it red" are
# different claims.
#
# `agree`    — the step's status must be the expected one in every
#              row.
# `mismatch` — the block must swallow at least one non-zero exit;
#              that is what a broken step looks like, and the
#              negative control depends on observing it.
replay_block() {
  local label=$1 block_file=$2 expect=$3 cases=$4
  local scratch="$sandbox/tmp/scratch."
  local body
  body="$sandbox/block-$(printf '%s' "$label" | tr -c 'a-zA-Z0-9' '_').sh"
  local repl
  repl="$(cat "$block_file")"
  repl=${repl//\/tmp\/self-check\./$scratch}
  repl=${repl//\/tmp\/gate\./$scratch}
  printf '%s\n' "$repl" > "$body"

  printf '\n%s (expect: %s)\n' "$label" "$expect"
  printf '%-26s %-10s %-12s %-12s %s\n' 'case' 'exit' 'ratchet' 'step exit' 'verdict'
  printf '%-26s %-10s %-12s %-12s %s\n' '--------------------------' '----------' '------------' '------------' '-------'

  # label|exit|emit JSON?|ratchet exit|expected step exit|gate kinds
  local case_spec name exit_code emit_json ratchet_exit expected kinds step_exit agree
  while IFS= read -r case_spec; do
    [ -z "${case_spec:-}" ] && continue
    IFS='|' read -r name exit_code emit_json ratchet_exit expected kinds <<<"$case_spec"

    step_exit=0
    (
      cd "$sandbox" || exit 1
      PATH="$sandbox/bin:$PATH" \
        STUB_EXIT="$exit_code" \
        STUB_JSON="$emit_json" \
        STUB_GATE_KINDS="$kinds" \
        STUB_RATCHET_EXIT="$ratchet_exit" \
        bash --noprofile --norc -e -o pipefail "$body"
    ) >"$sandbox/out.$name" 2>&1 || step_exit=$?

    [ "$verbose" = 1 ] && sed 's/^/    | /' "$sandbox/out.$name"

    if [ "$step_exit" = "$expected" ]; then agree='ok'; else agree='MISMATCH'; fi
    case "$expect" in
      agree)
        [ "$agree" = ok ] || fail=1
        ;;
      mismatch)
        # The control must swallow the non-zero exits; a green row on
        # exit 0 is fine either way.
        if [ "$exit_code" -ne 0 ] && [ "$step_exit" = "$exit_code" ]; then fail=1; fi
        ;;
    esac
    printf '%-26s %-10s %-12s %-12s %s\n' "$name" "$exit_code" "exit $ratchet_exit" "$step_exit" "$agree"
  done <<<"$cases"
}

# --- 4. the blocks -----------------------------------------------
printf '%s\n' "$self_check_body" > "$sandbox/self-check.sh"
printf '%s\n' "$gate_body" > "$sandbox/gate.sh"

# THE SELF-CHECK STEP: five rows, and the exit-3 row twice.
replay_block "self-check: current $CI_YML" "$sandbox/self-check.sh" agree "
verdict=pass|0|yes|0|0|
verdict=fail|1|yes|0|1|
verdict=unknown|3|yes|0|0|
verdict=unknown, pin bites|3|yes|1|1|
no-json-document|3|no|0|0|"

# THE GATE STEP: eight rows. The exit-3 rows differ in the gate's
# own histogram, because "the change touches a promise nobody keeps"
# and "the change is not covered" are different claims and one exit
# code cannot carry both.
replay_block "gate: current $CI_YML" "$sandbox/gate.sh" agree "
pass|0|yes|0|0|{}
block|1|yes|0|1|{\"FailedEvidence\":1}
input error|2|no|0|1|{}
unknown: declarations|3|yes|0|0|{\"Unknown\":3}
unknown: declarations, pin bites|3|yes|1|1|{\"Unknown\":3}
unknown: no evidence|3|yes|0|1|{\"MissingEvidence\":2}
unknown: stale evidence|3|yes|0|1|{\"StaleEvidence\":1}
no verdict document|3|no|0|1|{}"

# The pre-fix body, copied from ci.yml at commit 817c545^ (the last
# revision where the step still ended on the jq dump under set +e).
cat > "$sandbox/prefix.sh" <<'PREFIX_EOF'
set +e
nix develop .#test --command bash -c \
  '_build/install/default/bin/mathc self-check > /tmp/self-check.json 2> /tmp/self-check.err; \
   echo "self-check exit=$?"; \
   jq -c "{verdict, kernel_digest, repository_digest, subjects_count: (.subjects | length)}" /tmp/self-check.json || cat /tmp/self-check.err'
PREFIX_EOF
replay_block "self-check: pre-fix control (ci.yml @ 817c545^)" "$sandbox/prefix.sh" mismatch "
verdict=pass|0|yes|0|0|
verdict=fail|1|yes|0|1|
verdict=unknown|3|yes|0|0|"

echo
if [ "$fail" -ne 0 ]; then
  echo "ci-step-exit-sim: FAIL — an expectation above did not hold" >&2
  exit 1
fi
echo "ci-step-exit-sim: ok — today's steps report the verdicts they must report:"
echo "                   self-check: pass -> green, fail -> red, unknown -> the"
echo "                   corpus-debt ratchet's status (green while the debt is under"
echo "                   its ceiling, red when the pin bites);"
echo "                   gate: pass -> green, block -> red, input error -> red,"
echo "                   unknown -> the ratchet's status when the only gaps are the"
echo "                   corpus's declarations, red when the change is not covered;"
echo "                   pre-fix control demonstrably swallows it"
