The top-level items[] array is priority-ordered:
RequiredForGate < Changed < HighRisk < Unresolved < Supporting <
Historical. Per spec/semantics.md "context-prioritisation": the
order is normative; an agent MUST NOT silently reorder or rebucket
items.
This test asserts that the rank sequence is monotonically
non-decreasing. jq ranks each priority and verifies the result is
already sorted. Acceptance gate for obligation
context-capsule-priority-order in bootstrap/validate-and-context.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc context main HEAD --budget 100000 | jq -c '[.items[].priority] as $ps | [$ps[] | if . == "RequiredForGate" then 0 elif . == "Changed" then 1 elif . == "HighRisk" then 2 elif . == "Unresolved" then 3 elif . == "Supporting" then 4 elif . == "Historical" then 5 else -1 end] | {sorted: (. == (. | sort)), all_known: (all(. >= 0))}'
  {"sorted":true,"all_known":true}
