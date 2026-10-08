mathc validate enforces sha-match when both `body_sha` and `yaml_sha`
are recorded on a Decision: if both are present, the two digests
must be string-equal per spec/algebra-3.2.md §7 ("if D.body_sha ≠
∅ ∧ D.yaml_sha ≠ ∅ then D.body_sha = D.yaml_sha"). The check
lives in `lib/decision.ml::sha_match_check` and surfaces in
`bin/Mathc.ml::validate_with_counts` as the `MC-SHA-MISMATCH`
diagnostic (Block severity, exit code 1).

Acceptance gate for the T0.2 obligation `sha-match-enforced` in
`decisions/plan-2026-10-improvements/t0-2.yaml`. This is the
positive-and-negative contract for stream ε's T0.2.

  $ cd "$DUNE_SOURCEROOT"

A decision with both hashes present and EQUAL is accepted (matches
the same sha — the rule is satisfied trivially, no diagnostic
emitted):

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ SAME_SHA="sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  $ cat > sha-match-equal.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: sha-match-equal-demo
  > revision: 1
  > state: active
  > body_sha: "$SAME_SHA"
  > yaml_sha: "$SAME_SHA"
  > axiom_link:
  >   - A0
  > intent: |
  >   A decision with both hashes present and equal.
  > commitment: |
  >   Author recomputed both to the same digest.
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
  $ mathc validate --format=json sha-match-equal.yaml | jq -c '{verdict, code}'
  {"verdict":"accept","code":null}

A decision with both hashes present and DIFFERENT is rejected with
the specific `MC-SHA-MISMATCH` diagnostic (Block, exit 1). The
message embeds both digests verbatim and a policy reference to
spec/algebra-3.2.md §7:

  $ cat > sha-match-mismatch.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: sha-match-mismatch-demo
  > revision: 1
  > state: active
  > body_sha: "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  > yaml_sha: "sha256:fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"
  > axiom_link:
  >   - A0
  > intent: |
  >   A decision whose two digests disagree.
  > commitment: |
  >   The author forgot to recompute yaml_sha after editing the body.
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
  $ mathc validate --format=json sha-match-mismatch.yaml | jq -c '{verdict, code, severity}'
  {"verdict":"reject","code":"MC-SHA-MISMATCH","severity":"block"}

The full text-format reject message embeds both digests and points
at the recompute algorithm (next_actions snippet):

  $ mathc validate sha-match-mismatch.yaml
  reject: sha-match-mismatch.yaml
    code: MC-SHA-MISMATCH
    severity: block
    message: sha-match-mismatch-demo: body_sha (sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef) and yaml_sha (sha256:fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210) disagree: spec/algebra-3.2.md §7 requires both hashes to be equal when both are present. Recompute via the placeholder-substitution algorithm (sha256 of the decision with both fields replaced by 'sha256:' + 64 zeros); see scripts/axiom-link-seed.py:105-123 for the canonical implementation.
  [1]

A decision with ONLY `body_sha` (yaml_sha absent) is accepted —
the invariant is vacuously satisfied when either field is
missing:

  $ cat > sha-match-body-only.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: sha-match-body-only-demo
  > revision: 1
  > state: active
  > body_sha: "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  > axiom_link:
  >   - A0
  > intent: |
  >   A decision with only body_sha.
  > commitment: |
  >   yaml_sha absent is allowed (vacuously true).
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
  $ mathc validate --format=json sha-match-body-only.yaml | jq -c '{verdict, code}'
  {"verdict":"accept","code":null}

A decision with ONLY `yaml_sha` (body_sha absent) is accepted
— same vacuous-truth rule:

  $ cat > sha-match-yaml-only.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: sha-match-yaml-only-demo
  > revision: 1
  > state: active
  > yaml_sha: "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  > axiom_link:
  >   - A0
  > intent: |
  >   A decision with only yaml_sha.
  > commitment: |
  >   body_sha absent is allowed (vacuously true).
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
  $ mathc validate --format=json sha-match-yaml-only.yaml | jq -c '{verdict, code}'
  {"verdict":"accept","code":null}

A decision with NEITHER hash is accepted (no comparison is
possible, vacuous truth):

  $ cat > sha-match-neither.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: sha-match-neither-demo
  > revision: 1
  > state: active
  > axiom_link:
  >   - A0
  > intent: |
  >   A decision with neither hash recorded.
  > commitment: |
  >   Authors may omit both; the rule never fires when both are absent.
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
  $ mathc validate --format=json sha-match-neither.yaml | jq -c '{verdict, code}'
  {"verdict":"accept","code":null}

The diagnostic is reachable via `mathc explain-diagnostic` so
authors can look up remediation:

  $ mathc explain-diagnostic MC-SHA-MISMATCH | jq -c '{code, def_len: (.definition | length), rem_len: (.remediation | length)}'
  {"code":"MC-SHA-MISMATCH","def_len":320,"rem_len":409}

Cleanup:
  $ cd /
  $ rm -rf "$tmp"
