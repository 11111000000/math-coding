mathc validate enforces the schema-level required-ness of the
`counterexample` field for decisions whose `mode` is >=
`standard`. Per spec/algebra-3.2.md §11 and
`decisions/plan-2026-10-improvements/t6-2.yaml`, an active
decision with `mode` in `{standard, strict, exhaustive}` MUST
carry a non-empty `counterexample`. When the rule fires, the
verdict is `reject` (exit 1) with the diagnostic
`MC-COUNTEREXAMPLE-MISSING` (Block severity, `Deficit` kind,
`policy_rule` carrying the spec reference).

Tiny / light modes are exempt: an empty counterexample is a
soft Warn at most and the verdict stays `accept` (the legacy
soft-warning behaviour preserved from the pre-T6.2 kernel).

This is the positive-and-negative contract for the T6.2
acceptance gate. The rule is part of an A3-protected
transition (per `spec/constitution.md` §Self-application and
the A3 separation axiom: a contract change cannot authorize
its own adoption) and requires human review before merge.

  $ cd "$DUNE_SOURCEROOT"

A `mode: standard` decision WITH `counterexample` is accepted:

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ cat > mode-standard-with-counterexample.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: mode-standard-with-counterexample-demo
  > revision: 1
  > state: active
  > mode: standard
  > axiom_link:
  >   - A0
  > intent: |
  >   A mode=standard decision with counterexample (the rule applies).
  > commitment: |
  >   The author named the strongest objection.
  > counterexample: |
  >   If the search-fallback load test under-represents the peak,
  >   simultaneous fallback traffic from all instances may breach
  >   origin capacity even with the circuit breakers in place.
  > scope:
  >   paths: ["lib/**"]
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
  $ mathc validate --format=json mode-standard-with-counterexample.yaml | jq -c '{verdict, code}'
  {"verdict":"accept","code":null}

A `mode: standard` decision WITHOUT counterexample is rejected
with `MC-COUNTEREXAMPLE-MISSING` (Block, exit 1). This is the
new T6.2 rule firing; a default mode (mode absent) ALSO defaults
to `standard` per `lib/codec.ml::parse_mode` and so triggers
the same reject.

  $ cat > mode-standard-no-counterexample.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: mode-standard-no-counterexample-demo
  > revision: 1
  > state: active
  > mode: standard
  > axiom_link:
  >   - A0
  > intent: |
  >   A mode=standard decision without counterexample (the rule fires).
  > commitment: |
  >   The author forgot to add counterexample.
  > scope:
  >   paths: ["lib/**"]
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
  $ mathc validate --format=json mode-standard-no-counterexample.yaml | jq -c '{verdict, code, severity}'
  {"verdict":"reject","code":"MC-COUNTEREXAMPLE-MISSING","severity":"block"}

Default mode (mode absent, which defaults to standard) WITHOUT
counterexample: same reject — the rule's mode-floor check
treats absent as `standard`:

  $ cat > default-mode-no-counterexample.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: default-mode-no-counterexample-demo
  > revision: 1
  > state: active
  > axiom_link:
  >   - A0
  > intent: |
  >   A decision with mode absent (defaults to standard) and no counterexample.
  > commitment: |
  >   The schema default is standard.
  > scope:
  >   paths: ["lib/**"]
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
  $ mathc validate --format=json default-mode-no-counterexample.yaml | jq -c '{verdict, code}'
  {"verdict":"reject","code":"MC-COUNTEREXAMPLE-MISSING"}

Full text-format reject for the new rule embeds the decision
id and the spec reference:

  $ mathc validate mode-standard-no-counterexample.yaml
  reject: mode-standard-no-counterexample.yaml
    code: MC-COUNTEREXAMPLE-MISSING
    severity: block
    message: mode-standard-no-counterexample-demo: decision has mode=standard but empty counterexample: spec/algebra-3.2.md §11 requires the counterexample dialectical slot for modes >= standard; add a counterexample section naming the strongest objection (or downgrade to mode: light if a documented soft slot is appropriate)
  [1]

