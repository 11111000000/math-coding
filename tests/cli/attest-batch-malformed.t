mathc attest-batch refuses a malformed manifest with exit 2 and a
precise diagnostic naming the offending line number. The exact
line-numbered message is the contract -- it lets the user fix the
manifest in place rather than guess which row broke.

The fixture is tests/cli/fixtures/attest-batch/manifest-malformed.tsv:
a single line `decision\tobligation` (only 2 columns) where the
parser expects 4 or 5.

Hermetic: MATH_CODING_DECISIONS_DIR and MATH_CODING_ATTESTATIONS_DIR
point at operator-named directories under the tmpdir so the test
cannot pollute the host checkout.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d) && cd "$tmpdir"
  $ export MATH_CODING_DECISIONS_DIR=".test-math-coding/decisions"
  $ export MATH_CODING_ATTESTATIONS_DIR=".test-math-coding/attestations"
  $ if mathc attest-batch \
  >   --manifest="$DUNE_SOURCEROOT/tests/cli/fixtures/attest-batch/manifest-malformed.tsv" \
  >   --out="$MATH_CODING_ATTESTATIONS_DIR" 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on malformed manifest"; exit 1
  > else
  >   echo "refused malformed manifest (exit $?)"
  > fi
  refused malformed manifest (exit 2)

The stderr body names the path, line, and reason. The reason MUST
include the literal `expected 4 or 5 TAB-separated fields`. We
verify the diagnostic by capturing stderr to a temp file and
grepping for the expected substrings; this avoids depending on
cram's regex/glob annotation support (which is brittle across
dune 3.x cram versions).

  $ mathc attest-batch \
  >   --manifest="$DUNE_SOURCEROOT/tests/cli/fixtures/attest-batch/manifest-malformed.tsv" \
  >   --out="$MATH_CODING_ATTESTATIONS_DIR" 2> /tmp/attest-batch-malformed.stderr
  [2]
  $ grep -q 'line 1: expected 4 or 5 TAB-separated fields, got 2' /tmp/attest-batch-malformed.stderr \
  >   && echo "stderr contains line+reason"
  stderr contains line+reason
  $ grep -q 'no-tabs-here' /tmp/attest-batch-malformed.stderr \
  >   && echo "stderr echoes offending line"
  stderr echoes offending line
  $ rm -f /tmp/attest-batch-malformed.stderr

No output directory is created when the manifest fails -- the
binary aborts BEFORE any row is processed.

  $ test ! -d "$MATH_CODING_ATTESTATIONS_DIR" && echo "no output dir created on malformed input"
  no output dir created on malformed input

A missing manifest file is also exit 2 (input error class per
OCAML_BEST_PRACTICES §4.3). The error message MUST include the path
the user passed so they can spot typos.

  $ if mathc attest-batch --manifest=/nonexistent/path.tsv 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on missing manifest"; exit 1
  > else
  >   echo "missing manifest refused (exit $?)"
  > fi
  missing manifest refused (exit 2)

Bad --result value (anything other than `pass` / `fail`) is exit 2.
The diagnostic names the offending value.

  $ if mathc attest-batch \
  >   --manifest="$DUNE_SOURCEROOT/tests/cli/fixtures/attest-batch/manifest.tsv" \
  >   --result=oops 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on bad --result"; exit 1
  > else
  >   echo "bad --result refused (exit $?)"
  > fi
  bad --result refused (exit 2)

  $ cd /
  $ rm -rf "$tmpdir"
  $ unset MATH_CODING_DECISIONS_DIR
  $ unset MATH_CODING_ATTESTATIONS_DIR
