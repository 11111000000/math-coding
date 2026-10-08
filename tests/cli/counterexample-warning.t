mathc validate emits an MC-COUNTEREXAMPLE-MISSING Warn diagnostic
when a decision lacks the `counterexample` field AND the
decision's `mode` is in {tiny, light}. Counterexample is a
dialectical slot — when absent at tiny/light modes, the
diagnostic is a Warn and the verdict stays `accept`. (For
modes >= standard an empty counterexample is a Block; the
T6.2 cram test `tests/cli/validate-counterexample-required.t`
covers that separate rule.)

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cd "$tmp"

A `mode: light` decision with counterexample: no warning,
plain accept.

  $ cat > has-counterexample.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: has-counterexample-demo
  > revision: 1
  > state: active
  > mode: light
  > axiom_link:
  >   - A0
  > intent: |
  >   A test with counterexample present.
  > commitment: |
  >   The author named the strongest objection.
  > counterexample: |
  >   The strongest objection is that this change might break
  >   the kernel, but the test demonstrates it does not.
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
  $ mathc validate --format=json has-counterexample.yaml | jq -c '[.verdict, (.diagnostics // [] | map(.code))]'
  ["accept",[]]

A `mode: light` decision without counterexample: warning
emitted, verdict still accept (dialectical slot, not a hard
requirement at light mode).

  $ cat > no-counterexample.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: no-counterexample-demo
  > revision: 1
  > state: active
  > mode: light
  > axiom_link:
  >   - A0
  > intent: |
  >   A test with no counterexample.
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
  $ mathc validate --format=json no-counterexample.yaml | jq -c '[.verdict, (.diagnostics // [] | map(.code))]'
  [warn] deficit/MC-COUNTEREXAMPLE-MISSING: missing counterexample: spec/algebra-3.2.md §11 names it as a dialectical slot for modes >= light; add a counterexample section naming the strongest objection (legacy soft warning; the Block path was already rejected before parse)
  ["accept",["MC-COUNTEREXAMPLE-MISSING"]]

JSON form: counterexample as an array of strings (one per
dialectical objection) is also accepted without warning at
`mode: light`.

  $ cat > counterexample-array.json <<EOF
  > {
  >   "schema": "math-coding/3.0-alpha/decision",
  >   "kind": "decision",
  >   "id": "json-counterexample-demo",
  >   "revision": "1",
  >   "state": "active",
  >   "mode": "light",
  >   "axiom_link": ["A0"],
  >   "intent": {"source": "test", "text": "JSON form demo"},
  >   "commitment": "JSON counterexample form.",
  >   "counterexample": ["objection one", "objection two"],
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
  $ mathc validate --format=json counterexample-array.json | jq -c '[.verdict, (.diagnostics // [] | map(.code))]'
  ["accept",[]]

Cleanup:
  $ cd /
  $ rm -rf "$tmp"
