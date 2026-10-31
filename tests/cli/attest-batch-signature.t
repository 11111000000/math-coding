`mathc attest-batch --from=decisions` signs one attestation per
obligation in the store. It used to do that with three values it
chose on the operator's behalf: `kind_: review`, `result: pass`,
and `producer.identity: human:integration-experiment`. On this
corpus that is 793 attestations signed by a person who is not at
the keyboard, each asserting that nobody ran anything and each
carrying the name of the last release that hard-coded that string.

This fixture pins what replaced it: `--producer` has no default and
the command refuses without one; a batch larger than
`mass_issue_threshold` announces its own scale on stderr before a
single file is written; and `--kind` in the runtime set
(test|build|analysis|observation) requires `--run=<command>`, whose
exit code becomes `result` and whose output digest becomes
`materials_digest`. No `--kind` is left that prints `pass` for a run
that never happened.

It pins what did NOT change: `review` still carries an empty
`materials_digest`. The schema exempts exactly that kind -- "a
human declaration without a runtime anchor" -- and this is a
narrowing of who may sign, not of what a review is.

Hermetic: the decisions and the attestation store both live under
the tmpdir.  (No host checkout is touched.)

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d) && cd "$tmpdir"
  $ export MATH_CODING_ROOT="$tmpdir"
  $ git init -q "$tmpdir"
  $ git -C "$tmpdir" config user.email "t@t"
  $ git -C "$tmpdir" config user.name "t"
  $ git -C "$tmpdir" commit -q --allow-empty -m initial
  $ export MATH_CODING_DECISIONS_DIR=".test-math-coding/decisions"
  $ export MATH_CODING_ATTESTATIONS_DIR=".test-math-coding/attestations"
  $ mkdir -p "$MATH_CODING_DECISIONS_DIR" "$MATH_CODING_ATTESTATIONS_DIR"

A decision writer, so the fixture can ask for exactly as many
obligations as a case needs. The count is what drives the mass
report: 2 obligations stay under the threshold, 12 do not.

  $ write_decision() {
  >   id=$1; n=$2; out=$3
  >   {
  >     echo "---"
  >     echo "schema: math-coding/3.2"
  >     echo "id: $id"
  >     echo "revision: 1"
  >     echo "state: active"
  >     echo "mode: standard"
  >     echo "change_kind: implementation"
  >   # The EMPTY stub, not a placeholder of zeros: the kernel accepts
  >   # the empty string as a vacuous pass (decisions/
  >   # schema-empty-sha-2026-10.yaml), while an all-zeros digest is
  >   # COMPARED and therefore rejected as stale - which is what happened
  >   # here when the digest check became a block on 2026-10-22 and this
  >   # fixture was not updated with it.
  >   echo "body_sha: \"sha256:0000000000000000000000000000000000000000000000000000000000000000\""
  >   echo "yaml_sha: \"sha256:0000000000000000000000000000000000000000000000000000000000000000\""
  >     echo "axiom_link:"
  >     echo "  - A0"
  >     echo "  - A1"
  >     echo "  - A3"
  >     echo "intent: |"
  >     echo "  Fixture for the attest-batch signature obligations."
  >     echo "commitment: |"
  >     echo "  Signing is an explicit act."
  >     echo "counterexample: |"
  >     echo "  Synthetic."
  >     echo "scope:"
  >     echo "  paths: [\"**\"]"
  >     echo "outcomes:"
  >     echo "  - id: o1"
  >     echo "    statement: A first outcome."
  >     echo "obligations:"
  >     i=1
  >     while [ "$i" -le "$n" ]; do
  >       echo "  - id: obl-$i"
  >       echo "    outcome: o1"
  >       echo "    claim: A claim."
  >       echo "    acceptance:"
  >       echo "      all:"
  >       echo "        - verifier: mathc self-check"
  >       echo "          result: pass"
  >       i=$((i + 1))
  >     done
  >     echo "risk:"
  >     echo "  declared_triggers: []"
  >     echo "  owner: human:tester"
  >     echo "relations:"
  >     echo "  addresses: []"
  >   } > "$out"
  > }

