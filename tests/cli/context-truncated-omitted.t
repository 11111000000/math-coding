mathc context with --budget 200 forces truncation: the capsule
reports truncated=true, omitted[] is non-empty, and every omitted
item carries an `expansion` field (an `mathc explain ...` command so
an LLM agent can fetch the missing context on demand). Per
spec/semantics.md "context-prioritisation": when the budget is
exhausted, items are dropped in reverse priority order, and the
dropped items appear in the JSON `omitted` array with an
`expansion` command.
Acceptance gate for obligation context-capsule-truncated in
bootstrap/validate-and-context.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc context main HEAD --budget 200 | jq -c '{truncated, omitted_count_gt_0: (.omitted | length > 0), all_have_expansion: ([.omitted[].expansion] | all(. != null))}'
  {"truncated":true,"omitted_count_gt_0":true,"all_have_expansion":true}
