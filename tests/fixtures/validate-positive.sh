#!/usr/bin/env bash
# validate-and-context: cli-validate-decision positive fixture
#
# Asserts that `mc validate FILE` accepts a parseable decision file,
# exits 0, and prints an "accept" verdict. This is the acceptance gate
# for obligation cli-validate-decision in
# bootstrap/validate-and-context.yaml.
#
# Negative run (before cli-validate-decision lands):
#   bin/mathc.exe is two lines: it ignores argv and prints
#   "math-coding 3.0-alpha: bootstrap". There is no `validate`
#   subcommand. The fixture fails because:
#     - either the binary exits 0 without producing a verdict
#       'accept' on stdout (bootstrap-hello behavior), or
#     - the dune build emits a warning that declares an unresolved
#       subcommand.
#   In either case the inner INNER_EC marker is absent or the
#   stdout-text grep for 'accept' misses.
#
# Positive run (after cli-validate-decision lands):
#   inner INNER_EC is 0, stdout contains "accept: ..." for the
#   decision id. The fixture exits 0.

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "cli-validate-decision (positive):"

log=$(mktemp)
trap 'rm -f "$log"' EXIT

# Build and run in a single wrapper command so the inner exit code is
# preserved via the INNER_EC marker. Without the marker, nix develop
# itself swallows the inner failure and reports 0 (since the final
# `echo` succeeds). Markers outlive that flattening.
if ! nix develop .#test --command bash -c '
  dune build --root . bin/mathc.exe || exit 99
  _build/default/bin/mathc.exe validate \
    fixtures/conformance/decision/positive-minimal.json
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
  echo "  FAIL mc validate positive-minimal.json exited $inner_ec (expected 0)" >&2
  cat "$log" >&2
  exit 1
fi

# Stdout must carry an accept verdict. The CLI is free to format the
# verdict however it likes; we accept any line containing the keyword
# "accept" so future reformatting of the human-readable output doesn't
# break this fixture.
if ! grep -qE '\baccept\b' "$log"; then
  echo "  FAIL stdout did not contain verdict 'accept' for positive fixture" >&2
  cat "$log" >&2
  exit 1
fi

echo "  ok   mc validate positive-minimal.json exited 0 with accept verdict"
exit 0
