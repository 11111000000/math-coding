mathc self-check does not accept a machine-grade pass that names no
run, and `mathc re-evaluate-decisions` no longer writes one.

`kind_: test|build|analysis|observation` says "a check ran and it
passed". `producer.run` is what makes that claim falsifiable: it is
the command a reader can re-run and compare the recorded digest
against. An attestation of a machine class that names no run is a
signature, not a check.

The corpus carried 88 of them: `mathc re-evaluate-decisions` wrote
`kind_: test`, `result: pass`, an empty `materials_digest` (the
freshness wildcard) and no `producer.run`, for every obligation of
every decision. Its `result` came from the re-evaluation oracle's
word "compatible" -- "this decision's claim does not contradict axiom
A0" -- which is a REVIEW-class judgement and not "the check passed".
The oracle never executes a verifier.

Both halves are pinned here.

Setup: a project with one decision and one hand-written attestation.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ cd "$tmpdir"
  $ echo '(lang dune 3.0)' > "$tmpdir/dune-project"
  $ export MATH_CODING_ROOT="$tmpdir"
  $ git init -q .
  $ mkdir -p .math-coding/decisions .math-coding/attestations
  $ cat > .math-coding/decisions/probe.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: probe
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   A probe decision.
  > commitment: |
  >   One obligation.
  > outcomes:
  >   - id: o1
  >     statement: |
  >       The obligation exists.
  > scope:
  >   paths:
  >     - "src/**"
  > obligations:
  >   - id: ob1
  >     claim: |
  >       A claim.
  >     acceptance:
  >       all:
  >         - verifier: file-exists src
  >           result: pass
  > axiom_link:
  >   - A0
  > counterexample: |
  >   None; synthetic fixture.
  > risk:
  >   declared_triggers:
  >     - never
  >   owner: human:maintainer
  > relations:
  >   addresses: []
  >   supersedes: []
  >   superseded_by: []
  > YAML
  $ mkdir -p src && echo 'x' > src/f.txt
  $ mathc rehash --write .math-coding/decisions/probe.yaml > /dev/null
  $ git add -A
  $ git -c user.email=t@example -c user.name=t commit -qm init
  $ tree=$(git rev-parse HEAD)

`mathc re-evaluate-decisions` writes a REVIEW, anchored to the
command that produced it, and `inconclusive` -- not a machine-grade
pass. The oracle re-reads a decision and asks whether its claim
contradicts an axiom; it does not execute the obligation's verifier.

The corpus carried 88 attestations of exactly the wrong shape:
`kind_: test`, `result: pass`, an empty `materials_digest` (the
freshness wildcard) and no `producer.run`. A machine-grade class says
"a check ran and it passed"; without a run to name, that is a
signature.

`mathc re-evaluate-decisions` writes a REVIEW, anchored to the
command that produced it, and `inconclusive` -- not a machine-grade
pass. The oracle re-reads a decision and asks whether its claim
contradicts an axiom; it does not execute the obligation's verifier.

  $ rm -rf .math-coding/attestations && mkdir -p .math-coding/attestations
  $ mathc re-evaluate-decisions A0 > /dev/null 2>&1
  $ cat .math-coding/attestations/*probe-ob1.json | jq -c '{kind_, result, run: .producer.run}'
  {"kind_":"review","result":"inconclusive","run":"mathc re-evaluate-decisions A0"}

Cleanup.

  $ cd /
  $ rm -rf "$tmpdir"
