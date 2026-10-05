#!/usr/bin/env bash
# scripts/regenerate-self-check-fixture.sh
#
# Regenerates tests/fixtures/self-check-pass/attestations/ to cover every
# (decision_id, obligation_id) pair enumerated by `mc packages --format=json`,
# producing a pass attestation for each. This is the acceptance gate for
# obligation `audit-0.0.21-fixes/self-check-pass-fixture-covers-all` and the
# substrate for tests/cli/self-check-pass.t returning verdict:pass.
#
# Pair list source: `mc packages --format=json` (the kernel's own enumeration).
# For each (decision, obligation), we emit one attestation JSON in the
# fixture store with the producer identity `human:maintainer` and
# result=pass. The cram test then loads this store via
# `MATH_CODING_ATTESTATION_STORE=tests/fixtures/self-check-pass/attestations`
# and asserts that `mc self-check` returns verdict=pass, subjects=29, unknown=0.
#
# Run after any change to the obligation set (new decision, new obligation,
# retired decision). The script is idempotent: re-running overwrites the
# fixture with the current obligation set; obsolete fixtures are deleted.

set -euo pipefail
cd "$(dirname "$0")/.."

FIXTURE_DIR="tests/fixtures/self-check-pass/attestations"
mkdir -p "$FIXTURE_DIR"

# Build the (decision, obligation, kind_, identity, result) TSV from the kernel.
# `mc packages --format=json` is the canonical enumeration. We use
# `human:maintainer` as the producer identity (the doc/audit trail author
# for hand-verified obligations) and `result=pass` because every obligation
# in the test fixture is satisfied (a test fixture cannot model real CI).

# Determine the binary path
MATHC="mathc"
if [ -x "_build/install/default/bin/mathc" ]; then
  MATHC="_build/install/default/bin/mathc"
fi

# Build TSV
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

# Drop existing fixture files
find "$FIXTURE_DIR" -name "*.json" -delete

# Generate
python3 scripts/generate-attestations.py < "$TMP_TSV" 2>&1 

# Move generated files to fixture
for f in attestations/*.json; do
  mv "$f" "$FIXTURE_DIR/"
done

count=$(ls "$FIXTURE_DIR" | wc -l)
echo "Regenerated $count attestations in $FIXTURE_DIR"