Two small decisions first: 2 obligations and 3, i.e. 5 rows.

  $ write_decision small-a 2 "$MATH_CODING_DECISIONS_DIR/small-a.yaml"
  $ write_decision small-b 3 "$MATH_CODING_DECISIONS_DIR/small-b.yaml"

The decisions are written with the all-zeros digest placeholder and
then STAMPED: `mathc rehash --write` computes the canonical digest
of the file's own bytes. A decision cannot be parsed until its
digest is right, and its digest cannot be computed until the file
exists - so the placeholder is what breaks the loop, and rehash is
what closes it.

  $ $INSIDE_DUNE/bin/mathc.exe rehash --write "$MATH_CODING_DECISIONS_DIR/small-a.yaml" "$MATH_CODING_DECISIONS_DIR/small-b.yaml" 2>&1 | tail -1
  rehash: 2 changed, 0 already current, 0 skipped (written)

The decisions are COMMITTED before anything is signed. Under
semantics A the materials digest is the digest of the content of the
files the scope names, taken at the tree the attestation names - so
the scope has to exist in that tree. A decision written after the
commit is not in the tree, its scope digests to the empty set, and
the attestation says nothing. That is not a corner case: it is what
happens to every attestation whose scope was never committed.

  $ git add -A
  $ git commit -q -m "fixture decisions"

1. No `--producer`: refuse, and refuse BEFORE reading the store.
The exit code is 2 (input error) and not a single attestation is
written -- the refusal is not a warning followed by a batch signed
as someone else.

  $ $INSIDE_DUNE/bin/mathc.exe attest-batch --from=decisions --dry-run > /dev/null 2> refuse.log; echo "EXIT=$?"
  EXIT=2
  $ cat refuse.log
  mathc attest-batch: --producer=<identity> is required with --from=decisions
    Every attestation names the producer that signed it, and a default
    would sign this whole batch as whoever the last release happened
    to hard-code. Pass --producer=human:<you> or --producer=agent:<id>.
    (--manifest rows carry their own producer and do not need this.)
  $ ls .test-math-coding/attestations | wc -l
  0

`--help` must not advertise a default it no longer has.

  $ $INSIDE_DUNE/bin/mathc.exe attest-batch --help 2>&1 | grep 'producer identity'
    --producer  <id> producer identity for --from=decisions (REQUIRED; there is no default)

3. A runtime kind without a run: refuse. `--kind=test` claims
something ran; printing `result: pass` for a run that never
happened, five times over, is the defect this closes.

  $ $INSIDE_DUNE/bin/mathc.exe attest-batch --from=decisions --producer=human:fixture --kind=test --dry-run > /dev/null 2> kind.log; echo "EXIT=$?"
  EXIT=2
  $ head -1 kind.log
  mathc attest-batch: --kind=test needs --run=<command>

`review` is the one kind allowed to rest on a human declaration,
so it alone still needs nothing but a name.

  $ $INSIDE_DUNE/bin/mathc.exe attest-batch --from=decisions --producer=human:fixture --kind=review --dry-run 2> small.log | wc -l
  5
  $ grep -c 'bulk signature' small.log || true
  0

5 rows is readable at a glance; below the threshold the mass
report stays quiet.

Now the bulk case: two decisions of 6 obligations each.

  $ write_decision bulk-a 6 "$MATH_CODING_DECISIONS_DIR/bulk-a.yaml"
  $ write_decision bulk-b 6 "$MATH_CODING_DECISIONS_DIR/bulk-b.yaml"
  $ rm "$MATH_CODING_DECISIONS_DIR/small-a.yaml" "$MATH_CODING_DECISIONS_DIR/small-b.yaml"

2. Above the threshold the batch announces itself, on stderr, with
the three numbers an operator needs to decide whether to go ahead:
how many attestations, for how many decisions, and under whose name.
The stdout stream still carries only the JSON, so the report can
be redirected away without touching the output a caller parses.

  $ $INSIDE_DUNE/bin/mathc.exe attest-batch --from=decisions --producer=human:fixture --dry-run 2> bulk.log | wc -l
  12
  $ cat bulk.log
  mathc attest-batch: about to issue 12 attestations across 2 decision(s)
    producer=human:fixture kind_=review result=pass
    That is a bulk signature, not a review. Narrow the batch with --manifest=PATH to sign one obligation at a time.