Whitespace-only counterexample values are treated as empty
(e.g. an author cannot satisfy the rule with a literal " "
placeholder):

  $ cat > mode-standard-whitespace-counterexample.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: mode-standard-whitespace-counterexample-demo
  > revision: 1
  > state: active
  > mode: standard
  > axiom_link:
  >   - A0
  > intent: |
  >   A mode=standard decision with whitespace-only counterexample.
  > commitment: |
  >   The author tried to satisfy the rule with " ".
  > counterexample: |
  >   
  > scope:
  >   paths: ["lib/**"]
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
  $ mathc validate --format=json mode-standard-whitespace-counterexample.yaml | jq -c '{verdict, code}'
  {"verdict":"reject","code":"MC-COUNTEREXAMPLE-MISSING"}

JSON form: counterexample as an array of strings (one per
dialectical objection). An EMPTY array is treated as no
counterexample and fires the Block rule at mode >= standard;
an array with at least one non-empty entry satisfies the rule.

  $ cat > mode-standard-empty-array.json <<EOF
  > {
  >   "schema": "math-coding/3.0-alpha/decision",
  >   "kind": "decision",
  >   "id": "mode-standard-empty-array-demo",
  >   "revision": "1",
  >   "state": "active",
  >   "mode": "standard",
  >   "axiom_link": ["A0"],
  >   "intent": {"source": "test", "text": "mode=standard with empty array counterexample"},
  >   "commitment": "Empty array is treated as no counterexample.",
  >   "counterexample": [],
  >   "scope": [{"kind": "path", "path": "lib/**"}],
  >   "outcomes": [{"id": "o", "statement": "s"}],
  >   "obligations": [
  >     {
  >       "id": "ob1",
  >       "claim": "A claim.",
  >       "acceptance": {"all": [{"verifier": "tests/conformance.exe", "result": "pass"}]}
  >     }
  >   ],
  >   "risk": {"declared_triggers": [], "owner": "human:maintainer"}
  > }
  > EOF
  $ mathc validate --format=json mode-standard-empty-array.json | jq -c '{verdict, code}'
  {"verdict":"reject","code":"MC-COUNTEREXAMPLE-MISSING"}

  $ cat > mode-strict-with-counterexample.json <<EOF
  > {
  >   "schema": "math-coding/3.0-alpha/decision",
  >   "kind": "decision",
  >   "id": "mode-strict-with-counterexample-demo",
  >   "revision": "1",
  >   "state": "active",
  >   "mode": "strict",
  >   "axiom_link": ["A0"],
  >   "intent": {"source": "test", "text": "mode=strict with array counterexample"},
  >   "commitment": "Strict mode also carries the rule.",
  >   "counterexample": ["an objection", "another objection"],
  >   "scope": [{"kind": "path", "path": "lib/**"}],
  >   "outcomes": [{"id": "o", "statement": "s"}],
  >   "obligations": [
  >     {
  >       "id": "ob1",
  >       "claim": "A claim.",
  >       "acceptance": {"all": [{"verifier": "tests/conformance.exe", "result": "pass"}]}
  >     }
  >   ],
  >   "risk": {"declared_triggers": [], "owner": "human:maintainer"}
  > }
  > EOF
  $ mathc validate --format=json mode-strict-with-counterexample.json | jq -c '{verdict, code}'
  {"verdict":"accept","code":null}

