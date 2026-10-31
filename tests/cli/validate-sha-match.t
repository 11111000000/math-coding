mathc validate enforces sha-match when both `body_sha` and `yaml_sha`
are recorded on a Decision. The rule has TWO layers, and the second
is what this fixture is actually about.

Layer 1 (spec/kernel-contract.md §7): if both fields are present they
must be string-equal ("if D.body_sha ≠ ∅ ∧ D.yaml_sha ≠ ∅
then D.body_sha = D.yaml_sha"). Disagreement surfaces as the
`MC-SHA-MISMATCH` diagnostic (Block severity, exit code 1).

Layer 2 (spec/kernel-contract.md §7.1): equality is NECESSARY BUT NOT
SUFFICIENT. A decision's digest is defined over its own file bytes,
so the kernel recomputes it and rejects a stale value with
`MC-SHA-DIGEST-STALE` (Block, exit 1). Both live in
`lib/decision.ml::sha_match_check` and surface through
`bin/Mathc.ml::validate_with_counts`.

Why layer 2 had to exist: until `decisions/enforce-body-sha-digest-2026-10`,
`sha_match_check` compared the two stored fields to EACH OTHER and
never recomputed anything. Any equal pair passed — a fabricated
`sha256:0123...`, or the 64-zero placeholder — so the field that
exists to make a decision tamper-evident was, on its own, decorative:
edit the body and every downstream verdict still read `pass`. The
first case below used to assert exactly that, and its prose said the
rule "is satisfied trivially". That assertion WAS the defect, so it
now asserts the rejection instead, and asserts that `mathc rehash`
(the remediation both diagnostics name) is what makes the file valid.

Acceptance gate for the T0.2 obligation `sha-match-enforced` in
`decisions/plan-2026-10-improvements/t0-2.yaml`. This is the
positive-and-negative contract for stream ε's T0.2.

  $ cd "$DUNE_SOURCEROOT"

A decision with both hashes present and EQUAL, but carrying a
FABRICATED value, is REJECTED (Block, exit 1). The two fields agree,
so layer 1 is satisfied; they are not the digest of this file, so
layer 2 fires. `sha256:0123...` is the honest minimal witness for the
old defect: a well-formed hex digest that was never computed from
anything. The rejection names the file's actual digest, so the
author can see the value the kernel expects:

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
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json sha-match-equal.yaml | jq -c '{verdict, code, severity}'
  {"verdict":"reject","code":"MC-SHA-DIGEST-STALE","severity":"block"}
  $ $INSIDE_DUNE/bin/mathc.exe validate sha-match-equal.yaml 2>&1 | grep -c 'is not the digest of this file'
  1

Remediation is `mathc rehash <file> --write`: it recomputes both
fields from the file's own bytes and verifies the stamped result is
a fixed point before writing. After it, the SAME decision that was
just rejected validates:

  $ $INSIDE_DUNE/bin/mathc.exe rehash sha-match-equal.yaml --write > /dev/null
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json sha-match-equal.yaml | jq -c '{verdict, code}'
  {"verdict":"parse-ok","code":null}

A decision with both hashes present and DIFFERENT is rejected with
the specific `MC-SHA-MISMATCH` diagnostic (Block, exit 1). The
message embeds both digests verbatim and a policy reference to
spec/kernel-contract.md §7.

Note the code, given that BOTH values here are fabricated: layer 1
short-circuits, so the disagreement is reported as MISMATCH and the
recompute never runs. Layer 2 only speaks when layer 1 is silent, and
that ordering is what lets one message say what to fix instead of two
messages describing the same defect.

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
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json sha-match-mismatch.yaml | jq -c '{verdict, code, severity}'
  {"verdict":"reject","code":"MC-SHA-MISMATCH","severity":"block"}

The full text-format reject message embeds both digests and points
at the recompute algorithm (next_actions snippet):

  $ $INSIDE_DUNE/bin/mathc.exe validate sha-match-mismatch.yaml
  reject: sha-match-mismatch.yaml
    code: MC-SHA-MISMATCH
    severity: block
    message: sha-match-mismatch-demo: body_sha (sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef) and yaml_sha (sha256:fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210) disagree: spec/kernel-contract.md §7 requires both hashes to be equal when both are present. Recompute via the placeholder-substitution algorithm (sha256 of the decision with both fields replaced by 'sha256:' + 64 zeros); see scripts/axiom-link-seed.py:133-169 for the reference implementation.
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
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json sha-match-body-only.yaml | jq -c '{verdict, code}'
  {"verdict":"parse-ok","code":null}

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
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json sha-match-yaml-only.yaml | jq -c '{verdict, code}'
  {"verdict":"parse-ok","code":null}

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
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json sha-match-neither.yaml | jq -c '{verdict, code}'
  {"verdict":"parse-ok","code":null}

The diagnostic is reachable via `mathc explain-diagnostic` so
authors can look up remediation:

  $ $INSIDE_DUNE/bin/mathc.exe explain-diagnostic MC-SHA-MISMATCH | jq -c '{code, def_len: (.definition | length), rem_len: (.remediation | length)}'
  {"code":"MC-SHA-MISMATCH","def_len":324,"rem_len":506}

Cleanup:
  $ cd /
  $ rm -rf "$tmp"
