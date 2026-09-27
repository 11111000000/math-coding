#!/usr/bin/env bash
# kernel-conformance-runner: waiver-parser fixture
#
# Asserts that the conformance runner actually exercises a waiver
# parser for every waiver fixture — producing accept/reject verdicts —
# instead of silently emitting Skip labels with the message
# "parser not yet in lib/".
#
# This is the acceptance gate for obligation waiver-parser. The
# obligation's claim is that waiver fixture parsing is wired through
# Codec and Schema, so the runner must create real per-fixture verdicts
# for fixtures/conformance/waiver/.
#
# Negative run (before this obligation lands):
#   tests/conformance.ml's parse_waiver_for_fixture returns Skip
#   unconditionally. The runner emits labels of the form
#   "waiver/<name> [expects=..., got=skipped (parser not yet in lib/)]"
#   and the test cases pass silently — no parser exercise.
#
# Positive run (after this obligation lands):
#   tests/conformance.ml calls Codec.parse_waiver. The positive
#   fixture (positive-active-window.json) parses to Some _ → "got=accepted";
#   the negative fixture (negative-missing-expiry.json) parses to None
#   because expires_at is missing → "got=rejected". Every waiver
#   fixture label therefore shows a real verdict.

set -uo pipefail
cd "$(dirname "$0")/../.."

log=$(mktemp)
trap 'rm -f "$log"' EXIT

echo "waiver-parser:"

# Build the runner executable first so failures here are surfaced
# immediately, not hidden behind dune test output.
if ! nix develop .#test --command bash -c \
     'dune build --root . tests/conformance.exe' >"$log" 2>&1; then
  echo "  FAIL could not build tests/conformance.exe" >&2
  tail -30 "$log" >&2
  exit 1
fi

# --force rebuilds and re-runs the test executables so Alcotest
# emits per-case labels on every invocation (otherwise the second
# `check.sh` run after a warm cache silently omits the [OK] lines).
# See OCAML_BEST_PRACTICES §11.14.
#
# ALCOTEST_COLUMNS disables Alcotest's display-side truncation
# (~73 columns by default). Without it the runner's verdict string
# is replaced by "..." and the fixture can't distinguish accept
# from skip. See OCAML_BEST_PRACTICES §11.14 and Alcotest's own
# env-var docs in alcotest/cli.ml.
if ! nix develop .#test --command bash -c \
     'ALCOTEST_COLUMNS=500 dune test --root . --force' >"$log" 2>&1; then
  echo "  FAIL dune test exit status was nonzero" >&2
  tail -30 "$log" >&2
  exit 1
fi

# Extract every Alcotest line mentioning a waiver fixture.
# Output format from the runner (one line per fixture, with
# ALCOTEST_COLUMNS wide enough not to truncate the verdict):
#   [OK] fixtures  N waiver/<name> [expects=<exp>, got=<act>]
wvr_lines=$(grep -E 'waiver/[A-Za-z0-9_.-]+\s+\[expects=' "$log" || true)

# The runner must enumerate the waiver fixtures. Empty means
# parse_waiver_for_fixture was removed or the dispatch table
# changed; this fixture should not silently pass.
if [ -z "$wvr_lines" ]; then
  echo "  FAIL no waiver fixture labels found in dune test output" >&2
  echo "       (the runner should create per-fixture test cases)" >&2
  tail -30 "$log" >&2
  exit 1
fi

# Every waiver label must NOT carry the bare-skip message. If
# the parser isn't wired, every label says
# "got=skipped (parser not yet in lib/)" — the test case is then
# silently passed by the (_, _ -> ()) arm of tests/conformance.ml.
if echo "$wvr_lines" | grep -qE 'got=skipped \(parser not yet in lib/\)'; then
  echo "  FAIL waiver fixtures are still being skipped by the runner" >&2
  echo "       parser gap: parse_waiver_for_fixture returns Skip" >&2
  echo "       labels found:" >&2
  echo "$wvr_lines" | sed 's/^/         /' >&2
  exit 1
fi

# Every waiver label must carry a real verdict (accepted or
# rejected). If we see neither, the parser was called but returned a
# verdict that isn't one of the two outcomes we expect.
if ! echo "$wvr_lines" | grep -qE 'got=(accepted|rejected)'; then
  echo "  FAIL waiver fixtures did not produce accept/reject verdicts" >&2
  echo "       labels found:" >&2
  echo "$wvr_lines" | sed 's/^/         /' >&2
  exit 1
fi

# Positive fixture: must be accepted by the parser.
# positive-active-window.json has all required fields (id, policy_id,
# rule, subject, issuer, issued_at, expires_at, reason, plus
# compensating_controls) and no scope.
if ! echo "$wvr_lines" \
     | grep -qE 'waiver/positive-active-window\.json.*got=accepted'; then
  echo "  FAIL waiver/positive-active-window.json was not accepted" >&2
  echo "       expected accept, got a different verdict" >&2
  echo "$wvr_lines" | sed 's/^/         /' >&2
  exit 1
fi

# Negative fixture: must be rejected because expires_at is missing
# (schemas/waiver.json lists it under required).
if ! echo "$wvr_lines" \
     | grep -qE 'waiver/negative-missing-expiry\.json.*got=rejected'; then
  echo "  FAIL waiver/negative-missing-expiry.json was not rejected" >&2
  echo "       expected reject (expires_at is required by the schema)" >&2
  echo "$wvr_lines" | sed 's/^/         /' >&2
  exit 1
fi

echo "  ok   waiver/positive-active-window.json accepted by Codec.parse_waiver"
echo "  ok   waiver/negative-missing-expiry.json rejected (no expires_at)"
exit 0