mc self-check with an attestation store containing at least one
decisive fail attestation emits verdict "fail" and exits 1
(constitution.md Invariant 14 — exit honesty). The fixture
overwrites one attestation in tests/fixtures/self-check-fail/
with result=fail (bootstrap-v3 / preserve-v2); that subject
surfaces as a FailedEvidence gap with one cause. The remaining
21 subjects carry pass attestations, so they stay pass; only
the bootstrap-v3 subject is fail. Acceptance gate for obligation
mc-self-check-dispatcher-shipped (negative case) in
decisions/mc-self-check-subcommand.yaml@2.

  $ cd "$DUNE_SOURCEROOT"
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_ATTESTATION_STORE="$DUNE_SOURCEROOT/tests/fixtures/self-check-fail/attestations" bash -c 'mathc self-check > /tmp/sc-fail.out; ec=$?; jq -c "del(.now) | {verdict, fail_subjects: [.subjects[] | select(.verdict == \"fail\") | .name], fail_causes_present: ([.subjects[] | select(.verdict == \"fail\") | .causes | length > 0] | any)}" < /tmp/sc-fail.out; echo "exit=$ec"'
  {"verdict":"fail","fail_subjects":["bootstrap-v3"],"fail_causes_present":true}
  exit=1
