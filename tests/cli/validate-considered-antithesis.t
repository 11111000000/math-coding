mathc validate enforces the new v3-dialectic `antithesis`
slot requirement only for `mode: considered`. Per
spec/algebra-3.2.md §11 and
`decisions/antithesis-mode-considered-2026-10.yaml`,
antithesis is required for `mode = considered`; modes
`standard | strict | exhaustive` (and the absence of mode,
which defaults to standard) do NOT require antithesis. The
parser-level guard changed from `mode_geq_standard` to
`mode_geq_considered` in this decision cycle, so the
existing 60+ decisions at HEAD that previously rejected
with `MC-ANTITHESIS-MISSING` now accept.

  $ cd "$DUNE_SOURCEROOT"

A `mode: considered` decision WITH antithesis is accepted:

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ cat > mode-considered-with-antithesis.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: mode-considered-with-antithesis-demo
  > revision: 1
  > state: active
  > mode: considered
  > axiom_link:
  >   - A0
  > intent: |
  >   A mode=considered decision with antithesis (the new rule applies).
  > commitment: |
  >   The author named the antithesis position they considered and rejected.
  > counterexample: |
  >   If the search-fallback load test under-represents the peak,
  >   simultaneous fallback traffic from all instances may breach
  >   origin capacity even with the circuit breakers in place.
  > antithesis: |
  >   A considered-mode author considered and rejected the position
  >   that the rule should be relaxed to a soft warning at every mode;
  >   the chosen direction keeps the strict Block-only path.
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
  $ mathc validate --format=json mode-considered-with-antithesis.yaml | jq -c '{verdict, code}'
  {"verdict":"accept","code":null}

A `mode: considered` decision WITHOUT antithesis is rejected
with `MC-ANTITHESIS-MISSING` (Block, exit 1):

  $ cat > mode-considered-no-antithesis.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: mode-considered-no-antithesis-demo
  > revision: 1
  > state: active
  > mode: considered
  > axiom_link:
  >   - A0
  > intent: |
  >   A mode=considered decision without antithesis (the rule fires).
  > commitment: |
  >   The author forgot to add antithesis.
  > counterexample: |
  >   Same counterexample as above.
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
  $ mathc validate --format=json mode-considered-no-antithesis.yaml | jq -c '{verdict, code, severity}'
  {"verdict":"reject","code":"MC-ANTITHESIS-MISSING","severity":"block"}

`mode: standard` (and absent-mode) WITHOUT antithesis is
ACCEPTED — the new guard fires only for `Considered`. This
is the regression direction: the prior `mode_geq_standard`
guard rejected these; the new `mode_geq_considered` guard
accepts them. (This is the file shape that produced the 60+
prior failures at HEAD pre-fix.)

  $ cat > mode-standard-no-antithesis.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: mode-standard-no-antithesis-demo
  > revision: 1
  > state: active
  > mode: standard
  > axiom_link:
  >   - A0
  > intent: |
  >   A mode=standard decision without antithesis (NOT required at standard).
  > commitment: |
  >   The dialectic method is opt-in via `mode: considered`.
  > counterexample: |
  >   Counterexample stays required at mode >= standard per algebra §11.
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
  $ mathc validate --format=json mode-standard-no-antithesis.yaml | jq -c '{verdict, code}'
  {"verdict":"accept","code":null}

Whitespace-only antithesis is treated as empty (the
author cannot satisfy the rule with " "):

  $ cat > mode-considered-whitespace-antithesis.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: mode-considered-whitespace-antithesis-demo
  > revision: 1
  > state: active
  > mode: considered
  > axiom_link:
  >   - A0
  > intent: |
  >   A mode=considered decision with whitespace-only antithesis.
  > commitment: |
  >   The author tried to satisfy the rule with " ".
  > counterexample: |
  >   Counterexample present.
  > antithesis: |
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
  $ mathc validate --format=json mode-considered-whitespace-antithesis.yaml | jq -c '{verdict, code}'
  {"verdict":"reject","code":"MC-ANTITHESIS-MISSING"}

Full text-format reject for the new rule embeds the decision
id and the spec reference:

  $ mathc validate mode-considered-no-antithesis.yaml
  reject: mode-considered-no-antithesis.yaml
    code: MC-ANTITHESIS-MISSING
    severity: block
    message: mode-considered-no-antithesis-demo: decision has mode=considered but empty antithesis: spec/algebra-3.2.md §11 (v3 dialectic method) requires the antithesis dialectical slot for mode = considered; add an antithesis section naming the coherent counter-position the author considered and rejected (distinct from counterexample, which is the strongest objection surfaced to future readers)
  [1]

Cleanup:
  $ cd /
  $ rm -rf "$tmp"