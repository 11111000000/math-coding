Hermetic version of the `MC-COUNTEREXAMPLE-MISSING` rule pin
(see `tests/cli/validate-counterexample-required.t` for the broader
suite). The rule is: a decision with `mode >= standard` (or absent
mode, which defaults to standard per `lib/codec.ml::parse_mode`)
that has an empty `counterexample:` field is rejected with the
diagnostic `MC-COUNTEREXAMPLE-MISSING` -- NOT `MC-MISSING-INTENT`.

The pre-fix kernel tripped `MC-MISSING-INTENT` because the
`counterexample_violation` pre-check fired AFTER `parse_decision_yaml`
returned None (per PLAN.md §3.2; A3-protected transition recorded
in `decisions/kernel-bugs-v3.4-2026-10.yaml`). The post-fix kernel
fires the pre-check FIRST so the user gets the more accurate
diagnostic. This test is the focused, hermetic pin for that
ordering contract -- one fixture, two branches (counterexample
present vs absent), and the absence branch asserts the rejection
code is the dialectic one, not the generic intent one.

The fixture is built inside a fresh tmpdir using here-doc with a
heredoc-with-comment line per `tests/cli/validate-counterexample-required.t`
style; the JSON form keeps the shape concise. We use the same
v3.0-alpha schema as that broader suite for parity.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ cd "$tmpdir"

Positive case: decision with `counterexample` present must accept.

  $ cat > ok.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: counterexample-required-ok
  > revision: 1
  > state: active
  > mode: standard
  > axiom_link:
  >   - A0
  > intent: |
  >   Decision with a counterexample present.
  > commitment: |
  >   The author named the strongest objection.
  > counterexample: |
  >   Adopting math-coding is overhead for projects where one developer
  >   works alone with no AI assistance. This fails because the
  >   protocol's applicability envelope names those projects as Path B.
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
  >         - verifier: $INSIDE_DUNE/bin/mathc.exe self-check
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json ok.yaml | jq -c '{verdict, code}'
  {"verdict":"parse-ok","code":null}

Negative case: decision WITHOUT `counterexample:` must reject
with `MC-COUNTEREXAMPLE-MISSING`. The pre-fix kernel returned
`MC-MISSING-INTENT` (per PLAN.md §3.2). The post-fix kernel
fires the counterexample pre-check BEFORE the intent check, so the
diagnostic is the dialectic one. The fixture MUST NOT contain
`counterexample:` anywhere -- even a one-character placeholder.

  $ cat > missing-cx.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: counterexample-required-missing
  > revision: 1
  > state: active
  > mode: standard
  > axiom_link:
  >   - A0
  > intent: |
  >   Decision without counterexample (the rule should fire).
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
  >         - verifier: $INSIDE_DUNE/bin/mathc.exe self-check
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json missing-cx.yaml | jq -c '{verdict, code, severity}'
  {"verdict":"reject","code":"MC-COUNTEREXAMPLE-MISSING","severity":"block"}

Default mode (mode absent, which `lib/codec.ml::parse_mode`
defaults to `standard`) WITHOUT counterexample: same reject.
This is the regression pin for the mode-floor check that
treats absent as standard (per `decisions/kernel-bugs-v3.4-2026-10.yaml`).

  $ cat > default-mode-missing.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: counterexample-required-default-mode
  > revision: 1
  > state: active
  > axiom_link:
  >   - A0
  > intent: |
  >   Default-mode decision without counterexample (mode absent -> standard).
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
  >         - verifier: $INSIDE_DUNE/bin/mathc.exe self-check
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json default-mode-missing.yaml | jq -c '{verdict, code}'
  {"verdict":"reject","code":"MC-COUNTEREXAMPLE-MISSING"}

The diagnostic is reachable via `mathc explain-diagnostic` and the
remediation text is not blank. This catches a regression where the
diagnostic was added to the dispatcher but not to the registry.

  $ cd "$DUNE_SOURCEROOT"
  $ $INSIDE_DUNE/bin/mathc.exe explain-diagnostic MC-COUNTEREXAMPLE-MISSING | jq -r '.remediation' | head -3
  Add a `counterexample: |` block with one or two
  sentences naming the strongest objection to the
  decision. Re-run `mathc validate`. For mode >=

Cleanup.

  $ rm -rf "$tmpdir"
