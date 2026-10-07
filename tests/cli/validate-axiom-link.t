mathc validate emits diagnostic `MC-AXIOM-LINK-MISSING` (severity:
`block`) for a `state: active` decision with empty `axiom_link`,
and the verdict is `reject` (exit 1). This is the T2.2 acceptance
gate: the schema-level required-ness of `axiom_link` for active
decisions is enforced by the parser
(`lib/decision.ml::parse_decision`) and surfaced by the CLI
(`bin/Mathc.ml::validate_with_counts::axiom_link_violation`).

Draft, Retired, and Superseded decisions are exempt — only
`active` carries the contract. The diagnostic message names the
decision id when present and points at
`spec/algebra-3.2.md §7`.

  $ cd "$DUNE_SOURCEROOT"

A `state: active` decision without `axiom_link` is rejected with
the specific `MC-AXIOM-LINK-MISSING` diagnostic:

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ cat > active-no-axiom-link.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: active-no-axiom-link-demo
  > revision: 1
  > state: active
  > intent: |
  >   A test with no axiom_link and state=active.
  > commitment: |
  >   The author forgot axiom_link.
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
  $ mathc validate --format=json active-no-axiom-link.yaml | jq -c '{verdict, code, severity, message}'
  {"verdict":"reject","code":"MC-AXIOM-LINK-MISSING","severity":"block","message":"active-no-axiom-link-demo: decision has state=active but empty axiom_link: spec/algebra-3.2.md §7 requires every active decision to name the axiom(s) it addresses via the axiom_link field; add one (e.g. axiom_link: [A0]) to the decision front-matter"}

A decision with `axiom_link: [A0]` and `state: active` is accepted
(the rule is accepted; non-empty axiom_link is the fix):

  $ cat > active-with-axiom-link.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: active-with-axiom-link-demo
  > revision: 1
  > state: active
  > axiom_link:
  >   - A0
  > intent: |
  >   A test with axiom_link and state=active.
  > commitment: |
  >   The author names axiom_link.
  > counterexample: |
  >   The strongest objection is irrelevant for this demo.
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
  $ mathc validate --format=json active-with-axiom-link.yaml | jq -c '{verdict, code}'
  {"verdict":"accept","code":null}

A `state: draft` decision without `axiom_link` is accepted (draft
is exempt from the contract):

  $ cat > draft-no-axiom-link.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: draft-no-axiom-link-demo
  > revision: 1
  > state: draft
  > intent: |
  >   A draft without axiom_link (allowed).
  > commitment: |
  >   Drafts don't carry the axiom_link contract yet.
  > counterexample: |
  >   The strongest objection is irrelevant for this demo.
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
  $ mathc validate --format=json draft-no-axiom-link.yaml | jq -c '{verdict, code}'
  {"verdict":"accept","code":null}

A `state: retired` decision without `axiom_link` is accepted
(retired is exempt from the contract):

  $ cat > retired-no-axiom-link.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: retired-no-axiom-link-demo
  > revision: 1
  > state: retired
  > intent: |
  >   A retired decision without axiom_link (allowed).
  > commitment: |
  >   Retired decisions are historical records, not enforced.
  > counterexample: |
  >   Historical record only.
  > scope:
  >   paths: ["lib/**"]
  > outcomes:
  >   - id: o
  >     statement: s
  > obligations: []
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ mathc validate --format=json retired-no-axiom-link.yaml | jq -c '{verdict, code}'
  {"verdict":"accept","code":null}

A decision with `state` absent (default `active`) and no
`axiom_link` is rejected — the schema default for `state` is
`active`, so the contract applies:

  $ cat > default-state-no-axiom-link.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: default-state-no-axiom-link-demo
  > revision: 1
  > intent: |
  >   A decision with no state field (defaults to active).
  > commitment: |
  >   The schema default is active.
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
  $ mathc validate --format=json default-state-no-axiom-link.yaml | jq -c '{verdict, code}'
  {"verdict":"reject","code":"MC-AXIOM-LINK-MISSING"}

The diagnostic helper is also reachable via `mathc explain-diagnostic`
so authors can look up the remediation step:

  $ mathc explain-diagnostic MC-AXIOM-LINK-MISSING | jq -r '.remediation'
  Add `axiom_link: [A<n>]` to the decision front-matter,
  listing the axiom(s) the decision addresses. If the
  decision is a transitional draft that should not be
  evaluated yet, change its state to `draft` instead.
  Re-run `mathc validate`.

Cleanup:
  $ cd /
  $ rm -rf "$tmp"
