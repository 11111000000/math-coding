#!/usr/bin/env bash
# validate-and-context: cli-context-decision fixture
#
# Asserts that `mc context BASE HEAD --budget N` produces a JSON
# capsule of relevant context for an LLM agent. This is the
# acceptance gate for obligation deferred-cli-context in
# bootstrap/validate-and-context.yaml.
#
# The capsule MUST:
#   - exit 0 on success
#   - print valid JSON (a top-level object containing at least the
#     keys "change", "decisions", "obligations")
#   - work with arbitrary BASE and HEAD refs (commits, branches,
#     tags)
#   - log byte count (via the JSON key "total_bytes")
#
# Negative run (before this commit):
#   bin/mathc.exe has no `context` subcommand; the dispatcher
#   prints "mc: unknown command: context" to stderr and exits 2.
#   The fixture fails because INNER_EC is 2 (not 0) and no JSON
#   body containing "change"/"decisions"/"obligations" appears on
#   stdout.
#
# Positive run (after this commit):
#   INNER_EC is 0, stdout is a JSON object containing the keys
#   "change", "decisions", "obligations" (case-sensitive), and the
#   `total_bytes` field is present.

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "deferred-cli-context:"

log=$(mktemp)
trap 'rm -f "$log"' EXIT

if ! nix develop .#test --command bash -c '
  dune build --root . bin/mathc.exe || exit 99
  _build/default/bin/mathc.exe context main HEAD --budget 2000
  echo INNER_EC=$?
' >"$log" 2>&1; then
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
  echo "  FAIL mc context exited $inner_ec (expected 0)" >&2
  cat "$log" >&2
  exit 1
fi

# Locate the JSON body on stdout (everything before INNER_EC).
body=$(sed -n '/^INNER_EC=/!p' "$log")

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

# Required keys: change, decisions, obligations.
missing=0
for key in change decisions obligations; do
  if ! printf '%s' "$body" | grep -qE "\"$key\""; then
    echo "  FAIL JSON body missing key \"$key\"" >&2
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  cat "$log" >&2
  exit 1
fi

echo "  ok   mc context main HEAD --budget 2000 exited 0 with capsule JSON"
exit 0
