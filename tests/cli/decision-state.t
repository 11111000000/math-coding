`mathc decision-state <id> <action> [--by=<id>@<rev>]` (decision
lifecycle-commands-2026-10) is a focused YAML editor for a
single decision's lifecycle state. It runs in a temporary
project root (`tmp=$(mktemp -d)` plus `decisions/<id>.yaml`)
so the live project's decisions are not mutated.

The five cases match the spec in the orchestration prompt. Case
A: mark-superseded on an active decision with --by exits 0;
the YAML edit lands; mathc validate re-accepts. Case B:
mark-retired on a fresh active decision exits 0. Case C:
idempotent re-issue of mark-retired exits 1 (the no-op path is
a reject, not a pass per the dispatcher). Case D:
mark-superseded on a missing decision id exits 2 (input
error -- id not found). Case E: mark-superseded with a
non-kebab id exits 2.

Setup: a single active decision in a scratch project; `mathc`
is on PATH (deps %{bin:mathc} in tests/cli/dune). Each case
re-mints the fixture so they are independent. We set
`MATH_CODING_ROOT` to keep the dispatcher's project-root
detection in the scratch dir (the dune-project marker sits
inside it).

The fixture YAML carries `mode: light` so the dialectical
slot is optional; the `counterexample` block is synthetic
boilerplate. The `body_sha` and `yaml_sha` are 64-zero
placeholders that match by construction (both are the same
zero string; the kernel recomputes on the next `mathc
validate` run after the user adopts the file).

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ mkdir -p decisions
  $ echo '(lang dune 3.0)' > dune-project
  $ cat > decisions/lifecycle-test-2026-10.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: lifecycle-test-2026-10
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent:
  >   source: lifecycle-commands-2026-10
  >   text: |
  >     Lightweight fixture for the lifecycle-commands cram test.
  > commitment: |
  >   One file, one obligation, no surprises.
  > outcomes:
  >   - id: o1
  >     statement: |
  >       trivially true.
  > scope:
  >   paths:
  >     - "tests/cli/decision-state.t"
  > obligations:
  >   - id: trivial-obligation
  >     claim: |
  >       validates under mathc validate with active state.
  >     acceptance:
  >       all:
  >         - verifier: tests/cli/decision-state.t
  >           result: pass
  > axiom_link:
  >   - A0
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > relations:
  >   addresses:
  >     - bootstrap-v3@3
  > counterexample: |
  >   None — this is a synthetic test fixture for the
  >   `mathc decision-state` CLI; the dialectical slot does not
  >   apply.
  > YAML
  $ cat > decisions/lifecycle-test-replacement-2026-10.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: lifecycle-test-replacement-2026-10
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent:
  >   source: lifecycle-commands-2026-10
  >   text: |
  >     Replacement target for mark-superseded --by.
  > commitment: |
  >   Cited as the superseder for lifecycle-test-2026-10.
  > outcomes:
  >   - id: o1
  >     statement: |
  >       trivially true.
  > scope:
  >   paths:
  >     - "tests/cli/decision-state.t"
  > obligations: []
  > axiom_link:
  >   - A0
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > relations:
  >   addresses:
  >     - bootstrap-v3@3
  > counterexample: |
  >   None — synthetic fixture.
  > YAML

Case (a) — `mark-superseded --by=...` on an active decision
exits 0, writes the YAML, re-validates, prints the summary
line. (`accept` renamed to `parse-ok` in commit a602b361.)

  $ MATH_CODING_ROOT="$tmp" mathc decision-state lifecycle-test-2026-10 mark-superseded \
  >     --by=lifecycle-test-replacement-2026-10@1
  mathc decision-state: set state=superseded; added superseded_by: lifecycle-test-replacement-2026-10@1
  validate: parse-ok

  $ grep '^state:' decisions/lifecycle-test-2026-10.yaml
  state: superseded
  $ grep -A1 'superseded_by:' decisions/lifecycle-test-2026-10.yaml
    superseded_by:
      - lifecycle-test-replacement-2026-10@1

Case (b) — re-mint the fixture at `state: active` then
`mark-retired`. Exits 0; the new state is `retired`.

  $ cat > decisions/lifecycle-test-2026-10.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: lifecycle-test-2026-10
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent:
  >   source: lifecycle-commands-2026-10
  >   text: |
  >     Same fixture as case (a), re-minted at active.
  > commitment: |
  >   Exercise mark-retired.
  > outcomes:
  >   - id: o1
  >     statement: |
  >       trivially true.
  > scope:
  >   paths:
  >     - "tests/cli/decision-state.t"
  > obligations:
  >   - id: trivial-obligation
  >     claim: |
  >       validates under mathc validate with active state.
  >     acceptance:
  >       all:
  >         - verifier: tests/cli/decision-state.t
  >           result: pass
  > axiom_link:
  >   - A0
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > relations:
  >   addresses:
  >     - bootstrap-v3@3
  > counterexample: |
  >   None — this is a synthetic test fixture for the
  >   `mathc decision-state` CLI; the dialectical slot does not
  >   apply.
  > YAML
  $ MATH_CODING_ROOT="$tmp" mathc decision-state lifecycle-test-2026-10 mark-retired
  mathc decision-state: set state=retired
  validate: parse-ok

  $ grep '^state:' decisions/lifecycle-test-2026-10.yaml
  state: retired

Case (c) — re-issue `mark-retired` (idempotency). The
dispatcher treats the no-op as a reject (exit 1), not a pass.

  $ if MATH_CODING_ROOT="$tmp" mathc decision-state lifecycle-test-2026-10 mark-retired 2>/dev/null; then
  >   echo "FAIL: expected exit 1 on idempotent mark-retired"
  > else
  >   echo "idempotent mark-retired rejected (exit $?)"
  > fi
  idempotent mark-retired rejected (exit 1)

Case (d) — missing decision. The dispatcher exits 2 with a
diagnostic naming the absent path; the diagnostic contains the
basename so the cram sandbox path mismatch does not affect
the assertion.

  $ if MATH_CODING_ROOT="$tmp" mathc decision-state not-a-real-decision-2026-10 mark-superseded --by=other-2026-10@1 2>/dev/null; then
  >   echo "FAIL: expected exit 2 on missing id"
  > else
  >   echo "missing id refused (exit $?)"
  > fi
  missing id refused (exit 2)

Case (e) — non-kebab id. The kebab-case validator exits 2
before any disk I/O; the diagnostic mirrors
`schemas/decision.json`.

  $ if MATH_CODING_ROOT="$tmp" mathc decision-state Bad_ID mark-superseded --by=other-2026-10@1 2>/dev/null; then
  >   echo "FAIL: expected exit 2 on non-kebab id"
  > else
  >   echo "bad id refused (exit $?)"
  > fi
  bad id refused (exit 2)

Cleanup.

  $ cd /
  $ rm -rf "$tmp"
