#!/usr/bin/env bash
# validate-and-context: cli-validate-decision negative fixture
#
# Asserts that `mc validate FILE` rejects an invalid decision file,
# exits 1, and emits a recognisable diagnostic mentioning the missing
# field. This is the acceptance gate for obligation
# cli-validate-decision in bootstrap/validate-and-context.md.
#
# Negative run (before cli-validate-decision lands):
#   bin/mathc.exe is two lines and ignores argv — it always exits 0
#   after printing the bootstrap hello. The fixture fails because
#   the inner INNER_EC marker is 0 (not 1), or because no diagnostic
#   is printed.
#
# Positive run (after cli-validate-decision lands):
#   Decision.parse_decision returns None on the missing-commitment
#   fixture; the CLI exits 1, prints a diagnostic that names
#   "commitment" (the missing field) or carries the words "invalid"
#   or "error".

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "cli-validate-decision (negative):"

log=$(mktemp)
trap 'rm -f "$log"' EXIT

if ! nix develop .#test --command bash -c '
  dune build --root . bin/mathc.exe || exit 99
  _build/default/bin/mathc.exe validate \
    fixtures/conformance/decision/negative-missing-commitment.json
  echo INNER_EC=$?
' >"$log" 2>&1; then
  echo "  FAIL wrapper exited nonzero (likely build failure)" >&2
  cat "$log" >&2
  exit 1
fi

inner_ec=$(grep '^INNER_EC=' "$log" | tail -1 | cut -d= -f2)
if [ -z "$inner_ec" ]; then
  echo "  FAIL no INNER_EC marker in wrapper output" >&2
  cat "$log" >&2
  exit 1
fi

if [ "$inner_ec" != "1" ]; then
  echo "  FAIL mc validate negative-missing-commitment.json exited $inner_ec (expected 1)" >&2
  cat "$log" >&2
  exit 1
fi

# Diagnostic must carry at least one of: the missing field name, the
# word "invalid", or the word "error". The CLI may print on stdout or
# stderr; both are merged into the wrapper log here.
if ! grep -qiE 'commitment|invalid|error' "$log"; then
  echo "  FAIL diagnostic did not name the missing field, or 'invalid', or 'error'" >&2
  cat "$log" >&2
  exit 1
fi

echo "  ok   mc validate negative-missing-commitment.json exited 1 with diagnostic"
exit 0
