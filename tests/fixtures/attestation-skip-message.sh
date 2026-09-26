#!/usr/bin/env bash
# kernel-conformance-runner: attestation-parser fixture
#
# Asserts that the conformance runner actually exercises the
# attestation parser for every attestation fixture — producing
# accept/reject verdicts — instead of silently emitting Skip labels
# with the message "parser not yet in lib/".
#
# This is the acceptance gate for obligation attestation-parser in
# bootstrap/kernel-conformance-runner.yaml. The obligation's claim is
# that attestation fixture parsing is wired through Codec and Schema,
# so the runner must create real per-fixture verdicts.
#
# Negative run (before this obligation lands):
#   tests/conformance.ml's parse_attestation_for_fixture returns Skip
#   unconditionally. The runner emits labels of the form
#   "attestation/<name> [expects=..., got=skipped (parser not yet in lib/)]"
#   and the test cases pass silently — no parser exercise.
#
# Positive run (after this obligation lands):
#   tests/conformance.ml calls Codec.parse_attestation. The positive
#   fixture produces Some _ → "got=accepted"; the negative fixture
#   (result="successful", not in the enum) produces None → "got=rejected".
#   Every attestation fixture label therefore shows a real verdict.

set -uo pipefail
cd "$(dirname "$0")/../.."

log=$(mktemp)
trap 'rm -f "$log"' EXIT

echo "attestation-parser:"

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

# Extract every Alcotest line mentioning an attestation fixture.
# Output format from the runner (one line per fixture, with
# ALCOTEST_COLUMNS wide enough not to truncate the verdict):
#   [OK] fixtures  N attestation/<name> [expects=<exp>, got=<act>]
att_lines=$(grep -E 'attestation/[A-Za-z0-9_.-]+\s+\[expects=' "$log" || true)

# The runner must enumerate the attestation fixtures. Empty means
# parse_attestation_for_fixture was removed or the dispatch table
# changed; this fixture should not silently pass.
if [ -z "$att_lines" ]; then
  echo "  FAIL no attestation fixture labels found in dune test output" >&2
  echo "       (the runner should create per-fixture test cases)" >&2
  tail -30 "$log" >&2
  exit 1
fi

# Every attestation label must NOT carry the bare-skip message. If
# the parser isn't wired, every label says
# "got=skipped (parser not yet in lib/)" — the test case is then
# silently passed by the (_, _ -> ()) arm of tests/conformance.ml.
if echo "$att_lines" | grep -qE 'got=skipped \(parser not yet in lib/\)'; then
  echo "  FAIL attestation fixtures are still being skipped by the runner" >&2
  echo "       parser gap: parse_attestation_for_fixture returns Skip" >&2
  echo "       labels found:" >&2
  echo "$att_lines" | sed 's/^/         /' >&2
  exit 1
fi

# Every attestation label must carry a real verdict (accepted or
# rejected). If we see neither, the parser was called but returned a
# verdict that isn't one of the two outcomes we expect.
if ! echo "$att_lines" | grep -qE 'got=(accepted|rejected)'; then
  echo "  FAIL attestation fixtures did not produce accept/reject verdicts" >&2
  echo "       labels found:" >&2
  echo "$att_lines" | sed 's/^/         /' >&2
  exit 1
fi

# Positive fixture: must be accepted by the parser.
if ! echo "$att_lines" \
     | grep -qE 'attestation/positive-pass\.json.*got=accepted'; then
  echo "  FAIL attestation/positive-pass.json was not accepted" >&2
  echo "       expected accept, got a different verdict" >&2
  echo "$att_lines" | sed 's/^/         /' >&2
  exit 1
fi

# Negative fixture: must be rejected because result="successful" is
# not in the enum {pass, fail, inconclusive, infrastructure-error}.
if ! echo "$att_lines" \
     | grep -qE 'attestation/negative-unknown-result\.json.*got=rejected'; then
  echo "  FAIL attestation/negative-unknown-result.json was not rejected" >&2
  echo "       expected reject (result='successful' is not in the enum)" >&2
  echo "$att_lines" | sed 's/^/         /' >&2
  exit 1
fi

echo "  ok   attestation/positive-pass.json accepted by Codec.parse_attestation"
echo "  ok   attestation/negative-unknown-result.json rejected (result not in enum)"
exit 0
