#!/usr/bin/env bash
# adapters: junit-attestation-import fixture
#
# Asserts that `mc attest FILE` parses a JUnit XML report and emits
# a JSON summary on stdout. This is the acceptance gate for
# obligation junit-attestation-import in bootstrap/adapters.yaml.
#
# The fixture:
#   - writes a minimal JUnit XML report to a temp file
#   - invokes `_build/default/bin/mathc.exe attest <tmp>`
#   - asserts exit 0
#   - asserts stdout is a JSON object containing the keys
#     "suite_name", "test_count", "failure_count",
#     "skip_count", and "tests"
#   - asserts the tests array contains at least one pass and
#     one failure (so a parser that returns an empty array is
#     rejected)
#
# Negative run (before junit-attestation-import lands):
#   bin/mathc.exe has no `attest` subcommand. The dispatcher
#   prints "mc: unknown command: attest" to stderr and exits 2.
#   The fixture fails because INNER_EC is 2 (not 0) and the
#   stdout body is empty.
#
# Positive run (after junit-attestation-import lands):
#   INNER_EC is 0; stdout is a JSON object containing
#   "suite_name", "test_count", "failure_count",
#   "skip_count", and "tests"; the "tests" array contains at
#   least one element with "result":"pass" and one element
#   with "result":"fail".

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "junit-attestation-import:"

log=$(mktemp)
junit=$(mktemp --suffix=.xml)
json_out=$(mktemp)
jq_counts=$(mktemp)
jq_results=$(mktemp)
trap 'rm -f "$log" "$junit" "$json_out" "$jq_counts" "$jq_results"' EXIT

# Minimal but realistic JUnit XML: one suite, three tests (one
# pass, one failure, one skipped). The hand-rolled parser must
# surface all three. Empty newline inside the failure message
# is intentional: the parser's CDATA/text handling must not
# choke on whitespace inside a tag body.
cat >"$junit" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="sample.Suite" tests="3" failures="1" errors="0" skipped="1">
  <testcase classname="sample.A" name="ok" time="0.01"/>
  <testcase classname="sample.B" name="broken" time="0.02">
    <failure message="expected 1 but was 2" type="AssertionError">
      stack frame 1
      stack frame 2
    </failure>
  </testcase>
  <testcase classname="sample.C" name="later" time="0.0">
    <skipped/>
  </testcase>
</testsuite>
XML

# Capture JSON into a dedicated file. The wrapper log is a mix
# of stdout/stderr from dune, nix develop's banner, and our
# binary's stderr; using a separate file for the JSON body
# keeps the assertions clean. INNER_EC marker tells us the
# binary's exit status regardless of what was printed.
if ! nix develop .#test --command bash -c '
  dune build --root . bin/mathc.exe || exit 99
  _build/default/bin/mathc.exe attest "$1" > "$2"
  echo INNER_EC=$?
' bash "$junit" "$json_out" >"$log" 2>&1; then
  echo "  FAIL wrapper exited nonzero (build or runtime)" >&2
  cat "$log" >&2
  exit 1
fi

inner_ec=$(grep '^INNER_EC=' "$log" | tail -1 | cut -d= -f2)
if [ -z "$inner_ec" ]; then
  echo "  FAIL no INNER_EC marker in wrapper output" >&2
  cat "$log" >&2
  exit 1
fi

if [ "$inner_ec" != "0" ]; then
  echo "  FAIL mc attest exited $inner_ec (expected 0)" >&2
  cat "$log" >&2
  exit 1
fi

body=$(cat "$json_out")

# Strip trailing whitespace/newline introduced by print_endline.
body=$(printf '%s' "$body" | sed 's/[[:space:]]*$//')

# It must be a single JSON object.
if ! printf '%s' "$body" | grep -q '{'; then
  echo "  FAIL stdout did not contain a JSON object" >&2
  cat "$log" >&2
  exit 1
fi
if ! printf '%s' "$body" | grep -q '}'; then
  echo "  FAIL stdout JSON object not closed" >&2
  cat "$log" >&2
  exit 1
fi

# Required top-level keys.
missing=0
for key in suite_name test_count failure_count skip_count tests; do
  if ! printf '%s' "$body" | grep -qE "\"$key\""; then
    echo "  FAIL JSON body missing key \"$key\"" >&2
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  cat "$log" >&2
  exit 1
fi

# Use jq to validate that the body parses AND that the test
# array contains the expected verdicts. jq is in the dev
# shell's package list (see flake.nix:35). Each jq call is
# wrapped in its own nix develop; the dev shell prints a banner
# to stdout before running the inner command, so we route jq's
# output through a temp file and discard the banner.
if ! nix develop .#test --command bash -c '
  jq -e . "$1" >/dev/null
' bash "$json_out" >/dev/null 2>&1; then
  echo "  FAIL stdout did not parse as JSON (jq)" >&2
  cat "$log" >&2
  exit 1
fi

# Extract the test-counts via jq and assert pass/fail/skip
# counts match the fixture's XML. jq writes its result to a
# dedicated file because the nix develop banner shares stdout
# with jq and would otherwise pollute the captured variable.
# We use a jq expression that doesn't need string-interpolation
# syntax (\(...)) so we don't have to fight bash's quote
# handling inside single-quoted command strings.
nix develop .#test --command bash -c '
  jq -r "[.test_count, .failure_count, .skip_count] | join(\" \")" "$1" > "$2"
' bash "$json_out" "$jq_counts" >/dev/null 2>&1
parsed_counts=$(cat "$jq_counts")
if [ "$parsed_counts" != "3 1 1" ]; then
  echo "  FAIL counts (test/failure/skip) were '$parsed_counts' (expected '3 1 1')" >&2
  cat "$log" >&2
  exit 1
fi

# Verify the per-test array surfaced at least one pass and one
# fail result. We use jq because the field name "result" could
# be matched lexically inside the failure message; jq confirms
# the structural verdict.
nix develop .#test --command bash -c '
  jq -r "[.tests[].result] | sort | unique | join(\",\")" "$1" > "$2"
' bash "$json_out" "$jq_results" >/dev/null 2>&1
results=$(cat "$jq_results")
case "$results" in
  *pass*|*fail*|*skip*)
    ;;
  *)
    echo "  FAIL test array did not surface any pass/fail/skip results" >&2
    echo "       parsed results: $results" >&2
    cat "$log" >&2
    exit 1
    ;;
esac
if ! printf '%s' "$results" | grep -q "pass"; then
  echo "  FAIL test array did not surface a 'pass' result" >&2
  cat "$log" >&2
  exit 1
fi
if ! printf '%s' "$results" | grep -q "fail"; then
  echo "  FAIL test array did not surface a 'fail' result" >&2
  cat "$log" >&2
  exit 1
fi

echo "  ok   mc attest sample.xml exited 0 with JUnit JSON (3 tests, 1 fail, 1 skip)"
exit 0
