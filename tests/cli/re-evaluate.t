mathc re-evaluate classifies a (DECISION_ID, AXIOM_ID) pair per
algebra 3.2 §17 (T1.2 expansion: 4+1-valued status). Exercises
the rejection paths and the new no-run Incompatible verdict.

For a decision whose verifier is `tests/cli/<name>.t`, calling
`mathc re-evaluate` without an explicit `mathc
re-evaluate-decisions` run MUST return verdict `incompatible`
per obligation (T1.2 A1 closure: a `Compatible` verdict requires
an explicit run). The positive `compatible_after_run` verdict
is asserted in tests/cli/re-evaluate-decisions.t.

Acceptance gate for obligation re-evaluate-subcommand-spec-row
in decisions/3-2-cli-catalog.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc re-evaluate
  mathc re-evaluate: DECISION_ID and AXIOM_ID are required
  [2]
  $ mathc re-evaluate nonexistent A1
  mathc re-evaluate: unknown DECISION_ID nonexistent
  [2]
  $ mathc re-evaluate bootstrap-v3 BOGUS
  mathc re-evaluate: AXIOM_ID must be one of A0..A4 (got BOGUS)
  [2]

T1.2 dual-failure evidence (negative): a decision whose
acceptance verifier is `tests/cli/<name>.t` returns
`incompatible` per obligation when no run has been performed.
3-2-cli-catalog has six such verifiers (`tests/cli/mode.t`,
`tests/cli/rebuttals.t`, `tests/cli/re-evaluate.t`, and their
fixture-pair siblings), so the no-run verdict is `incompatible`.

  $ mathc re-evaluate 3-2-cli-catalog A0 | jq -r '.verdict, .ran'
  incompatible
  false
  $ mathc re-evaluate 3-2-cli-catalog A0 | jq -r '[.obligations[] | select(.verdict == "incompatible")] | length'
  6

T1.2 positive (built-in verifier still `Compatible` without
run): a decision whose only `mathc-`-prefixed verifier maps to
`BuiltIn` and is therefore still `Compatible` even without an
explicit run. `algebra-3.2-notation-flag-2026-10::kernel-unchanged`
is such an obligation (`mathc-self-check-verdict` is a built-in
kernel verifier).

  $ mathc re-evaluate algebra-3.2-notation-flag-2026-10 A0 | jq -r '.obligations[] | select(.id == "kernel-unchanged") | .verdict'
  compatible

T1.2 manual-style verifier still maps to `inconclusive`: the
`notation-note-present` obligation has a non-built-in verifier
(`rg -n '...' spec/algebra-3.2.md`); without a run the verdict
is `inconclusive` (does not block; surfaces follow-up review).

  $ mathc re-evaluate algebra-3.2-notation-flag-2026-10 A0 | jq -r '.obligations[] | select(.id == "notation-note-present") | .verdict'
  inconclusive
