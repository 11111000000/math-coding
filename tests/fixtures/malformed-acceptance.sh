#!/usr/bin/env bash
# T4 fixture: parses a decision with a malformed acceptance item
# (verifier field present but result has an unknown value) and
# asserts that `mc validate` emits MC-MALFORMED-ACCEPTANCE.
#
# The parser returns Domain.All [] for a malformed item (verifier
# half fails to parse) — that's why we use "positive-" prefix
# even though the item is rejected: the *decision* still parses,
# the *acceptance list* is just one shorter.
#
# Strategy:
#   - run `mc validate positive-malformed-acceptance.json`
#   - assert exit 0 (kernel accepts the decision)
#   - assert stderr contains "MC-MALFORMED-ACCEPTANCE"
#   - assert stdout begins with "accept:"

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "malformed-acceptance:"

log=$(mktemp)
trap 'rm -f "$log"' EXIT

fixture="fixtures/conformance/decision/positive-malformed-acceptance.json"
if ! nix develop .#test --command bash -c "
  dune build --root . bin/mathc.exe || exit 99
  _build/default/bin/mathc.exe validate '$fixture'
  echo INNER_EC=\$?
" >"$log" 2>&1; then
  echo "  FAIL wrapper exited nonzero" >&2
  cat "$log" >&2
  exit 1
fi

inner_ec=$(grep '^INNER_EC=' "$log" | tail -1 | cut -d= -f2)
if [ "$inner_ec" != "0" ]; then
  echo "  FAIL mc validate exited $inner_ec (expected 0; decision still parses)" >&2
  cat "$log" >&2
  exit 1
fi

if ! grep -q '^accept:' "$log"; then
  echo "  FAIL stdout missing 'accept:' verdict" >&2
  cat "$log" >&2
  exit 1
fi

if ! grep -q 'MC-MALFORMED-ACCEPTANCE' "$log"; then
  echo "  FAIL stderr missing MC-MALFORMED-ACCEPTANCE diagnostic" >&2
  cat "$log" >&2
  exit 1
fi

if ! grep -q 'malformed-obligation' "$log"; then
  echo "  FAIL diagnostic does not name the obligation id" >&2
  cat "$log" >&2
  exit 1
fi

echo "  ok   MC-MALFORMED-ACCEPTANCE emitted, verdict still accept"
exit 0