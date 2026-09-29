mc gate BASE HEAD exits 0 and prints a JSON object containing
at minimum the keys "verdict", "gaps", "obligations", "now",
"base", "head". The verdict is "unknown" or "pass" (never "pass"
without an attestation store; see bootstrap/gate-decision.yaml
outcome gate-stub-honest). The fixture pins the JSON contract;
future revisions under obligation gate-attestation-store-fill
extend the body without renaming keys. `now` is scrubbed
(non-deterministic). The `gaps` array is large and depends on
obligation state; this test asserts the contract keys rather than
gap contents. Acceptance gate for obligation gate-stub-honest
in bootstrap/gate-decision.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc gate main HEAD | jq -c 'keys'
  ["base","gaps","head","now","obligations","verdict"]
