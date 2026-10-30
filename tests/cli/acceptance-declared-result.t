An acceptance item names a check. It does not state the check's
outcome: the outcome is measured by running the check, and it is
recorded in the attestation store.

The corpus carried 863 `result:` keys -- every one of them `pass` --
and no verdict ever consulted them. They were decoration that reads
like evidence: a reader opening a decision file saw "pass" next to a
promise and could not tell that no check had run. The constitution's
separation is `declared != derived != attested != reviewed !=
observed`, and a declared outcome in the promise's own file is a
DECLARED result standing where an ATTESTED one belongs.

So the key is gone from the schema and from the corpus, and a file
that still carries one is reported: MC-ACCEPTANCE-DECLARED-RESULT.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ cat > declared-result.yaml <<'EOF'
  > ---
  > schema: math-coding/3.3
  > id: declared-result-demo
  > revision: 1
  > state: active
  > intent: |
  >   An acceptance item that declares its own outcome.
  > commitment: |
  >   Nothing here is checked.
  > axiom_link:
  >   - A0
  > counterexample: |
  >   A `result: pass` in the promise's own file is a claim that a
  >   check ran and passed. Nothing ran.
  > scope:
  >   paths:
  >     - "lib/**"
  > outcomes:
  >   - id: none
  >     statement: |
  >       Nothing is checked here.
  > obligations:
  >   - id: ob1
  >     outcome: none
  >     claim: |
  >       A claim.
  >     acceptance:
  >       all:
  >         - verifier: file-exists lib
  >           result: pass
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json declared-result.yaml | jq -c '[.verdict, (.diagnostics // [] | map(.code))]'
  [block] input/MC-ACCEPTANCE-DECLARED-RESULT: obligation ob1: acceptance item (all[0]) declares a `result:`. The outcome of a check is measured, not declared: remove the key, and let the check write its verdict into the attestation store.
  ["parse-ok",["MC-ACCEPTANCE-DECLARED-RESULT"]]

The same file without the key parses clean: the item names the
check, and nothing claims its outcome.

  $ sed -i '/result: pass/d' declared-result.yaml
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json declared-result.yaml | jq -c '[.verdict, (.diagnostics // [] | map(.code))]'
  ["parse-ok",[]]
