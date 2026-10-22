#!/usr/bin/env bash
# scripts/ci-step-exit-sim.sh — prove that the CI self-check step's
# exit status is mathc's exit status.
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
# VERBATIM against a stub `mathc` that exits 0 / 1 / 3, and asserts
# that the step's status equals mathc's status in every case.
#
# Two properties make the replay trustworthy:
#   1. the body is read from ci.yml, never copied here, so the
#      simulation cannot drift away from the workflow it checks;
#   2. it runs under the same shell GitHub Actions uses for a `run:`
#      step on Linux — `bash --noprofile --norc -e -o pipefail {0}` —
#      because errexit and pipefail are part of the environment a
#      workflow step actually lives in.
#
# A fourth row drives mathc into a crash-before-JSON exit 3, so the
# diagnostic fallback (`cat ... || true`) is exercised too: it must not
# become the step's status either.
#
# `nix` is stubbed with a shim that reproduces `nix develop .#test
# --command bash -c '<script>'` semantics (exec the inner bash,
# propagate its status). No nix store lock, no build, <2 s.
#
# Usage:  scripts/ci-step-exit-sim.sh [--verbose]
# Exit:   0 if step_exit == mathc_exit in every row; 1 otherwise.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

STEP_NAME='mathc self-check (bootstrap-gate block)'
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
  awk -v want="$STEP_NAME" '
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

step_body=$(extract_step_body)
if [ -z "$step_body" ]; then
  echo "FAIL: could not extract the run: block of step '$STEP_NAME' from $CI_YML" >&2
  exit 1
fi
if ! grep -q 'mathc self-check' <<<"$step_body"; then
  echo "FAIL: extracted block does not mention 'mathc self-check'; wrong step matched" >&2
  exit 1
fi
[ "$verbose" = 1 ] && printf '%s\n' "$step_body"

# --- 2. build the sandbox ---------------------------------------------
sandbox=$(mktemp -d -t ci-step-exit-sim.XXXXXX)
trap 'rm -rf "$sandbox"' EXIT

mkdir -p "$sandbox/bin" "$sandbox/_build/install/default/bin" "$sandbox/tmp"

# Stub mathc: writes a verdict document, exits $STUB_MATHC_EXIT.
cat > "$sandbox/_build/install/default/bin/mathc" <<'STUB'
#!/usr/bin/env bash
[ "${1:-}" = self-check ] || { echo "stub mathc: unexpected argv: $*" >&2; exit 64; }
case "${STUB_MATHC_EXIT:-0}" in
  0) verdict=pass ;;
  1) verdict=fail ;;
  3) verdict=unknown ;;
  *) verdict=pass ;;
esac
if [ "${STUB_MATHC_JSON:-yes}" = no ]; then
  # Crash-before-JSON case: nothing on stdout, a message on stderr. The
  # step must still report mathc's status, not the status of the
  # `cat` that prints the message.
  echo "stub mathc: fatal before emitting a verdict document" >&2
else
  printf '{"verdict":"%s","kernel_digest":"stub","repository_digest":"stub","subjects":[]}\n' \
    "$verdict"
fi
exit "${STUB_MATHC_EXIT:-0}"
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
[ "${1:-}" = -c ] || exec "$@"
shift
exec bash -c "${1:-}"
STUB
chmod +x "$sandbox/bin/nix"

# The step writes its scratch files to absolute paths under /tmp; keep
# them inside the sandbox so repeated runs cannot read each other's
# leftovers and so a real /tmp is not trashed.
scratch="$sandbox/tmp/self-check."
step_body=${step_body//\/tmp\/self-check\./$scratch}
printf '%s\n' "$step_body" > "$sandbox/step.sh"

# --- 3. replay the step for each verdict ------------------------------
printf '%-18s %-12s %-12s %s\n' 'mathc verdict' 'mathc exit' 'step exit' 'verdict'
printf '%-18s %-12s %-12s %s\n' '-----------------' '-----------' '-----------' '-------'

# label|mathc exit|emit JSON?
for case_spec in 'verdict=pass 0 yes' \
                 'verdict=fail 1 yes' \
                 'verdict=unknown 3 yes' \
                 'no-json-document 3 no'; do
  # shellcheck disable=SC2086
  set -- $case_spec
  verdict=$1
  mathc_exit=$2
  emit_json=$3

  step_exit=0
  (
    cd "$sandbox" || exit 1
    PATH="$sandbox/bin:$PATH" \
      STUB_MATHC_EXIT="$mathc_exit" \
      STUB_MATHC_JSON="$emit_json" \
      bash --noprofile --norc -e -o pipefail "$sandbox/step.sh"
  ) >"$sandbox/out.$mathc_exit.$emit_json" 2>&1 || step_exit=$?

  [ "$verbose" = 1 ] && sed 's/^/    | /' "$sandbox/out.$mathc_exit.$emit_json"

  if [ "$step_exit" = "$mathc_exit" ]; then
    agree='ok'
  else
    agree='MISMATCH'
    fail=1
  fi
  printf '%-18s %-12s %-12s %s\n' "$verdict" "$mathc_exit" "$step_exit" "$agree"
done

echo
if [ "$fail" -ne 0 ]; then
  echo "ci-step-exit-sim: FAIL — at least one verdict did not reach the step status" >&2
  exit 1
fi
echo "ci-step-exit-sim: ok — the step's exit status equals mathc's in all four rows"