A `mode: light` decision WITHOUT counterexample: warns but
accepts (legacy soft-warning behaviour, EXEMPT from the new
rule). The diagnostic is still MC-COUNTEREXAMPLE-MISSING but
the verdict stays `accept`.

  $ cat > mode-light-no-counterexample.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: mode-light-no-counterexample-demo
  > revision: 1
  > state: active
  > mode: light
  > axiom_link:
  >   - A0
  > intent: |
  >   A mode=light decision without counterexample (legacy soft warning).
  > commitment: |
  >   Tiny / light modes are exempt; the diagnostic is Warn.
  > scope:
  >   paths: ["lib/**"]
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
  $ mathc validate --format=json mode-light-no-counterexample.yaml | jq -c '[.verdict, (.diagnostics // [] | map(.code))]'
  [warn] deficit/MC-COUNTEREXAMPLE-MISSING: missing counterexample: spec/algebra-3.2.md §11 names it as a dialectical slot for modes >= light; add a counterexample section naming the strongest objection (legacy soft warning; the Block path was already rejected before parse)
  ["accept",["MC-COUNTEREXAMPLE-MISSING"]]

A `mode: tiny` decision WITHOUT counterexample: also accepts
(tiny modes are exempt). The format below intentionally lets
`jq` see the diagnostic in the accept path:

  $ cat > mode-tiny-no-counterexample.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: mode-tiny-no-counterexample-demo
  > revision: 1
  > state: active
  > mode: tiny
  > axiom_link:
  >   - A0
  > intent: |
  >   A mode=tiny decision without counterexample (legacy soft warning).
  > commitment: |
  >   Tiny / light modes are exempt.
  > scope:
  >   paths: ["lib/**"]
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
  $ mathc validate --format=json mode-tiny-no-counterexample.yaml | jq -c '[.verdict, (.diagnostics // [] | map(.code))]'
  [warn] deficit/MC-COUNTEREXAMPLE-MISSING: missing counterexample: spec/algebra-3.2.md §11 names it as a dialectical slot for modes >= light; add a counterexample section naming the strongest objection (legacy soft warning; the Block path was already rejected before parse)
  ["accept",["MC-COUNTEREXAMPLE-MISSING"]]

`mode: strict` WITHOUT counterexample is also rejected (strict
sits above standard in the mode sum type, so mode >= standard
includes strict):

  $ cat > mode-strict-no-counterexample.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: mode-strict-no-counterexample-demo
  > revision: 1
  > state: active
  > mode: strict
  > axiom_link:
  >   - A0
  > intent: |
  >   A mode=strict decision without counterexample.
  > commitment: |
  >   Strict is also >= standard.
  > scope:
  >   paths: ["lib/**"]
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
  $ mathc validate --format=json mode-strict-no-counterexample.yaml | jq -c '{verdict, code, severity}'
  {"verdict":"reject","code":"MC-COUNTEREXAMPLE-MISSING","severity":"block"}

`mode: exhaustive` WITHOUT counterexample: same reject:

  $ cat > mode-exhaustive-no-counterexample.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: mode-exhaustive-no-counterexample-demo
  > revision: 1
  > state: active
  > mode: exhaustive
  > axiom_link:
  >   - A0
  > intent: |
  >   A mode=exhaustive decision without counterexample.
  > commitment: |
  >   Exhaustive is the top of the floor.
  > scope:
  >   paths: ["lib/**"]
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
  $ mathc validate --format=json mode-exhaustive-no-counterexample.yaml | jq -c '{verdict, code, severity}'
  {"verdict":"reject","code":"MC-COUNTEREXAMPLE-MISSING","severity":"block"}

The diagnostic is reachable via `mathc explain-diagnostic` so
authors can look up the remediation step (note: the explanation
includes both the soft Warn and the hard Block paths because
the rule is mode-conditional):

  $ mathc explain-diagnostic MC-COUNTEREXAMPLE-MISSING | jq -r '.remediation' | head -10
  Add a `counterexample: |` block with one or two
  sentences naming the strongest objection to the
  decision. Re-run `mathc validate`. For mode >=
  standard an absent counterexample is a blocker; a
  quick fix is to drop the decision to `mode: light`,
  but the long-term fix is to record the strongest
  objection.

Cleanup:
  $ cd /
  $ rm -rf "$tmp"
