mathc context with --budget 100000 (~100 KiB) fits everything; the
capsule reports truncated=false and total_bytes <= 100000.
Per spec/semantics.md "context-prioritisation": the `truncated`
flag MUST be `true` iff the `omitted` array is non-empty.
This test pins the inequality total_bytes <= budget. The `now`
field is scrubbed (non-deterministic). Acceptance gate for
obligation context-capsule-budget-bound in
bootstrap/validate-and-context.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc context main HEAD --budget 100000 | jq -c '{truncated, total_bytes, omitted: (.omitted | length)}'
  {"truncated":false,"total_bytes":9530,"omitted":0}
