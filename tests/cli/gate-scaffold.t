mathc gate --no-execute BASE HEAD -- the MERGE GATE's question: the
decisions this change touches, with no verifier run -- exits 0 and
prints a JSON object containing at minimum the keys "verdict", "gaps",
"obligations", "now", "base", "head". The verdict is "unknown" or
"pass" (never "pass" without an attestation store; see
bootstrap/gate-decision.yaml outcome gate-stub-honest). The fixture
pins the JSON contract; future revisions under obligation
gate-attestation-store-fill extend the body without renaming keys.
`now` is scrubbed (non-deterministic). The `gaps` array is a REPORT
about the gaps, and the report is bounded: `gaps_total` is how many
gaps there are, `gaps_by_kind` is the histogram, and `gaps` holds the
first N of them (decisive first), with `gaps_truncated` saying
whether the list is the whole set. The verdict is computed from EVERY
gap either way. Acceptance gate for obligation gate-stub-honest in
bootstrap/gate-decision.yaml.

The gate's default is now the scoped, executing merge gate. This fixture
asks the MERGE GATE's question -- the decisions this change touches --
and it runs no verifier at all, which is spelled out with
`--no-execute`: a verifier that runs `dune runtest` inside a `dune
runtest` recurses until the test times out. The fixture pins the
document's contract and says nothing about the obligation count, so the
scope does not change the question it asks.

  $ cd "$DUNE_SOURCEROOT"
  $ $INSIDE_DUNE/bin/mathc.exe gate --no-execute main HEAD | jq -c 'keys'
  ["base","gaps","gaps_by_kind","gaps_total","gaps_truncated","head","now","obligations","verdict"]

The counts and the list agree, and the list never claims to be more
than it is.

  $ $INSIDE_DUNE/bin/mathc.exe gate --no-execute main HEAD | jq -c '{consistent: (.gaps_total >= (.gaps | length)), honest_truncation: (.gaps_truncated == (.gaps_total > (.gaps | length)))}'
  {"consistent":true,"honest_truncation":true}

The cap is a cap: the printed list never exceeds it, and the total
is reported beside it.

The assertion is the CAP, not the count. This fixture used to pin
`shown: 0` as well, and that number held only while `main..HEAD` was
an empty diff -- that is, only on the default branch. On any branch
with a change in it, the merge gate has gaps to report and the count
is the size of that change, not a property of the gate. The contract
this fixture pins is "the printed list never exceeds the cap"; the
number beside it is the change's, and the change is not the fixture's
to predict.

  $ $INSIDE_DUNE/bin/mathc.exe gate --no-execute --gaps-limit 3 main HEAD | jq -c '{within_cap: ((.gaps | length) <= 3)}'
  {"within_cap":true}

`--gaps-limit 0` means "print them all" -- the escape hatch for a
reader that needs every gap.

  $ $INSIDE_DUNE/bin/mathc.exe gate --no-execute --gaps-limit 0 main HEAD | jq -c '{whole_set: (.gaps_total == (.gaps | length))}'
  {"whole_set":true}
