mc validate exits 0 on a decision whose acceptance carries both
verifier and review: the kernel accepts the verifier half and emits
the MC-AMBIGUOUS-ACCEPTANCE diagnostic on stderr naming the
obligation id. This pins the silent-drop fix recorded against
obligation parse-ambiguous-acceptance in
bootstrap/parse-acceptance-diagnostics.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc validate fixtures/conformance/decision/positive-ambiguous-acceptance.json
  [warn] conflict/MC-AMBIGUOUS-ACCEPTANCE: obligation obligation-with-ambiguous-acceptance: acceptance item carries both verifier and review (all[0]); verifier wins, review is dropped
  accept: fixtures/conformance/decision/positive-ambiguous-acceptance.json
    decision: ambiguous-acceptance-demo
    revision: rev:7f3a
    obligations: 1
    assumptions: 1
