The active policy (bootstrap/decision.yaml, decision_id
"bootstrap-v3") is present in the capsule under the
RequiredForGate priority bucket. Per spec/semantics.md
"context-prioritisation": RequiredForGate | bootstrap/decision.yaml;
the active policy | Always included if present.
The fixture fails when the policy is missing from the capsule,
which is a worse failure than running out of budget: an agent that
does not see the active policy will happily act on stale beliefs.
Acceptance gate for obligation context-capsule-required-for-gate
in bootstrap/validate-and-context.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc context main HEAD --budget 100000 | jq -c '[.items[] | select(.detail_ref == "decision:bootstrap-v3")] | {count: length, priority: (.[0].priority // null)}'
  {"count":1,"priority":"RequiredForGate"}