3. `--run` is a command, not a shell. A `|` is refused before
anything is read, exactly like the verify sandbox refuses one.

  $ $INSIDE_DUNE/bin/mathc.exe attest-batch --from=decisions --producer=human:fixture --kind=test --run="ls | wc -l" --dry-run > /dev/null 2> meta.log; echo "EXIT=$?"
  EXIT=2
  $ cat meta.log
  mathc attest-batch: --run contains the shell metacharacter '|'; attest-batch never runs a shell

A run that passes: its exit code is the result, its output is the
materials anchor. The digest is a sha256 of the run's output, so
every attestation in the batch cites the same run -- one run, not
twelve -- and the report line names the run it was.

  $ printf '#!/bin/sh\necho "ran the suite: 12 cases"\nexit 0\n' > probe-ok.sh
  $ chmod +x probe-ok.sh
  $ $INSIDE_DUNE/bin/mathc.exe attest-batch --from=decisions --producer=human:fixture --kind=test --run="$tmpdir/probe-ok.sh" > /dev/null 2> run-ok.log; echo "EXIT=$?"
  EXIT=0
  $ grep -c '^wrote ' run-ok.log
  12
  $ grep 'producer=' run-ok.log | sed "s|$tmpdir|<TMP>|g"
    producer=human:fixture kind_=test result=pass (result of one run: <TMP>/probe-ok.sh)
  $ python3 -c "
  > import json, glob
  > rows = [json.load(open(p)) for p in sorted(glob.glob('.test-math-coding/attestations/*.json'))]
  > assert len(rows) == 12, len(rows)
  > assert all(r['kind_'] == 'test' for r in rows), 'kind'
  > assert all(r['result'] == 'pass' for r in rows), 'result'
  > digests = {r['subject']['materials_digest'] for r in rows}
  > assert all(d.startswith('sha256:') and len(d) == 71 for d in digests), digests
  > decisions = {r['subject']['decision'] for r in rows}
  > assert len(digests) <= len(decisions), (len(digests), len(decisions))
  > print('12 test attestations, result=pass, one scope digest per decision')
  > "
  12 test attestations, result=pass, one scope digest per decision

A run that fails: the batch is signed `fail`, and the operator is
told on stderr that this is what happened. `--result` is not
consulted when `--run` is given -- otherwise the run would be
decoration.

  $ printf '#!/bin/sh\necho "1 test failed"\nexit 1\n' > probe-bad.sh
  $ chmod +x probe-bad.sh
  $ $INSIDE_DUNE/bin/mathc.exe attest-batch --from=decisions --producer=human:fixture --kind=test --result=pass --run="$tmpdir/probe-bad.sh" 2> run-bad.log > /dev/null; echo "EXIT=$?"
  EXIT=0
  $ head -1 run-bad.log | sed "s|$tmpdir|<TMP>|g"
  mathc attest-batch: --run `<TMP>/probe-bad.sh` did not exit 0; the batch is signed result=fail
  $ python3 -c "
  > import json, glob
  > rows = [json.load(open(p)) for p in sorted(glob.glob('.test-math-coding/attestations/*.json'))]
  > assert all(r['result'] == 'fail' for r in rows), sorted({r['result'] for r in rows})
  > assert all(r['subject']['materials_digest'].startswith('sha256:') for r in rows), 'digest'
  > print(len(rows), 'attestations re-signed result=fail by the run')
  > "
  12 attestations re-signed result=fail by the run

And back to `review`: the digest is the SCOPE digest again, and
that is correct under semantics A. A review carries no execution
anchor - no build log, no test output - but it is still bound to the
content it reviewed. A review whose scope changed afterwards is a
review of something that no longer exists, and under semantics A it
goes stale like any other attestation. An attestation that can never
be invalidated is not a declaration; it is a decoration.

  $ $INSIDE_DUNE/bin/mathc.exe attest-batch --from=decisions --producer=human:fixture --kind=review > /dev/null 2>&1
  $ python3 -c "
  > import json, glob
  > rows = [json.load(open(p)) for p in sorted(glob.glob('.test-math-coding/attestations/*.json'))]
  > assert all(r['kind_'] == 'review' for r in rows), 'kind'
  > assert all(r['result'] == 'pass' for r in rows), 'result'
  > assert all(r['producer']['identity'] == 'human:fixture' for r in rows), 'producer'
  > assert all(r['subject']['materials_digest'].startswith('sha256:') for r in rows), 'review digest must be the scope digest'
  > print(len(rows), 'review attestations, scope digest, named producer')
  > "
  12 review attestations, scope digest, named producer

