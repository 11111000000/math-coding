#!/usr/bin/env bash
# T4 fixture: parses a decision with an ambiguous acceptance item
# (verifier AND review on the same object) and asserts that
# `mc validate` emits MC-AMBIGUOUS-ACCEPTANCE to stderr while
# still exiting 0 (the kernel accepts the verifier-half).
#
# Per OCAML_BEST_PRACTICES §9.1 the previous parser silently
# dropped the review when both fields were present; this fixture
# is the positive acceptance test for the diagnostic that surfaces
# the silent-drop defect.
#
# Strategy:
#   - run `mc validate positive-ambiguous-acceptance.json`
#   - assert exit 0 (kernel still accepts the verifier half)
#   - assert stderr contains "MC-AMBIGUOUS-ACCEPTANCE"
#   - assert stderr names the obligation id
#   - assert stdout begins with "accept:" (verdict still pass)

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "ambiguous-acceptance:"

log=$(mktemp)
trap 'rm -f "$log"' EXIT

fixture="fixtures/conformance/decision/positive-ambiguous-acceptance.json"
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
  echo "  FAIL mc validate exited $inner_ec (expected 0; verdict is still accept on verifier half)" >&2
  cat "$log" >&2
  exit 1
fi

if ! grep -q '^accept:' "$log"; then
  echo "  FAIL stdout missing 'accept:' verdict" >&2
  cat "$log" >&2
  exit 1
fi

if ! grep -q 'MC-AMBIGUOUS-ACCEPTANCE' "$log"; then
  echo "  FAIL stderr missing MC-AMBIGUOUS-ACCEPTANCE diagnostic" >&2
  cat "$log" >&2
  exit 1
fi

if ! grep -q 'obligation-with-ambiguous-acceptance' "$log"; then
  echo "  FAIL diagnostic does not name the obligation id" >&2
  cat "$log" >&2
  exit 1
fi

echo "  ok   MC-AMBIGUOUS-ACCEPTANCE emitted, verdict still accept"
exit 0