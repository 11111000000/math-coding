The `MC-COUNTEREXAMPLE-MISSING` diagnostic fires on genuine
absence of the `counterexample` field only. Before the A2
parser fix (`decisions/fix-yaml-parser-2026-10`, commit
3f14b76 — `lib/codec.ml::parse_yaml_pairs` now accepts the
inline-sequence form `key: - foo\n- bar`), the same
diagnostic was a parser-induced false positive: the kernel
silently dropped the `counterexample:` key when
`risk.declared_triggers` was given in the inline form
followed by a `- bar` continuation at the same indent.
This test pins the post-fix behaviour — the diagnostic is a
true positive for absence. (The accompanying parser-shape
test `tests/cli/yaml-parser.t` covers the codec-level fix;
this test is the focused pin for the *diagnostic surface*.)

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cd "$tmp"

Scenario 1 — `counterexample:` present, plain accept.

  $ cat > has-ce.yaml <<'EOF'
  > ---
  > schema: math-coding/3.0-alpha
  > id: has-ce-b2
  > revision: 1
  > state: active
  > mode: light
  > axiom_link:
  >   - A0
  > intent: |
  >   Decision with a counterexample.
  > commitment: |
  >   The author named the strongest objection.
  > counterexample: |
  >   Strongest objection recorded.
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
  $ mathc validate --format=json has-ce.yaml | jq -c '[.verdict, (.diagnostics // [] | map(.code))]'
  ["parse-ok",[]]

Scenario 2 — `counterexample:` absent (genuine absence);
Warn fires at `mode: light`. The verdict stays `accept`
because counterexample is a dialectical slot, not a hard
requirement, at light mode (per spec/algebra-3.2.md §11).

  $ cat > no-ce.yaml <<'EOF'
  > ---
  > schema: math-coding/3.0-alpha
  > id: no-ce-b2
  > revision: 1
  > state: active
  > mode: light
  > axiom_link:
  >   - A0
  > intent: |
  >   Decision without a counterexample.
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
  $ mathc validate --format=json no-ce.yaml | jq -c '[.verdict, (.diagnostics // [] | map(.code))]'
  [warn] deficit/MC-COUNTEREXAMPLE-MISSING: missing counterexample: spec/algebra-3.2.md §11 names it as a dialectical slot for modes >= light; add a counterexample section naming the strongest objection (legacy soft warning; the Block path was already rejected before parse)
  ["parse-ok",["MC-COUNTEREXAMPLE-MISSING"]]

Scenario 3 — `counterexample:` present AFTER inline-sequence
`risk.declared_triggers: - foo` followed by a `- bar`
continuation at the same indent. Pre-A2 the parser dropped
the `counterexample:` key here and the warn fired as a
false positive. Post-A2 the parser keeps the inline sequence
as Array AND the following `counterexample:` block; the warn
does NOT fire. This is the regression pin for the diagnostic
surface.

  $ cat > post-parser-fix.yaml <<'EOF'
  > ---
  > schema: math-coding/3.0-alpha
  > id: post-parser-fix-b2
  > revision: 1
  > state: active
  > mode: light
  > axiom_link:
  >   - A0
  > intent: |
  >   Post-A2 regression fixture for the
  >   MC-COUNTEREXAMPLE-MISSING diagnostic.
  > commitment: |
  >   The parser keeps the counterexample.
  > scope:
  >   paths: ["lib/codec.ml"]
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
  >   declared_triggers: - foo
  >   - bar
  >   owner: human:maintainer
  > counterexample: |
  >   The parser keeps the inline sequence
  >   AND the following counterexample block.
  > EOF
  $ mathc validate --format=json post-parser-fix.yaml | jq -c '[.verdict, (.diagnostics // [] | map(.code))]'
  ["parse-ok",[]]

Scenario 4 — same shape, counterexample absent. The Warn
fires (genuine absence). This is the negative counterpart
of scenario 3 — the diagnostic surfaces a real omission
even in the inline-sequence context.

  $ cat > post-parser-fix-no-ce.yaml <<'EOF'
  > ---
  > schema: math-coding/3.0-alpha
  > id: post-parser-fix-no-ce-b2
  > revision: 1
  > state: active
  > mode: light
  > axiom_link:
  >   - A0
  > intent: |
  >   Counterpart of scenario 3 with the
  >   counterexample deliberately omitted.
  > commitment: |
  >   The author forgot to add a counterexample.
  > scope:
  >   paths: ["lib/codec.ml"]
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
  >   declared_triggers: - foo
  >   - bar
  >   owner: human:maintainer
  > EOF
  $ mathc validate --format=json post-parser-fix-no-ce.yaml | jq -c '[.verdict, (.diagnostics // [] | map(.code))]'
  [warn] deficit/MC-COUNTEREXAMPLE-MISSING: missing counterexample: spec/algebra-3.2.md §11 names it as a dialectical slot for modes >= light; add a counterexample section naming the strongest objection (legacy soft warning; the Block path was already rejected before parse)
  ["parse-ok",["MC-COUNTEREXAMPLE-MISSING"]]

Cleanup.

  $ cd /
  $ rm -rf "$tmp"
