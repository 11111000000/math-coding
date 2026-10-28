mathc gate --no-execute BASE HEAD -- the MERGE GATE's question: the
decisions this change touches, with no verifier run -- exits 0 and
prints a JSON object containing at minimum the keys "verdict", "gaps",
"obligations", "now", "base", "head". The verdict is "unknown" or
"pass" (never "pass" without an attestation store; see
bootstrap/gate-decision.yaml outcome gate-stub-honest). The fixture
pins the JSON contract; future revisions under obligation
gate-attestation-store-fill extend the body without renaming keys.
`now` is scrubbed (non-deterministic). The `gaps` array is large and
depends on obligation state; this test asserts the contract keys
rather than gap contents. Acceptance gate for obligation
gate-stub-honest in bootstrap/gate-decision.yaml.

The gate's default is now the scoped, executing merge gate. This fixture
asks the MERGE GATE's question -- the decisions this change touches --
and it runs no verifier at all, which is spelled out with
`--no-execute`: a verifier that runs `dune runtest` inside a `dune
runtest` recurses until the test times out. The fixture pins the
document's contract and says nothing about the obligation count, so the
scope does not change the question it asks.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc gate --no-execute main HEAD | jq -c 'keys'
  ["base","gaps","head","now","obligations","verdict"]
