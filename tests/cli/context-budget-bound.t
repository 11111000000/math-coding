mathc context never exceeds its budget, and it says so when it
does not fit.
Per spec/semantics.md "context-prioritisation": the `truncated`
flag MUST be `true` iff the `omitted` array is non-empty. The
inequality total_bytes <= budget is the load-bearing claim. The
`now` field is scrubbed (non-deterministic). Acceptance gate for
obligation context-capsule-budget-bound in
bootstrap/validate-and-context.yaml.

WHAT IS NOT PINNED, AND WHY. This fixture used to assert
`truncated=false, omitted=0` at a budget of 100000 bytes. That
assertion is a statement about the SIZE OF THE CORPUS, not about the
capsule: the capsule is the decision texts, the corpus grows, and on
2026-10-26 the honest re-signing plus one more decision pushed it
past 100 KiB and the assertion broke.

A fixture that pins the size of the corpus breaks whenever the corpus
advances, and a fixture that breaks whenever the project advances
teaches people to ignore it. What the kernel owes here is the
INEQUALITY and the CONSISTENCY of the report, and both are asserted
below against whatever the corpus currently is.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc context main HEAD --budget 100000 | jq -c '{truncated, under_budget: (.total_bytes <= 100000), total_bytes, omitted: (.omitted | length)}' | sed 's/"total_bytes":[0-9]*/"total_bytes":"<N>"/' | sed 's/"omitted":[0-9]*/"omitted":"<N>"/'
  {"truncated":true,"under_budget":true,"total_bytes":"<N>","omitted":"<N>"}

The inequality holds at a budget that cannot fit the corpus.

  $ mathc context main HEAD --budget 100000 | jq -e '.total_bytes <= 100000' > /dev/null && echo "the capsule respects its budget"
  the capsule respects its budget

`truncated` is true if and only if something was omitted: the flag
is the report of the omission list, not a second opinion about it.

  $ mathc context main HEAD --budget 100000 | jq -e '(.truncated == ((.omitted | length) > 0))' > /dev/null && echo "truncated agrees with the omitted list"
  truncated agrees with the omitted list

A budget large enough for the whole corpus omits nothing, and says
so.

  $ mathc context main HEAD --budget 1000000 | jq -c '{truncated, under_budget: (.total_bytes <= 1000000), omitted: (.omitted | length)}'
  {"truncated":false,"under_budget":true,"omitted":0}
