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
  $ $INSIDE_DUNE/bin/mathc.exe rehash --write .math-coding/decisions/probe.yaml > /dev/null
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
  $ $INSIDE_DUNE/bin/mathc.exe re-evaluate-decisions A0 > /dev/null 2>&1
  $ cat .math-coding/attestations/*probe-ob1.json | jq -c '{kind_, result, run: .producer.run}'
  {"kind_":"review","result":"inconclusive","run":"mathc re-evaluate-decisions A0"}

The GATE side of the same rule, and the half that was missing. The
writer above refused to sign a machine-grade pass; nothing stopped a
hand-written file from CLAIMING one, and the gate believed the claim.

A RUNTIME-class attestation (`kind_: test|build|analysis|observation`)
discharges an obligation only when its source class is ESTABLISHED: it
names the `producer.run` that produced it, OR its `producer.identity`
declares the machine class `ci:`. The declared producer classes are
`human:`, `agent:` and `ci:` (`decisions/attestation-producer-vocab-2026-10.yaml`);
`ci-bot:` is not one of them -- it is a grandfathered pre-vocabulary
spelling that names no class at all, so it cannot establish that a
check ran.

A `review`-class pass discharges the obligation as it stands. A review
claims nothing stronger than itself, so accepting it promotes nothing.

The store loader admits only TRACKED files (`store_keep_for`), so the
attestation below is committed before the gate reads it. The oracle's
own artefact is removed first: it is an `inconclusive` review of the
same obligation, and a second attestation for one obligation would
make the assertions below ambiguous.

  $ rm -rf .math-coding/attestations && mkdir -p .math-coding/attestations
  $ echo 'y' > src/g.txt
  $ cat > .math-coding/attestations/probe-ob1.json <<'JSON'
  > {"schema":"math-coding/attestation-3.3","kind":"attestation","subject":{"decision":"probe","obligation":"ob1","candidate_tree":"HEAD","materials_digest":""},"kind_":"test","producer":{"identity":"ci-bot"},"result":"pass","issued_at":"2026-10-08T00:00:00Z","id":"sha256:0000000000000000000000000000000000000000000000000000000000000001"}
  > JSON
  $ git add -A
  $ git -c user.email=t@example -c user.name=t commit -qm second

REJECTED -- a runtime-class pass that names no run and declares no
machine class. The obligation is not discharged, the gap names the
class, and the verdict is `unknown` (exit 3, never exit 0).

  $ $INSIDE_DUNE/bin/mathc.exe gate --no-scope --no-execute HEAD~1 HEAD > /tmp/evc-unanchored.json; echo "exit=$?"
  exit=3
  $ jq -c '{verdict, gap_kind: .gaps[0].kind, class_named: ([.gaps[0].causes[] | select(contains("source class is not established"))] | length > 0), remedy_named: ([.gaps[0].remedies[] | select(contains("producer.run"))] | length > 0)}' < /tmp/evc-unanchored.json
  {"verdict":"unknown","gap_kind":"Unknown","class_named":true,"remedy_named":true}

ACCEPTED -- the same runtime-class pass, now naming the run that
produced it. The producer identity is still undeclared; the run alone
establishes the class.

  $ cat > .math-coding/attestations/probe-ob1.json <<'JSON'
  > {"schema":"math-coding/attestation-3.3","kind":"attestation","subject":{"decision":"probe","obligation":"ob1","candidate_tree":"HEAD","materials_digest":""},"kind_":"test","producer":{"identity":"ci-bot","run":"dune runtest"},"result":"pass","issued_at":"2026-10-08T00:00:00Z","id":"sha256:0000000000000000000000000000000000000000000000000000000000000002"}
  > JSON
  $ $INSIDE_DUNE/bin/mathc.exe gate --no-scope --no-execute HEAD~1 HEAD > /tmp/evc-run.json; echo "exit=$?"
  exit=0
  $ jq -c '{verdict, gaps: (.gaps | length)}' < /tmp/evc-run.json
  {"verdict":"pass","gaps":0}

ACCEPTED -- the second anchor: a declared machine producer, no run.

  $ cat > .math-coding/attestations/probe-ob1.json <<'JSON'
  > {"schema":"math-coding/attestation-3.3","kind":"attestation","subject":{"decision":"probe","obligation":"ob1","candidate_tree":"HEAD","materials_digest":""},"kind_":"test","producer":{"identity":"ci:fixture"},"result":"pass","issued_at":"2026-10-08T00:00:00Z","id":"sha256:0000000000000000000000000000000000000000000000000000000000000003"}
  > JSON
  $ $INSIDE_DUNE/bin/mathc.exe gate --no-scope --no-execute HEAD~1 HEAD > /tmp/evc-ci.json; echo "exit=$?"
  exit=0
  $ jq -c '{verdict, gaps: (.gaps | length)}' < /tmp/evc-ci.json
  {"verdict":"pass","gaps":0}

ACCEPTED -- a review-class pass discharges the obligation as it stands,
with no run and a `human:` producer. The rule constrains the UPGRADE,
not the declaration.

  $ cat > .math-coding/attestations/probe-ob1.json <<'JSON'
  > {"schema":"math-coding/attestation-3.3","kind":"attestation","subject":{"decision":"probe","obligation":"ob1","candidate_tree":"HEAD","materials_digest":""},"kind_":"review","producer":{"identity":"human:maintainer"},"result":"pass","issued_at":"2026-10-08T00:00:00Z","id":"sha256:0000000000000000000000000000000000000000000000000000000000000004"}
  > JSON
  $ $INSIDE_DUNE/bin/mathc.exe gate --no-scope --no-execute HEAD~1 HEAD > /tmp/evc-review.json; echo "exit=$?"
  exit=0
  $ jq -c '{verdict, gaps: (.gaps | length)}' < /tmp/evc-review.json
  {"verdict":"pass","gaps":0}

Cleanup.

  $ cd /
  $ rm -rf "$tmpdir"
