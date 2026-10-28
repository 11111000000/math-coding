mathc gate --no-scope --no-execute BASE HEAD -- the AUDIT question: every
active decision, read from the attestation store, with no verifier run.
With a populated attestation store covering all applicable obligations it
emits verdict "pass", gaps `[]`, and exits 0.
Acceptance gate for obligation gate-attestation-store-implemented
and gate-real-verdict (positive case) in
bootstrap/gate-attestation-store-fill-decision.yaml.

The store (tests/fixtures/gate-pass/attestations) holds ten pass
attestations covering two decisions — `kernel-conformance-runner`
(four obligations) and `validate-and-context` (six). Those two
decisions are authored into a temp project so that the store
covers *every* applicable obligation: with the full repository
decision set the same store leaves hundreds of obligations
uncovered and the honest verdict is `unknown` (gate-empty.t and
gate-fail.t cover those shapes). Authoring the covered decisions
here is what makes the positive case reachable without asserting a
count that drifts every time `decisions/*.yaml` grows.

The switches are spelled out because the default moved: `mathc gate` now
asks the change's question and runs the checks unless it is told
otherwise. This fixture asks the AUDIT question -- the whole corpus,
read from the store -- and says so on the command line.
`--no-execute` is also the only safe thing to write inside a cram
fixture: a verifier that runs `dune runtest` inside a `dune runtest`
recurses, and the recursion ends in a timeout rather than a verdict.

The control run at the end re-runs the identical gate against an
absent store and asserts it degrades to `unknown` / exit 3, so the
`pass` above cannot be vacuously produced by an empty obligation
set.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ cat > dune-project <<'EOF'
  > (lang dune 3.21)
  > (cram enable)
  > EOF
  $ git init -q
  $ git config user.email "t@t"
  $ git config user.name "t"
  $ echo a > a.txt
  $ git add . && git commit -q -m initial
  $ echo b > b.txt
  $ git add . && git commit -q -m second
  $ mkdir -p decisions
  $ cat > decisions/kernel-conformance-runner.yaml <<'YAML'
  > schema: math-coding/3.0-alpha
  > id: kernel-conformance-runner
  > revision: 2
  > state: active
  > mode: light
  > axiom_link:
  >   - A1
  > intent: |
  >   Fixture decision whose four obligations are all attested by
  >   tests/fixtures/gate-pass/attestations.
  > commitment: |
  >   The store covers every obligation of this decision.
  > outcomes:
  >   - id: o
  >     statement: s
  > obligations:
  >   - id: enumerate-and-classify-fixtures
  >     claim: A claim.
  >   - id: parse-positive-and-negative-decision
  >     claim: A claim.
  >   - id: wire-conformance-into-dune-test
  >     claim: A claim.
  >   - id: skip-non-decision-fixtures-with-warning
  >     claim: A claim.
  > assumptions: []
  > reversal: []
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > counterexample: |
  >   n/a
  > YAML
  $ cat > decisions/validate-and-context.yaml <<'YAML'
  > schema: math-coding/3.0-alpha
  > id: validate-and-context
  > revision: 3
  > state: active
  > mode: light
  > axiom_link:
  >   - A1
  > intent: |
  >   Fixture decision whose six obligations are all attested by
  >   tests/fixtures/gate-pass/attestations.
  > commitment: |
  >   The store covers every obligation of this decision.
  > outcomes:
  >   - id: o
  >     statement: s
  > obligations:
  >   - id: jsonl-array-parser-fixed
  >     claim: A claim.
  >   - id: cli-context-capsule
  >     claim: A claim.
  >   - id: cli-validate-decision
  >     claim: A claim.
  >   - id: cli-version-preserved
  >     claim: A claim.
  >   - id: kernel-offline-pure-unchanged
  >     claim: A claim.
  >   - id: capsule-byte-budget-tracked
  >     claim: A claim.
  > assumptions: []
  > reversal: []
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > counterexample: |
  >   n/a
  > YAML
  $ git add . && git commit -q -m "fixture decisions"
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$DUNE_SOURCEROOT/tests/fixtures/gate-pass/attestations" bash -c 'mathc gate --no-scope --no-execute HEAD~1 HEAD > /tmp/gate-pass.out; ec=$?; jq -c "del(.now) | {verdict, gaps: (.gaps | length), obligations_positive: (.obligations > 0), every_obligation_attested: ((.gaps | length) == 0)}" < /tmp/gate-pass.out; echo "exit=$ec"'
  {"verdict":"pass","gaps":0,"obligations_positive":true,"every_obligation_attested":true}
  exit=0

Control — same project, store absent: the verdict degrades to
unknown and the exit code becomes 3, so the `pass` above is
earned by the store rather than by an empty obligation set.

  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/does-not-exist" bash -c 'mathc gate --no-scope --no-execute HEAD~1 HEAD > /tmp/gate-pass-empty.out; ec=$?; jq -c "del(.now) | {verdict, all_missing: (.gaps | length > 0 and all(.kind == \"MissingEvidence\"))}" < /tmp/gate-pass-empty.out; echo "exit=$ec"'
  {"verdict":"unknown","all_missing":true}
  exit=3
  $ cd /
  $ rm -rf "$tmp"