The manifest branch is the OTHER half of `attest-batch`, and until now
this fixture exercised only `--from=decisions`. The obligation that
names this fixture -- `runtime-kind-without-run-is-refused` in
decisions/attest-per-obligation-2026-10.yaml -- is a claim about
`mathc attest-batch --manifest=FILE`, and it was standing on a fixture
that never ran the code it was about. A verifier that exercises one
branch cannot vouch for the other.

A manifest is a TSV: one row per obligation to sign,
`decision_id<TAB>obligation_id<TAB>kind_<TAB>producer_identity`. The
producer is part of the ROW, so a manifest needs no `--producer` --
that is the point of the manifest form, and it is the one place where
the identity is not a flag on the command line.

  $ printf 'bulk-a\tobl-1\treview\thuman:manifest-fixture\n' > "$tmpdir/manifest-review.tsv"
  $ $INSIDE_DUNE/bin/mathc.exe attest-batch --manifest="$tmpdir/manifest-review.tsv" --out="$tmpdir/manifest-attestations" 2> manifest-review.log; echo "EXIT=$?"
  EXIT=0
  $ grep -c '^wrote ' manifest-review.log
  1
  $ ls -1 "$tmpdir/manifest-attestations" | sort
  bulk-a-obl-1.json

The attestation carries the producer the ROW named -- not a default,
and not whoever happened to run the command.

  $ python3 -c "
  > import json
  > r = json.load(open('$tmpdir/manifest-attestations/bulk-a-obl-1.json'))
  > assert r['kind_'] == 'review', r['kind_']
  > assert r['producer']['identity'] == 'human:manifest-fixture', r['producer']
  > assert r['subject']['decision'] == 'bulk-a', r['subject']
  > assert r['subject']['obligation'] == 'obl-1', r['subject']
  > print('the row signed itself: ' + r['producer']['identity'])
  > "
  the row signed itself: human:manifest-fixture

A row that declares a RUNTIME kind with no `--run` behind it is
refused, and the refusal names the kind. The row claims that something
ran; nothing ran; and the command would print `result: pass` for it
anyway. Naming the kind is what tells the operator WHICH row to fix.

  $ printf 'bulk-b\tobl-2\ttest\tci:manifest-fixture\n' > "$tmpdir/manifest-runtime.tsv"
  $ $INSIDE_DUNE/bin/mathc.exe attest-batch --manifest="$tmpdir/manifest-runtime.tsv" --out="$tmpdir/manifest-attestations" > /dev/null 2> manifest-runtime.log; echo "EXIT=$?"
  EXIT=2
  $ cat manifest-runtime.log
  mathc attest-batch: the manifest declares test attestation(s), and a test attestation claims something ran. Without --run=<command> this command would print `result: pass` for a run that never happened, for every such row. Use --run="dune runtest" (or whatever command produces the artefact) or declare those rows as `review`.

And nothing was written for the refused row: a refusal that signs the
row anyway is a refusal in name only.

  $ ls -1 "$tmpdir/manifest-attestations" | grep -c 'bulk-b' || true
  0

The preview path is a preview. `--dry-run` prints what it WOULD write
and writes nothing -- here a row for an obligation that has no file in
the store yet, so the count cannot move.

  $ printf 'bulk-b\tobl-1\treview\thuman:manifest-fixture\n' > "$tmpdir/manifest-dry.tsv"
  $ $INSIDE_DUNE/bin/mathc.exe attest-batch --manifest="$tmpdir/manifest-dry.tsv" --dry-run | wc -l
  1
  $ ls -1 "$tmpdir/manifest-attestations" | wc -l
  1

Cleanup.

  $ cd /
  $ rm -rf "$tmpdir"
  $ unset MATH_CODING_DECISIONS_DIR
  $ unset MATH_CODING_ATTESTATIONS_DIR
