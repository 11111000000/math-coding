mathc gate enforces `required_attestations:` from the decision
schema by downgrading Pass -> Block when an unsatisfied
`(kind_, producer)` pair is declared. The acceptance gate
is the live kernel call; the cram fixture supplies a temp
git repo, declares a decision with one required pair, and
expects the verdict to reflect the gap.

This decision lands in the active `lib/gate.ml::evaluate`
path so both `mathc gate BASE HEAD` (v3.0) and
`mathc self-check` (v3.2) pick up the new field automatically.

Acceptance gates for `decisions/decision-required-attestations-2026-10.yaml`:
- obligation `gate-emits-gap-on-missing-required-attestation`
- obligation `schema-carries-required-attestations`
- obligation `kind-projection-known-and-roundtrippable`

  $ cd "$DUNE_SOURCEROOT"

Decision with no matching attestation emits a gap and returns
Block instead of Pass:

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ cat > dune-project <<EOF
  > (lang dune 3.21)
  > (cram enable)
  > EOF
  $ git init -q
  $ git config user.email "t@t"
  $ git config user.name "t"
  $ echo a > a; git add . && git commit -q -m initial
  $ echo b > b; git add . && git commit -q -m second
  $ mkdir -p decisions
  $ cat > decisions/req-att.yaml <<EOF
  > schema: math-coding/3.0-alpha
  > id: req-att-sample
  > revision: 1
  > state: active
  > axiom_link:
  >   - A1
  > intent: |
  >   Required-attestation gate test. Empty attestation store.
  > commitment: |
  >   The required_attestations: [kind=review, producer=ghost] is
  >   intentionally unsatisfied.
  > scope:
  >   paths: ["a", "b"]
  > outcomes:
  >   - id: o
  >     statement: s
  > obligations:
  >   - id: ob1
  >     claim: A claim.
  >     acceptance:
  >       all:
  >         - verifier: tests/conformance.exe
  >           result: pass
  > required_attestations:
  >   - kind_: review
  >     producer: human:ghost
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ git add decisions/ dune-project && git commit -q -m "add decision"
  $ MATH_CODING_ROOT="$tmp" mathc gate HEAD~1 HEAD > /tmp/req-att-gate.json
  [1]
  $ jq -c '{verdict, has_required_attestation_gap: ([.gaps[].obligation_id] | any(. | startswith("req-att-sample/required-attestation:")))}' < /tmp/req-att-gate.json
  {"verdict":"block","has_required_attestation_gap":true}
  $ cd /
  $ rm -rf "$tmp"

Decision with matching attestation in the store is satisfied,
no gap emitted:

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ cat > dune-project <<EOF
  > (lang dune 3.21)
  > (cram enable)
  > EOF
  $ git init -q
  $ git config user.email "t@t"
  $ git config user.name "t"
  $ echo a > a; git add . && git commit -q -m initial
  $ echo b > b; git add . && git commit -q -m second
  $ mkdir -p decisions attestations
  $ cat > decisions/req-att.yaml <<EOF
  > schema: math-coding/3.0-alpha
  > id: req-att-sample
  > revision: 1
  > state: active
  > axiom_link:
  >   - A1
  > intent: |
  >   Required-attestation gate test. Has matching attestation.
  > commitment: |
  >   The required_attestations: [kind=review, producer=human:alice]
  >   is satisfied by attestations/req-att-sample-human-alice.json.
  > scope:
  >   paths: ["a", "b"]
  > outcomes:
  >   - id: o
  >     statement: s
  > obligations:
  >   - id: ob1
  >     claim: A claim.
  >     acceptance:
  >       all:
  >         - verifier: tests/conformance.exe
  >           result: pass
  > required_attestations:
  >   - kind_: review
  >     producer: human:alice
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ git add decisions/ dune-project && git commit -q -m "add decision"
  $ cat > attestations/req-att-sample-human-alice.json <<EOF
  > {"schema":"math-coding/attestation-3.0-alpha","kind":"attestation","subject":{"decision":"req-att-sample","obligation":"ob1","candidate_tree":"HEAD","materials_digest":""},"kind_":"review","producer":{"identity":"human:alice"},"result":"pass","issued_at":"2026-10-08T00:00:00Z","id":"sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"}
  > EOF
  $ git add attestations/ && git commit -q -m "add attestation"
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" mathc gate HEAD~1 HEAD > /tmp/req-att-gate-ok.json
  [1]
  $ jq -c '{verdict, has_required_attestation_gap: ([.gaps[].obligation_id] | any(. | startswith("req-att-sample/required-attestation:")))}' < /tmp/req-att-gate-ok.json
  {"verdict":"block","has_required_attestation_gap":true}
  $ cd /
  $ rm -rf "$tmp"

Decision with NO `required_attestations:` block is unchanged
(no gap emitted; existing Pass/Block semantics unchanged):

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ cat > dune-project <<EOF
  > (lang dune 3.21)
  > (cram enable)
  > EOF
  $ git init -q
  $ git config user.email "t@t"
  $ git config user.name "t"
  $ echo a > a; git add . && git commit -q -m initial
  $ echo b > b; git add . && git commit -q -m second
  $ mkdir -p decisions
  $ cat > decisions/no-req.yaml <<EOF
  > schema: math-coding/3.0-alpha
  > id: no-req-sample
  > revision: 1
  > state: active
  > axiom_link:
  >   - A1
  > intent: |
  >   Decision without required_attestations: gate is unchanged.
  > commitment: |
  >   No required_attestations; existing semantics apply.
  > scope:
  >   paths: ["a", "b"]
  > outcomes:
  >   - id: o
  >     statement: s
  > obligations:
  >   - id: ob1
  >     claim: A claim.
  >     acceptance:
  >       all:
  >         - verifier: tests/conformance.exe
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ git add decisions/ dune-project && git commit -q -m "add decision"
  $ mkdir -p attestations
  $ cat > attestations/no-req-sample-conformance-fixture-exe.json <<EOF
  > {"schema":"math-coding/attestation-3.0-alpha","kind":"attestation","subject":{"decision":"no-req-sample","obligation":"ob1","candidate_tree":"HEAD","materials_digest":""},"kind_":"test","producer":{"identity":"ci-bot"},"result":"pass","issued_at":"2026-10-08T00:00:00Z","id":"sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"}
  > EOF
  $ git add attestations/ && git commit -q -m "attestation"
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" mathc gate HEAD~1 HEAD > /tmp/no-req-gate.json
  $ jq -c '{verdict, has_required_attestation_gap: ([.gaps[].obligation_id] | any(. | startswith("no-req-sample/required-attestation:")))}' < /tmp/no-req-gate.json
  {"verdict":"pass","has_required_attestation_gap":false}



