mathc validate exits 0 on a decision whose acceptance item carries an
unparseable verifier, emits the MC-MALFORMED-ACCEPTANCE diagnostic
on stderr naming the obligation id, and still prints the parse-ok
verdict. The acceptance list is one shorter (Domain.All []) but the
decision itself parses. This is the acceptance gate for
obligation parse-malformed-acceptance in
bootstrap/parse-acceptance-diagnostics.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ $INSIDE_DUNE/bin/mathc.exe validate fixtures/conformance/decision/positive-malformed-acceptance.json
  [warn] input/MC-MALFORMED-ACCEPTANCE: obligation malformed-obligation: acceptance item (all[0]) is malformed: verifier or review present but unparseable
  parse-ok: fixtures/conformance/decision/positive-malformed-acceptance.json
    decision: malformed-acceptance-demo
    revision: rev:8c4b
    obligations: 1
    assumptions: 1
