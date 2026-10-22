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
  >     echo "body_sha: \"sha256:0000000000000000000000000000000000000000000000000000000000000000\""
  >     echo "yaml_sha: \"sha256:0000000000000000000000000000000000000000000000000000000000000000\""
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

1. No `--producer`: refuse, and refuse BEFORE reading the store.
The exit code is 2 (input error) and not a single attestation is
written -- the refusal is not a warning followed by a batch signed
as someone else.

  $ mathc attest-batch --from=decisions --dry-run > /dev/null 2> refuse.log; echo "EXIT=$?"
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

  $ mathc attest-batch --help 2>&1 | grep 'producer identity'
    --producer  <id> producer identity for --from=decisions (REQUIRED; there is no default)

3. A runtime kind without a run: refuse. `--kind=test` claims
something ran; printing `result: pass` for a run that never
happened, five times over, is the defect this closes.

  $ mathc attest-batch --from=decisions --producer=human:fixture --kind=test --dry-run > /dev/null 2> kind.log; echo "EXIT=$?"
  EXIT=2
  $ head -1 kind.log
  mathc attest-batch: --kind=test needs --run=<command>

`review` is the one kind allowed to rest on a human declaration,
so it alone still needs nothing but a name.

  $ mathc attest-batch --from=decisions --producer=human:fixture --kind=review --dry-run 2> small.log | wc -l
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

  $ mathc attest-batch --from=decisions --producer=human:fixture --dry-run 2> bulk.log | wc -l
  12
  $ cat bulk.log
  mathc attest-batch: about to issue 12 attestations across 2 decision(s)
    producer=human:fixture kind_=review result=pass
    That is a bulk signature, not a review. Narrow the batch with --manifest=PATH to sign one obligation at a time.

3. `--run` is a command, not a shell. A `|` is refused before
anything is read, exactly like the verify sandbox refuses one.

  $ mathc attest-batch --from=decisions --producer=human:fixture --kind=test --run="ls | wc -l" --dry-run > /dev/null 2> meta.log; echo "EXIT=$?"
  EXIT=2
  $ cat meta.log
  mathc attest-batch: --run contains the shell metacharacter '|'; attest-batch never runs a shell

A run that passes: its exit code is the result, its output is the
materials anchor. The digest is a sha256 of the run's output, so
every attestation in the batch cites the same run -- one run, not
twelve -- and the report line names the run it was.

  $ printf '#!/bin/sh\necho "ran the suite: 12 cases"\nexit 0\n' > probe-ok.sh
  $ chmod +x probe-ok.sh
  $ mathc attest-batch --from=decisions --producer=human:fixture --kind=test --run="$tmpdir/probe-ok.sh" > /dev/null 2> run-ok.log; echo "EXIT=$?"
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
  > assert len(digests) == 1, digests
  > only = digests.pop()
  > assert only.startswith('sha256:') and len(only) == 71, only
  > print('12 test attestations, result=pass, one shared sha256 digest')
  > "
  12 test attestations, result=pass, one shared sha256 digest

A run that fails: the batch is signed `fail`, and the operator is
told on stderr that this is what happened. `--result` is not
consulted when `--run` is given -- otherwise the run would be
decoration.

  $ printf '#!/bin/sh\necho "1 test failed"\nexit 1\n' > probe-bad.sh
  $ chmod +x probe-bad.sh
  $ mathc attest-batch --from=decisions --producer=human:fixture --kind=test --result=pass --run="$tmpdir/probe-bad.sh" 2> run-bad.log > /dev/null; echo "EXIT=$?"
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

And back to `review`: the digest is empty again, and that is
correct. The schema requires a runtime anchor for the runtime
kinds and exempts review as "a human declaration without a runtime
anchor". Refusing to sign is not the same as pretending a review
needs a build log.

  $ mathc attest-batch --from=decisions --producer=human:fixture --kind=review > /dev/null 2>&1
  $ python3 -c "
  > import json, glob
  > rows = [json.load(open(p)) for p in sorted(glob.glob('.test-math-coding/attestations/*.json'))]
  > assert all(r['kind_'] == 'review' for r in rows), 'kind'
  > assert all(r['result'] == 'pass' for r in rows), 'result'
  > assert all(r['producer']['identity'] == 'human:fixture' for r in rows), 'producer'
  > assert all(r['subject']['materials_digest'] == '' for r in rows), 'review digest must stay empty'
  > print(len(rows), 'review attestations, empty digest, named producer')
  > "
  12 review attestations, empty digest, named producer

Cleanup.

  $ cd /
  $ rm -rf "$tmpdir"
  $ unset MATH_CODING_DECISIONS_DIR
  $ unset MATH_CODING_ATTESTATIONS_DIR
