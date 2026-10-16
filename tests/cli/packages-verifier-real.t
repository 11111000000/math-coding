`mathc packages --format=json` extracts the actual `verifier`
string from each obligation's `acceptance.all[].verifier` and
emits it in the `verifier` field of the JSON output (per
`decisions/kernel-bugs-v3.4-2026-10.yaml`; PLAN.md §3.1). The
pre-fix kernel rendered a placeholder equal to the obligation id,
which made the `packages` output useless for review: a reviewer
could not tell which verifier was supposed to run for an
obligation without opening the decision itself. The post-fix kernel
emits the literal verifier string.

Note: `mathc packages` walks the hardcoded `decisions/` directory
relative to cwd (per `bin/Mathc.ml::do_packages`, line 4604).
This test is hermetic for the host checkout (a fresh tmpdir is
created and removed), but it does rely on the legacy `decisions/`
path because the path resolver is not yet wired into the packages
subcommand (a v3.5 follow-up per `decisions/ux-3-minimal-pollution-2026-10.yaml`).
The test is forward-compatible: once the packages subcommand picks
up `Path_config.resolve_decisions_dir ()`, the test continues to
pass -- the fixture path is renamed to point at the resolved dir.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ cd "$tmpdir"

Hand-write a minimal-but-parseable v3.2 decision with two
obligations. The two `verifier` values are intentionally
distinct so the test cannot pass by accident: if both
obligations ended up with the same verifier, a placeholder
implementation that returns the obligation id would also
"work" trivially.

  $ mkdir decisions
  $ cat > decisions/foo.yaml <<EOF
  > ---
  > schema: math-coding/3.2
  > id: foo-decision
  > revision: 1
  > state: active
  > mode: standard
  > change_kind: implementation
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > axiom_link:
  >   - A0
  >   - A1
  >   - A3
  > intent: |
  >   Test decision for the packages-verifier-real pin.
  > commitment: |
  >   Verify that mathc packages --format=json shows the real verifier string.
  > counterexample: |
  >   Pre-fix mathc packages rendered a placeholder for the verifier field.
  > scope:
  >   paths: ["**"]
  > outcomes:
  >   - id: o1
  >     statement: A first outcome.
  > obligations:
  >   - id: obl-acceptance
  >     outcome: o1
  >     claim: A claim.
  >     acceptance:
  >       all:
  >         - verifier: mathc self-check
  >           result: pass
  >   - id: obl-build
  >     outcome: o1
  >     claim: Another claim.
  >     acceptance:
  >       all:
  >         - verifier: dune runtest
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:tester
  > relations:
  >   addresses: []
  > EOF

The `verifier` field of each obligation MUST equal the literal
`verifier` string from the YAML, NOT the obligation id. The
test projects the `id` and `verifier` fields into a flat list
so a regression where the verifier field is dropped or
substituted with the obligation id trips immediately.

  $ mathc packages --format=json | jq -c '.decisions[0].obligations[] | {id, verifier}'
  {"id":"obl-acceptance","verifier":"mathc self-check"}
  {"id":"obl-build","verifier":"dune runtest"}

Sanity: each obligation id MUST NOT equal its "verifier" field.
This is the regression pin for the kernel-bugs v3.4 fix: pre-fix,
the verifier field was a placeholder equal to the obligation id.

  $ mathc packages --format=json | jq '[.decisions[0].obligations[] | select(.id == .verifier)] | length'
  0

The JSON shape carries the `verifier` field for every obligation.
A regression where the field is omitted (rather than substituted
with the obligation id) is also caught here.

  $ mathc packages --format=json | jq '[.decisions[0].obligations[].verifier] | length'
  2
  $ mathc packages --format=json | jq '[.decisions[0].obligations[].verifier] | all(. != null and . != "")'
  true

Cleanup.

  $ cd /
  $ rm -rf "$tmpdir"

