mathc validate enforces the schema-declared pattern on body_sha
and yaml_sha (`^sha256:[0-9a-f]{64}$`, 71 characters total).
Per `schemas/decision.json#body_sha`/`#yaml_sha`, the kernel now
rejects any present-but-non-matching value with
`MC-BODY-SHA-PATTERN-VIOLATION` (Block, exit 1). Per
`decisions/kernel-bugs-v3.4-2026-10`, this closes the loophole
where a literal shell-template artifact like `sha256:' + sha + '`
(used by the upstream math-coding repo's own `body_sha` template)
would survive the prior equality-only check.

This is the positive-and-negative contract for the
body_sha/yaml_sha pattern enforcement (decisions/kernel-bugs-
v3.4-2026-10). The check is part of an A3-protected transition
(self-application closure).

  $ cd "$DUNE_SOURCEROOT"

A decision with a well-FORMED `body_sha`/`yaml_sha` pair is accepted
once the digest actually corresponds to the file. The template writes
the 64-zero placeholder, which is well-formed and equal to itself but
describes nothing, so it is now rejected until `mathc rehash` supplies
a real digest. Matching the pattern was never the whole rule:

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ cat > sha-pattern-good.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: sha-pattern-good-demo
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
  >         - verifier: tests/conformance.exe
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json sha-pattern-good.yaml | jq -c '{verdict, code}'
  {"verdict":"reject","code":"MC-SHA-DIGEST-STALE"}
  $ $INSIDE_DUNE/bin/mathc.exe rehash sha-pattern-good.yaml --write > /dev/null
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json sha-pattern-good.yaml | jq -c '{verdict, code}'
  {"verdict":"parse-ok","code":null}

A decision with a `body_sha` that is NOT the canonical
`sha256:` + 64 hex chars is rejected with
`MC-BODY-SHA-PATTERN-VIOLATION`:

  $ cat > sha-pattern-garbage.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: sha-pattern-garbage-demo
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
  >         - verifier: tests/conformance.exe
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json sha-pattern-garbage.yaml | jq -c '{verdict, code, severity}'
  {"verdict":"reject","code":"MC-BODY-SHA-PATTERN-VIOLATION","severity":"block"}

A literal shell-template artifact (`sha256:' + sha + '`) that
survived the prior equality-only check is now rejected:

  $ cat > sha-pattern-template-artifact.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: sha-pattern-template-artifact-demo
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
  >         - verifier: tests/conformance.exe
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json sha-pattern-template-artifact.yaml | jq -c '{verdict, code, severity}'
  {"verdict":"reject","code":"MC-BODY-SHA-PATTERN-VIOLATION","severity":"block"}

A decision with both `body_sha` AND `yaml_sha` matching the
pattern is accepted — but matching the pattern is no longer
sufficient. The digest must also be the digest OF THIS FILE. The
fabricated `1111...` this fixture used to write and expect
`parse-ok` is exactly the hole that let an edited decision keep
validating: syntactically valid and equal to itself, describing
nothing. `mathc rehash` supplies a real digest, which is what the
workflow now requires, and MC-SHA-DIGEST-STALE is the diagnostic when
the pattern is fine but the value is not:

  $ cat > sha-pattern-valid-both.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: sha-pattern-valid-both-demo
  > revision: 1
  > state: active
  > body_sha: "sha256:1111111111111111111111111111111111111111111111111111111111111111"
  > yaml_sha: "sha256:1111111111111111111111111111111111111111111111111111111111111111"
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
  >         - verifier: tests/conformance.exe
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json sha-pattern-valid-both.yaml | jq -c '{verdict, code}'
  {"verdict":"reject","code":"MC-SHA-DIGEST-STALE"}
  $ $INSIDE_DUNE/bin/mathc.exe rehash sha-pattern-valid-both.yaml --write > /dev/null
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json sha-pattern-valid-both.yaml | jq -c '{verdict, code}'
  {"verdict":"parse-ok","code":null}

The diagnostic is reachable via `mathc explain-diagnostic`:

  $ $INSIDE_DUNE/bin/mathc.exe explain-diagnostic MC-BODY-SHA-PATTERN-VIOLATION | jq -r '.remediation' | head -1
  Replace the offending value with the canonical

Cleanup:

  $ cd /
  $ rm -rf "$tmp"
