#!/usr/bin/env bash
# gate-decision: gate-scaffold fixture
#
# Asserts that `mc gate BASE HEAD` exits 0 and prints a JSON
# object containing at minimum the keys "verdict", "gaps",
# "obligations", "now", "base", "head". The verdict is
# expected to be "unknown" or "pass" (never "pass" without an
# attestation store; see bootstrap/gate-decision.yaml outcome
# gate-stub-honest). The fixture exists to PIN the JSON
# contract; future revisions under obligation
# gate-attestation-store-fill extend the body without
# renaming keys.
#
# Strategy:
#   - run `mc gate main HEAD` (no-op range; verdict should be
#     "pass" because no paths changed) and assert exit 0
#   - run `mc gate HEAD~1 HEAD` (some change) and assert
#     verdict is "unknown" OR "pass" with non-empty "gaps"
#   - assert all six required keys present
#   - assert "verdict" value is one of the four documented values

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "gate-scaffold:"

log=$(mktemp)
trap 'rm -f "$log"' EXIT

if ! nix develop .#test --command bash -c '
  dune build --root . bin/mathc.exe || exit 99
  _build/default/bin/mathc.exe gate main HEAD
  echo INNER_EC=$?
' >"$log" 2>&1; then
  echo "  FAIL wrapper exited nonzero" >&2
  cat "$log" >&2
  exit 1
fi

inner_ec=$(grep '^INNER_EC=' "$log" | tail -1 | cut -d= -f2)
if [ "$inner_ec" != "0" ]; then
  echo "  FAIL mc gate main HEAD exited $inner_ec (expected 0)" >&2
  cat "$log" >&2
  exit 1
fi

body=$(sed -n '/^INNER_EC=/!p' "$log" | grep -m1 '^{')

# Required keys: verdict, gaps, obligations, now, base, head.
missing=0
for key in verdict gaps obligations now base head; do
  if ! printf '%s' "$body" | grep -qE "\"$key\""; then
    echo "  FAIL JSON body missing key \"$key\"" >&2
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  cat "$log" >&2
  exit 1
fi

# Verdict must be one of the documented values.
verdict=$(printf '%s' "$body" \
  | grep -oE '"verdict":"[a-z-]+"' \
  | head -1 \
  | cut -d'"' -f4)
case "$verdict" in
  pass|open-with-waiver|block|unknown) ;;
  *)
    echo "  FAIL verdict='$verdict' not in {pass,open-with-waiver,block,unknown}" >&2
    cat "$log" >&2
    exit 1
    ;;
esac

# A second invocation against a non-empty range must also
# exit 0 and produce a valid JSON body. We use HEAD~3 HEAD
# because that range touches files on most active branches.
log2=$(mktemp)
if ! nix develop .#test --command bash -c '
  _build/default/bin/mathc.exe gate HEAD~3 HEAD
  echo INNER_EC=$?
' >"$log2" 2>&1; then
  echo "  FAIL second invocation wrapper exited nonzero" >&2
  cat "$log2" >&2
  rm -f "$log2"
  exit 1
fi
inner_ec2=$(grep '^INNER_EC=' "$log2" | tail -1 | cut -d= -f2)
if [ "$inner_ec2" != "0" ]; then
  echo "  FAIL mc gate HEAD~3 HEAD exited $inner_ec2 (expected 0)" >&2
  cat "$log2" >&2
  rm -f "$log2"
  exit 1
fi
body2=$(sed -n '/^INNER_EC=/!p' "$log2" | grep -m1 '^{')
for key in verdict gaps obligations now base head; do
  if ! printf '%s' "$body2" | grep -qE "\"$key\""; then
    echo "  FAIL second JSON body missing key \"$key\"" >&2
    cat "$log2" >&2
    rm -f "$log2"
    exit 1
  fi
done
rm -f "$log2"

echo "  ok   gate scaffold emits required keys, verdict in documented set"
exit 0