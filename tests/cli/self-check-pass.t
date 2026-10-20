mathc self-check with a populated attestation store that does not
yet cover the whole corpus emits verdict "unknown" and exits 3.
The fixture store at tests/fixtures/self-check-pass/attestations
holds one pass attestation per (decision_id, obligation_id) pair
for the decisions it covers (see fixture commit); every covered
subject reports pass, the rest report unknown, and the aggregate
refuses to certify the uncovered remainder. The dispatcher walks
the full decisions directory via Sys.readdir (no hardcoded file
list) per ROADMAP P1, so the subject count moves with
`decisions/*.yaml` — this fixture asserts the invariants, not a
count. Acceptance gate for obligation mathc-self-check-dispatcher-shipped
(positive case) in decisions/mathc-self-check-subcommand.yaml@2.

  $ cd "$DUNE_SOURCEROOT"
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_ATTESTATION_STORE="$DUNE_SOURCEROOT/tests/fixtures/self-check-pass/attestations" mathc self-check | jq -c '{verdict, store_read: ([.subjects[] | select(.verdict == "pass")] | length > 0), uncovered_unknown: ([.subjects[] | select(.verdict == "unknown")] | length > 0), fail_count: ([.subjects[] | select(.verdict == "fail")] | length), all_subjects_classified: (([.subjects[].verdict] | map(select(. == "pass" or . == "fail" or . == "unknown")) | length) == (.subjects | length)), kernel_digest_len: (.kernel_digest | length), repo_digest_len: (.repository_digest | length)}'
  {"verdict":"unknown","store_read":true,"uncovered_unknown":true,"fail_count":0,"all_subjects_classified":true,"kernel_digest_len":64,"repo_digest_len":64}
