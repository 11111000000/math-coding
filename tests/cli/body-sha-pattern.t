Hermetic version of the `body_sha` / `yaml_sha` pattern
enforcement pin (see `tests/cli/validate-body-sha-pattern.t` for
the broader suite). The rule: when `body_sha` or `yaml_sha` is
present in a decision, its value MUST match
`^sha256:[0-9a-f]{64}$` (71 characters total: 7 for the
`sha256:` prefix and 64 hex chars for the digest). Any other
present-but-non-matching value is rejected with
`MC-BODY-SHA-PATTERN-VIOLATION` (Block, exit 1).

This closes the loophole where a literal shell-template artifact
like `sha256:' + sha + '` (which survived the prior equality-only
check) would otherwise pass (per PLAN.md §3.1, recorded in
`decisions/kernel-bugs-v3.4-2026-10.yaml`). The pattern enforcement
is part of an A3-protected transition (self-application closure).

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ cd "$tmpdir"

Positive case: a decision with valid `body_sha` and `yaml_sha`
must accept. "Valid" here means both pattern AND currency: the
fields below hold the 64-zero placeholder, which matches
`^sha256:[0-9a-f]{64}$` but is not the digest of this file, so
validate would reject it with `MC-SHA-DIGEST-STALE` before any
pattern question arises. `mathc rehash` writes the real digest, so
the positive case isolates the rule this fixture is about instead
of the digest rule.

  $ cat > good.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: body-sha-pattern-good
  > revision: 1
  > state: active
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > axiom_link:
  >   - A0
  > intent: "Test"
  > commitment: "Test"
  > counterexample: "Test"
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
  >         - verifier: mathc self-check
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe rehash good.yaml --write | sed '/^$/d'
    STAMP good.yaml
  rehash: 1 changed, 0 already current, 0 skipped (written)
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json good.yaml | jq -c '{verdict, code}'
  {"verdict":"parse-ok","code":null}

Negative case: `body_sha: "garbage"` (the most common offender --
a placeholder that survived pre-fix) MUST be rejected with
`MC-BODY-SHA-PATTERN-VIOLATION`. The exit code is 1.

  $ cat > garbage.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: body-sha-pattern-garbage
  > revision: 1
  > state: active
  > body_sha: "garbage"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > axiom_link:
  >   - A0
  > intent: "Test"
  > commitment: "Test"
  > counterexample: "Test"
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
  >         - verifier: mathc self-check
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json garbage.yaml | jq -c '{verdict, code, severity}'
  {"verdict":"reject","code":"MC-BODY-SHA-PATTERN-VIOLATION","severity":"block"}

Negative case: the literal shell-template artifact
`sha256:' + sha + '` that survived the prior equality-only check
must now be rejected. This is the regression pin for the loophole
PLAN.md §3.1 names.

  $ cat > template-artifact.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: body-sha-pattern-template-artifact
  > revision: 1
  > state: active
  > body_sha: "sha256:' + sha + '"
  > yaml_sha: "sha256:' + sha + '"
  > axiom_link:
  >   - A0
  > intent: "Test"
  > commitment: "Test"
  > counterexample: "Test"
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
  >         - verifier: mathc self-check
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json template-artifact.yaml | jq -c '{verdict, code, severity}'
  {"verdict":"reject","code":"MC-BODY-SHA-PATTERN-VIOLATION","severity":"block"}

The diagnostic is reachable via `mathc explain-diagnostic`.

  $ cd "$DUNE_SOURCEROOT"
  $ $INSIDE_DUNE/bin/mathc.exe explain-diagnostic MC-BODY-SHA-PATTERN-VIOLATION | jq -r '.remediation' | head -3
  Replace the offending value with the canonical
  SHA-256 of the decision body (with both fields replaced
  by `sha256:` + 64 zeros). The reference implementation

Cleanup.

  $ rm -rf "$tmpdir"

