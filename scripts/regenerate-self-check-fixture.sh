#!/usr/bin/env bash
# scripts/regenerate-self-check-fixture.sh
#
# BUILDER, not a verifier. This script WRITES the fixture
# tests/fixtures/self-check-pass/attestations/. It does not check
# anything, and it is no longer wired as the acceptance verifier for
# any obligation — a script that produces its own evidence and then
# declares that evidence correct is not a check
# (decisions/self-check-fixture-coverage-honest-2026-10.yaml@1).
# The verifier that READS the committed fixture and compares it
# against the live obligation set is
# scripts/check-self-check-fixture-coverage.sh.
#
# It regenerates one pass attestation per (decision_id, obligation_id)
# pair enumerated by `mathc packages --format=json`, so
# tests/cli/self-check-pass.t has a populated store to load via
# MATH_CODING_ATTESTATION_STORE.
#
# Run after any change to the obligation set (new decision, new
# obligation, retired decision). Idempotent: re-running overwrites
# the fixture with the current obligation set; obsolete fixtures are
# deleted.
#
# NON-DESTRUCTIVE BY CONSTRUCTION. rev 2 of this script generated into
# the live store `attestations/` and then moved every `*.json` it
# found there into the fixture:
#
#     for f in attestations/*.json; do mv "$f" "$FIXTURE_DIR/"; done
#
# That emptied a 765-file committed evidence store while the script
# exited 0, and it was declared as the acceptance verifier for
# `audit-0.0.21-fixes/self-check-pass-fixture-covers-all`, so the
# destruction was reported to the operator as a pass. Measured on the
# pre-fix script: attestations/ 765 -> 0, exit 0.
#
# Two things changed. (1) Generation is routed into $FIXTURE_DIR by
# the generator's own documented output-directory env var
# (MATH_CODING_ATTESTATIONS_DIR, scripts/generate-attestations.py),
# so no file is ever written into the live store and the `mv` loop is
# gone rather than merely re-pointed. (2) A before/after guard
# asserts the live store is bit-for-bit what it was, so a future
# re-introduction of a write is a non-zero exit, not a silent loss.

set -euo pipefail
cd "$(dirname "$0")/.."

FIXTURE_DIR="tests/fixtures/self-check-pass/attestations"
LIVE_STORE="attestations"

if [ ! -d "$LIVE_STORE" ]; then
  echo "refusing to run: live store '$LIVE_STORE' does not exist." >&2
  echo "This script must never create it; a missing store means the" >&2
  echo "tree is not the one it was written for." >&2
  exit 2
fi

# --- non-destructiveness guard: fingerprint the live store ----------
# Two cheap, complementary invariants. The count catches files ADDED
# or REMOVED, including the gitignored ones (`git status` will not
# list them, and the old `mv attestations/*.json` glob matched them).
# The status diff catches files MODIFIED in place. Both are compared
# before/after rather than asserted empty, so a store that was already
# dirty when this script started does not make it fail.
live_count() { find "$LIVE_STORE" -maxdepth 1 -type f -name '*.json' | wc -l | tr -d ' '; }
live_status() { git status --porcelain -- "$LIVE_STORE" 2>/dev/null || true; }

LIVE_COUNT_BEFORE=$(live_count)
LIVE_STATUS_BEFORE=$(live_status)

assert_store_untouched() {
  local stage="$1"
  local after_count after_status
  after_count=$(live_count)
  after_status=$(live_status)
  if [ "$after_count" != "$LIVE_COUNT_BEFORE" ]; then
    echo "FAIL: $stage changed the live store $LIVE_STORE/" >&2
    echo "  files before=$LIVE_COUNT_BEFORE after=$after_count" >&2
    exit 3
  fi
  if [ "$after_status" != "$LIVE_STATUS_BEFORE" ]; then
    echo "FAIL: $stage modified tracked files in the live store $LIVE_STORE/" >&2
    diff <(printf '%s\n' "$LIVE_STATUS_BEFORE") \
         <(printf '%s\n' "$after_status") >&2 || true
    exit 3
  fi
}

mkdir -p "$FIXTURE_DIR"

# Determine the binary path
MATHC="mathc"
if [ -x "_build/install/default/bin/mathc" ]; then
  MATHC="_build/install/default/bin/mathc"
fi

# Build the (decision, obligation, kind_, identity, result) TSV from the kernel.
# `mathc packages --format=json` is the canonical enumeration. We use
# `human:maintainer` as the producer identity (the doc/audit trail author
# for hand-verified obligations) and `result=pass` because every obligation
# in the test fixture is satisfied (a test fixture cannot model real CI).

TMP_TSV=$(mktemp)
trap 'rm -f "$TMP_TSV"' EXIT

"$MATHC" packages --format=json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for dec in d['decisions']:
    did = dec['decision_id']
    for ob in dec['obligations']:
        oid = ob['id']
        # Default: 'review' (human attestation), result=pass
        # Tests/cli fixtures: 'ci:build:cram' for cram-runnable
        kind_ = 'review'
        identity = 'human:maintainer'
        result = 'pass'
        print(f'{did}\t{oid}\t{kind_}\t{identity}\t{result}')
" > "$TMP_TSV"

# Drop existing fixture files. The scope is the FIXTURE, and it is
# spelled as a literal path: `find "$FIXTURE_DIR"` can only ever reach
# inside the fixture.
find "$FIXTURE_DIR" -maxdepth 1 -name "*.json" -delete

# Generate straight into the fixture. scripts/generate-attestations.py
# resolves its output directory as
#   $MATH_CODING_ATTESTATIONS_DIR  if set, else <repo_root>/attestations
# (documented in that script's docstring), so exporting the variable
# here is what routes the writes. Nothing is written into the live
# store, so there is nothing to move afterwards.
MATH_CODING_ATTESTATIONS_DIR="$FIXTURE_DIR" \
  python3 scripts/generate-attestations.py < "$TMP_TSV" 2>/dev/null

assert_store_untouched "generation"

count=$(find "$FIXTURE_DIR" -maxdepth 1 -type f -name '*.json' | wc -l | tr -d ' ')
echo "Regenerated $count attestations in $FIXTURE_DIR"
echo "live store $LIVE_STORE/: $LIVE_COUNT_BEFORE files, unchanged (verified)"
