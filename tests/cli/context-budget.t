mc context with --budget 100000 produces a JSON capsule whose
top-level object carries the documented keys (base, change,
decisions, obligations, head, items, omitted, total_bytes,
truncated). The `now` field is non-deterministic and the absolute
total_bytes value drifts as the project gains files (each new
spec/axiom/decision file adds to the budget). The fixture asserts
the shape — keys present, types correct, truncated iff omitted
non-empty — rather than a byte-exact snapshot. Acceptance gate
for obligation cli-context-decision in
bootstrap/validate-and-context.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc context main HEAD --budget 100000 > /tmp/cb.json
  $ jq -e 'has("base") and has("change") and has("decisions") and has("obligations") and has("head") and has("items") and has("omitted") and has("total_bytes") and has("truncated") and has("now")' /tmp/cb.json
  true
  $ jq -e '(.total_bytes | type == "number") and (.total_bytes > 0) and (.truncated | type == "boolean") and (.omitted | type == "array") and (.items | type == "array")' /tmp/cb.json
  true
  $ jq -e '.truncated == (.omitted | length > 0)' /tmp/cb.json
  true
  $ rm -f /tmp/cb.json
