mathc validate emits an MC-COUNTEREXAMPLE-MISSING Warn diagnostic
when a decision lacks the `counterexample` field. This closes the
gap between spec/algebra-3.2.md §11 (counterexample required for
modes >= light) and the kernel's prior behaviour of silently
ignoring the field. The verdict remains `accept` — counterexample
is a dialectical slot, not a hard requirement, so legacy
decisions without it stay valid. The diagnostic is one surfaced
next-step, not a reject.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cd "$tmp"

A decision with counterexample: no warning, plain accept.

  $ cat > has-counterexample.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: has-counterexample-demo
  > revision: 1
  > state: active
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

A decision without counterexample: warning emitted, verdict still
accept (dialectical slot, not a hard requirement).

  $ cat > no-counterexample.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: no-counterexample-demo
  > revision: 1
  > state: active
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
  [warn] input/MC-COUNTEREXAMPLE-MISSING: missing counterexample: spec/algebra-3.2.md §11 requires it for modes >= light; add a counterexample section naming the strongest objection
  ["accept",["MC-COUNTEREXAMPLE-MISSING"]]

JSON form: counterexample as an array of strings (one per
dialectical objection) is also accepted without warning.

  $ cat > counterexample-array.json <<EOF
  > {
  >   "schema": "math-coding/3.0-alpha/decision",
  >   "kind": "decision",
  >   "id": "json-counterexample-demo",
  >   "revision": "1",
  >   "state": "active",
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
