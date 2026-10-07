mathc re-evaluate-decisions walks decisions/ via
Re_evaluation.re_evaluate_after_run and emits a post-run JSON
summary plus per-obligation attestations under
`$MATH_CODING_ATTESTATION_STORE/` (T1.2 expansion). The
default store is `attestations/`; the test overrides via
`MATH_CODING_ATTESTATION_STORE` so the running kernel does
not pollute the live attestation store.

Negative paths (input error / invalid axiom id) exercise the
dispatch contract; positive path asserts that a decision whose
verifier is `tests/cli/<name>.t` is now `compatible_after_run`
in the post-run verdict — the same call without the run would
return `incompatible` (asserted in tests/cli/re-evaluate.t).

Acceptance gate for obligation t1-2-re-evaluation-4-valued in
decisions/plan-2026-10-improvements.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc re-evaluate-decisions
  mathc re-evaluate-decisions: AXIOM_ID is required
  [2]
  $ mathc re-evaluate-decisions BOGUS
  mathc re-evaluate-decisions: AXIOM_ID must be one of A0..A4 (got BOGUS)
  [2]

Positive (T1.2 dual-failure evidence): running
`mathc re-evaluate-decisions A0` returns a verdict of
`compatible_after_run` for an obligation whose verifier is
`tests/cli/<name>.t`. We pick `3-2-cli-catalog::mode-subcommand-spec-row`
whose verifier is `tests/cli/mode.t` — pre-T1.2 this would have
been a silent `compatible`, post-T1.2-without-run it would be
`incompatible`, post-T1.2-with-run it is `compatible_after_run`.

  $ tmp=$(mktemp -d)
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_ATTESTATION_STORE="$tmp" mathc re-evaluate-decisions A0 > /tmp/re-eval.out
  $ ec=$?
  $ jq -r '.ran, .axiom' < /tmp/re-eval.out
  true
  A0
  $ jq -r '.decisions[] | select(.id == "3-2-cli-catalog") | .obligations[] | select(.id == "mode-subcommand-spec-row") | .verdict' < /tmp/re-eval.out
  compatible_after_run
  $ ls "$tmp"/t1-2-A0-3-2-cli-catalog-mode-subcommand-spec-row.json > /dev/null
  $ jq -r '.kind_, .result, .re_eval_verdict, .producer.identity' < "$tmp"/t1-2-A0-3-2-cli-catalog-mode-subcommand-spec-row.json
  test
  pass
  compatible_after_run
  ci-bot:re-evaluate-decisions

Negative (T1.2 dual-failure evidence): every decision's verdict
in the post-run summary is one of the four T1.2 values
(`compatible`, `compatible_after_run`, `inconclusive`,
`incompatible`, `stale_claim`); at least one decision must reach
`compatible_after_run` (asserting the post-run oracle works
end-to-end) and the shape of the summary matches the
documented JSON keys (`axiom`, `now`, `ran`, `decisions`).

  $ jq -r '.decisions[].verdict' < /tmp/re-eval.out | sort -u | tr '\n' ',' | sed 's/,$//'
  compatible,compatible_after_run,inconclusive
  $ jq -r 'keys | sort | join(",")' < /tmp/re-eval.out
  axiom,decisions,now,ran
  $ rm -rf "$tmp"
