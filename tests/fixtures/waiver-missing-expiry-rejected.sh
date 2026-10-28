#!/usr/bin/env bash
# tests/fixtures/waiver-missing-expiry-rejected.sh
#
# Verifier for decisions/waiver-missing-expiry-rejected-2026-10.yaml.
#
# THE CLAIM. A waiver is a grant, and a grant without a validity
# interval is not a grant: `expires_at` is one of the four required
# bounds (lib/waiver.ml), and the schema requires it. The validator
# used to accept a waiver on the strength of its SCHEMA NAME, with
# the waiver's own fields never parsed, so a waiver with no expiry
# was accepted.
#
# WHAT THIS FIXTURE CHECKS. The project's own corpus says it must
# be rejected -- fixtures/conformance/waiver/negative-missing-expiry.json
# is a negative fixture whose NAME says so. This fixture asserts the
# rejection, and it asserts the rejection MESSAGE, because a
# rejection that does not say which field is missing is a rejection
# the reader cannot act on.
#
# THE NEGATIVE CONTROL. A waiver WITH an expiry must still be
# accepted. Without this, a validator that rejected every waiver
# would pass this fixture, and the fix would have turned a gap into
# a wall.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# The binary. The same two candidates the other fixtures use.
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
  echo "waiver-missing-expiry-rejected: FAIL"
  exit 1
fi

negative="fixtures/conformance/waiver/negative-missing-expiry.json"

# --- 1. the waiver without an expiry MUST be rejected ---------------------
out="$("$bin" validate "$negative" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ]; then
  bad "a waiver without an expiry was ACCEPTED (exit 0); the family dispatch is routing it away from every parser again"
else
  ok "a waiver without an expiry is rejected (exit $rc)"
fi

# The rejection must NAME the field. A rejection that says only
# "invalid" sends the reader looking for the problem.
if printf '%s' "$out" | grep -q 'expires_at'; then
  ok "the rejection names the missing field: expires_at"
else
  bad "the rejection does not name expires_at: $out"
fi

# --- 2. the negative control: a waiver WITH an expiry is accepted --------
# A waiver that is well formed must still pass; a validator that
# rejected every waiver would satisfy the first half of this file.
control="$(mktemp -d)"
trap 'rm -rf "$control"' EXIT
cat >"$control/waiver.json" <<'JSON'
{
  "schema": "math-coding/waiver-3.0-alpha",
  "kind": "waiver",
  "id": "with-expiry",
  "policy_id": "repository-policy",
  "rule": "payment-side-effect/duplicate-delivery",
  "subject": "change:pr-481",
  "issuer": "human:lead",
  "issued_at": "2026-09-26T12:00:00Z",
  "expires_at": "2026-12-26T12:00:00Z",
  "reason": "the control case"
}
JSON
if "$bin" validate "$control/waiver.json" >/dev/null 2>&1; then
  ok "the control waiver (with an expiry) is accepted"
else
  bad "the control waiver (with an expiry) was rejected: the fix rejects every waiver"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "waiver-missing-expiry-rejected: PASS"
  exit 0
fi
echo "waiver-missing-expiry-rejected: FAIL"
exit 1
