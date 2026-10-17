The custom YAML parser used to silently drop the `counterexample:`
key when `risk.declared_triggers` was given in the inline form
`key: - foo` followed by a continuation line `- bar`. The shape
is documented as YAML 1.2 §7.1; the original implementation in
`lib/codec.ml` treated the first item as a string scalar and then
bailed out at the next dash item, dropping every top-level key
that came after.

This test is the focused pin for the kernel fix
(`decisions/fix-yaml-parser-2026-10.yaml`). Each scenario writes
the decision in a fresh tmpdir, runs `mathc validate --format=json`,
and asserts the parsed object contains both `risk.declared_triggers`
as an Array and `counterexample` as a String — and that the
`MC-COUNTEREXAMPLE-MISSING` soft-warn does NOT fire.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ cd "$tmpdir"

Scenario 1 — inline sequence (`key: - foo` + continuation `- bar`)
followed by a `counterexample: |` block. Without the fix this shape
triggers `MC-COUNTEREXAMPLE-MISSING` on a decision that has the
counterexample present.

  $ cat > inline-seq.yaml <<'EOF'
  > ---
  > schema: math-coding/3.0-alpha
  > id: yaml-inline-seq-bug
  > revision: 1
  > state: active
  > mode: light
  > axiom_link:
  >   - A0
  > intent: |
  >   Regression fixture: an inline-sequence
  >   `risk.declared_triggers` followed by a counterexample
  >   block at top level.
  > commitment: |
  >   The parser must keep the counterexample key
  >   visible to the diagnostic.
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
  >   The strongest objection was the parser bug;
  >   the inline form is now accepted.
  > EOF

Diagnostic list is empty; verdict is `accept`.

  $ mathc validate --format=json inline-seq.yaml | jq -c '[.verdict, (.diagnostics // [] | map(.code))]'
  ["accept",[]]

`risk.declared_triggers` is parsed as an Array — not a string.

  $ mathc validate --format=json inline-seq.yaml | jq -c '.decision'
  "yaml-inline-seq-bug"

Scenario 2 — same shape, WITHOUT the counterexample. The
`MC-COUNTEREXAMPLE-MISSING` soft-warn is still expected to fire
(genuine absence, not parser-ignored).

  $ cat > inline-seq-no-ce.yaml <<'EOF'
  > ---
  > schema: math-coding/3.0-alpha
  > id: yaml-inline-seq-no-ce
  > revision: 1
  > state: active
  > mode: light
  > axiom_link:
  >   - A0
  > intent: |
  >   Counterpart of scenario 1 with the
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

Verdict is `accept` (light mode, dialectical slot), but the
soft-warn diagnostic is present.

  $ mathc validate --format=json inline-seq-no-ce.yaml | jq -c '[.verdict, (.diagnostics // [] | map(.code))]'
  [warn] deficit/MC-COUNTEREXAMPLE-MISSING: missing counterexample: spec/algebra-3.2.md §11 names it as a dialectical slot for modes >= light; add a counterexample section naming the strongest objection (legacy soft warning; the Block path was already rejected before parse)
  ["accept",["MC-COUNTEREXAMPLE-MISSING"]]

Scenario 3 — pre-existing indented form (`key:` on its own line,
dashes at deeper indent). Confirms no regression: the inline-seq
patch must not change the existing behaviour.

  $ cat > indented.yaml <<'EOF'
  > ---
  > schema: math-coding/3.0-alpha
  > id: yaml-indented-form
  > revision: 1
  > state: active
  > mode: light
  > axiom_link:
  >   - A0
  > intent: |
  >   The indented form used by every legacy
  >   decision in decisions/*.yaml.
  > commitment: |
  >   The fix is targeted at inline sequence only.
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
  >   declared_triggers:
  >     - foo
  >     - bar
  >   owner: human:maintainer
  > counterexample: |
  >   The indented form already worked before
  >   this fix; this fixture verifies that.
  > EOF

Verdict is `accept`, no diagnostics — same surface as before.

  $ mathc validate --format=json indented.yaml | jq -c '[.verdict, (.diagnostics // [] | map(.code))]'
  ["accept",[]]

Scenario 4 — inline sequence at top level (`items: - first`
followed by `- second`, `- third` on continuation lines). Confirms
the new branch handles a top-level value, not just one nested
under a mapping key.

  $ cat > top-level.yaml <<'EOF'
  > ---
  > schema: math-coding/3.0-alpha
  > id: yaml-top-level-inline-seq
  > revision: 1
  > state: active
  > mode: light
  > axiom_link:
  >   - A0
  > intent: |
  >   Regression for the top-level form.
  > commitment: |
  >   Top-level inline sequences must round-trip
  >   as Array values too.
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
  > items: - first
  > - second
  > - third
  > counterexample: |
  >   Plain-scalar continuation at top level.
  > EOF

Verdict is `accept`, no diagnostics — the top-level inline
sequence is parsed as Array, and `counterexample` is preserved.

  $ mathc validate --format=json top-level.yaml | jq -c '[.verdict, (.diagnostics // [] | map(.code))]'
  ["accept",[]]

Cleanup.

  $ cd /
  $ rm -rf "$tmpdir"
