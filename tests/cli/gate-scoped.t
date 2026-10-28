mathc gate's DEFAULT is now the merge gate -- the change's question, with
the checks run -- and this fixture pins that default beside the AUDIT
path (`--no-scope --no-execute`, the whole corpus read from the store)
and the `--no-execute` escape hatch, which runs nothing at all.
Acceptance fixture for decisions/gate-scoped-default-2026-10.yaml.

The gate used to ask one question -- is the whole historical corpus
still satisfied -- on every commit. Measured on this repository on
2026-10-27: a commit that touched eight files was checked against 962
obligations, produced 826 gaps, and the verdict was `block`. The
verdict was not wrong; it was answering a question nobody asked, and
it made the gate unusable as a merge gate.

This fixture builds its OWN git repository with its OWN decisions, so
it does not depend on the project's history, and it pins five things
that a corpus-sized fixture could only pin as inequalities:

1. `--scope` evaluates FEWER obligations than the unscoped gate --
4 against 6 here, from the same tree and the same store. The
untouched decision's two obligations are not in the change's
question, so the scoped gate does not ask them.

2. `--execute` runs the touched decisions' verifiers ON THE
CANDIDATE TREE, and the check that fails says so: the gap kind is
`FailedEvidence`, the verdict is `block`, the exit code is 1. The
sibling obligation, whose second verifier could not even be set up,
is NOT reported as satisfied -- it is an `Unknown` gap, because "the
check could not be run" and "the check passed" are different facts
and the gate must not confuse them.

3. A verifier that CANNOT BE SET UP is a failure, not a crash. A
`dir-exists` verifier naming a directory that does not exist used to
kill the whole gate with `mathc: internal error: Sys_error(...)`,
exit 3 and no JSON document at all, because `Sys.is_directory`
raises on a missing path where `Sys.file_exists` answers false. The
gate runs verifiers, so a verifier that crashes the gate takes the
gate with it. Here it is a `FailedEvidence` gap and a verdict.

4. `--no-execute` runs NOTHING: the marker file the failing verifier
writes is absent, and the store's record decides. It is a VETO, not a
toggle -- it wins over `--execute` whatever the order of the flags --
because the switch exists for a gate that is invoked from inside a
test, where a verifier that runs `dune runtest` inside a `dune
runtest` recurses until it times out.

5. The DEFAULT is the merge gate: `mathc gate BASE HEAD` with no
switches at all asks the change's question AND runs the checks, and
the document it prints is the document `--scope --execute` prints --
same obligation count, same gap kinds, same verdict, same exit code.
`--no-scope` restores the wider question: the whole corpus, six
obligations against the default's four.

The exact JSON keys of the gate's document are pinned too, so a
future revision that renames `obligations` or `verdict` fails here
rather than in a consumer.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ export tmp
  $ cd "$tmp"
  $ cat > dune-project <<'EOF'
  > (lang dune 3.21)
  > (cram enable)
  > EOF
  $ git init -q
  $ git config user.email "t@t"
  $ git config user.name "t"
  $ mkdir -p decisions scripts attestations
  $ cat > decisions/scoped-decision.yaml <<'YAML'
  > ---
  > schema: math-coding/3.2
  > id: scoped-decision
  > revision: 1
  > state: active
  > mode: light
  > intent: |
  >   A fixture decision whose scope names the file the change
  >   touches, and nothing else.
  > commitment: |
  >   The scope of this decision is exactly `scoped.txt`.
  > outcomes:
  >   - id: o
  >     statement: s
  > scope:
  >   paths:
  >     - "scoped.txt"
  > obligations:
  >   - id: probe-fails
  >     claim: |
  >       A verifier that runs and fails.
  >     acceptance:
  >       all:
  >         - verifier: scripts/failing-probe.sh
  >           result: pass
  >   - id: dir-missing
  >     claim: |
  >       A verifier that cannot be set up is a failure, not a crash.
  >     acceptance:
  >       all:
  >         - verifier: dir-exists src
  >           result: pass
  >   - id: declared-by-a-human
  >     claim: |
  >       An obligation no program can check: a human's word. The
  >       store's record is the evidence for it, and the store holds
  >       one.
  >     acceptance:
  >       all:
  >         - verifier: manual-a-human-looked
  >           result: pass
  >   - id: sibling-cannot-be-set-up
  >     claim: |
  >       One verifier passes and one cannot be set up. The obligation
  >       must not come out satisfied.
  >     acceptance:
  >       all:
  >         - verifier: file-exists scoped.txt
  >           result: pass
  >         - verifier: scripts/does-not-exist.sh
  >           result: pass
  > assumptions: []
  > reversal: []
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > counterexample: |
  >   n/a
  > YAML
  $ cat > decisions/untouched-decision.yaml <<'YAML'
  > ---
  > schema: math-coding/3.2
  > id: untouched-decision
  > revision: 1
  > state: active
  > mode: light
  > intent: |
  >   A fixture decision whose scope names a file the change does NOT
  >   touch.
  > commitment: |
  >   The scope of this decision is exactly `untouched.txt`.
  > outcomes:
  >   - id: o
  >     statement: s
  > scope:
  >   paths:
  >     - "untouched.txt"
  > obligations:
  >   - id: untouched-one
  >     claim: |
  >       A claim.
  >     acceptance:
  >       all:
  >         - verifier: manual-one
  >           result: pass
  >   - id: untouched-two
  >     claim: |
  >       A claim.
  >     acceptance:
  >       all:
  >         - verifier: manual-two
  >           result: pass
  > assumptions: []
  > reversal: []
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > counterexample: |
  >   n/a
  > YAML
  $ printf '#!/bin/sh\necho ran > marker.txt\nexit 1\n' > scripts/failing-probe.sh
  $ chmod +x scripts/failing-probe.sh
  $ cat > attestations/scoped-decision-declared-by-a-human.json <<'JSON'
  > {
  >   "id": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
  >   "issued_at": "2026-10-28T00:00:00Z",
  >   "kind": "attestation",
  >   "kind_": "review",
  >   "producer": {"identity": "human:fixture"},
  >   "result": "pass",
  >   "schema": "math-coding/attestation-3.3",
  >   "subject": {
  >     "candidate_tree": "0000000000000000000000000000000000000000",
  >     "decision": "scoped-decision",
  >     "materials_digest": "",
  >     "obligation": "declared-by-a-human"
  >   }
  > }
  > JSON
  $ echo one > scoped.txt
  $ echo two > untouched.txt
  $ git add -A && git commit -q -m initial
  $ echo changed > scoped.txt
  $ git add -A && git commit -q -m second
  $ git log --oneline | wc -l
  2

The AUDIT path -- `--no-scope --no-execute` -- asks every active
decision and reads the store: six obligations, five gaps, verdict
`unknown`, exit 3. The document's keys are pinned: a revision that
renames one of them fails here.

  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" bash -c 'mathc gate --no-scope --no-execute HEAD~1 HEAD > "$tmp/all.json" 2> "$tmp/all.err"; ec=$?; jq -c "{keys: keys, obligations, gaps: (.gaps|length), verdict}" < "$tmp/all.json"; echo "exit=$ec"; echo "stderr_bytes=$(wc -c < "$tmp/all.err")"; echo "marker=$(test -f "$tmp/marker.txt" && echo present || echo absent)"'
  {"keys":["base","gaps","head","now","obligations","verdict"],"obligations":6,"gaps":5,"verdict":"unknown"}
  exit=3
  stderr_bytes=0
  marker=absent

The scoped gate asks only the decision whose scope names the changed
file: four obligations, three gaps. Two fewer obligations are
evaluated, and the untouched decision's two obligations are not in the
question at all. `--no-execute` keeps the store's record in charge, so
this question differs from the audit one in scope and not in what ran.

  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" bash -c 'mathc gate --scope --no-execute HEAD~1 HEAD > "$tmp/scoped.json" 2> "$tmp/scoped.err"; ec=$?; jq -c "{obligations, gaps: (.gaps|length), ids: [.gaps[].obligation_id], verdict}" < "$tmp/scoped.json"; echo "exit=$ec"; echo "marker=$(test -f "$tmp/marker.txt" && echo present || echo absent)"'
  {"obligations":4,"gaps":3,"ids":["probe-fails","dir-missing","sibling-cannot-be-set-up"],"verdict":"unknown"}
  exit=3
  marker=absent

`--no-execute` runs NOTHING and the store's record decides. The
verdict and the exit code are the scoped gate's, and the marker file
the failing verifier would have written is absent: no verifier ran.

  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" bash -c 'mathc gate --scope --no-execute HEAD~1 HEAD > "$tmp/noexec.json" 2> "$tmp/noexec.err"; ec=$?; jq -c "{obligations, gaps: (.gaps|length), kinds: [.gaps[].kind], verdict}" < "$tmp/noexec.json"; echo "exit=$ec"; echo "stderr_bytes=$(wc -c < "$tmp/noexec.err")"; echo "marker=$(test -f "$tmp/marker.txt" && echo present || echo absent)"'
  {"obligations":4,"gaps":3,"kinds":["MissingEvidence","MissingEvidence","MissingEvidence"],"verdict":"unknown"}
  exit=3
  stderr_bytes=0
  marker=absent

`--no-execute` is a VETO, not a toggle: it wins over `--execute`
whatever the order of the flags. A gate invoked from inside a test
has to be able to say "run nothing" and have that hold.

  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" bash -c 'mathc gate --scope --execute --no-execute HEAD~1 HEAD > "$tmp/veto1.json" 2>/dev/null; echo "exit=$?"; jq -c "{obligations, kinds: [.gaps[].kind], verdict}" < "$tmp/veto1.json"; echo "marker=$(test -f "$tmp/marker.txt" && echo present || echo absent)"'
  exit=3
  {"obligations":4,"kinds":["MissingEvidence","MissingEvidence","MissingEvidence"],"verdict":"unknown"}
  marker=absent
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" bash -c 'mathc gate --scope --no-execute --execute HEAD~1 HEAD > "$tmp/veto2.json" 2>/dev/null; echo "exit=$?"; jq -c "{obligations, kinds: [.gaps[].kind], verdict}" < "$tmp/veto2.json"; echo "marker=$(test -f "$tmp/marker.txt" && echo present || echo absent)"'
  exit=3
  {"obligations":4,"kinds":["MissingEvidence","MissingEvidence","MissingEvidence"],"verdict":"unknown"}
  marker=absent

`--execute` runs the touched decisions' verifiers on the candidate
tree. The failing verifier RAN: the marker file is there, the gate
says so on stderr, and the obligation is a `FailedEvidence` gap -- a
check that ran and failed, not a check that could not be run. The
verdict is `block` and the exit code is 1. The `dir-exists` verifier
naming a directory that does not exist is a `FailedEvidence` gap too,
NOT a crash: the gate printed a verdict.

This invocation deliberately runs the checks, and so does the default
one below it: their verifiers are a `sh` script and path checks on
files and directories, and none of them can recurse into `dune
runtest` the way a verifier that runs the suite would. A gate that
runs the suite inside the suite is exactly what `--no-execute` exists
for, and it is why every invocation here that only asks a question
carries it.

  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" bash -c 'mathc gate --scope --execute HEAD~1 HEAD > "$tmp/exec.json" 2> "$tmp/exec.err"; ec=$?; jq -c "{obligations, gaps: (.gaps|length), kinds: [.gaps[].kind], ids: [.gaps[].obligation_id], verdict}" < "$tmp/exec.json"; echo "exit=$ec"; echo "verifier_reported=$(grep -c "exited 1" "$tmp/exec.err")"; echo "crashed=$(grep -c "internal error" "$tmp/exec.err")"; echo "marker=$(test -f "$tmp/marker.txt" && echo present || echo absent)"'
  {"obligations":4,"gaps":3,"kinds":["FailedEvidence","FailedEvidence","Unknown"],"ids":["probe-fails","dir-missing","sibling-cannot-be-set-up"],"verdict":"block"}
  exit=1
  verifier_reported=1
  crashed=0
  marker=present

The DEFAULT is the merge gate, and the default is what every caller
gets who types nothing: `mathc gate BASE HEAD` with no switches at all
asks the change's question AND runs the checks. Its document is the
document `--scope --execute` prints -- same obligation count, same gap
kinds, same verdict, same exit code -- and the marker file is written
again, so the verifiers ran under the default too.

  $ rm -f "$tmp/marker.txt"
  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" bash -c 'mathc gate HEAD~1 HEAD > "$tmp/default.json" 2> "$tmp/default.err"; ec=$?; jq -c "{obligations, gaps: (.gaps|length), kinds: [.gaps[].kind], ids: [.gaps[].obligation_id], verdict}" < "$tmp/default.json"; echo "exit=$ec"; echo "verifier_reported=$(grep -c "exited 1" "$tmp/default.err")"; echo "marker=$(test -f "$tmp/marker.txt" && echo present || echo absent)"'
  {"obligations":4,"gaps":3,"kinds":["FailedEvidence","FailedEvidence","Unknown"],"ids":["probe-fails","dir-missing","sibling-cannot-be-set-up"],"verdict":"block"}
  exit=1
  verifier_reported=1
  marker=present

The two documents are the same document: once the timestamp is removed,
the default's output and `--scope --execute`'s output are identical.

  $ jq -S -c 'del(.now)' < "$tmp/exec.json" > "$tmp/exec.norm"
  $ jq -S -c 'del(.now)' < "$tmp/default.json" > "$tmp/default.norm"
  $ [ "$(cat "$tmp/exec.norm")" = "$(cat "$tmp/default.norm")" ] && echo identical
  identical

`--no-scope` restores the wider question: the whole corpus, not the
decisions this change touches. Everything else is the default's, so
the obligation count is the difference between the two questions -- six
against four -- and the default's count is the narrow one.

  $ MATH_CODING_ROOT="$tmp" MATH_CODING_ATTESTATION_STORE="$tmp/attestations" bash -c 'mathc gate --no-scope HEAD~1 HEAD > "$tmp/noscope.json" 2> "$tmp/noscope.err"; ec=$?; jq -c "{obligations, gaps: (.gaps|length), verdict}" < "$tmp/noscope.json"; echo "exit=$ec"'
  {"obligations":6,"gaps":5,"verdict":"block"}
  exit=1

The two runs are the same tree, the same store and the same four
obligations, and they differ in exactly one thing -- whether the
checks ran. The failing obligation is `FailedEvidence` when the check
ran and `MissingEvidence` when it did not.

  $ jq -c '[.gaps[].kind]' < "$tmp/exec.json"
  ["FailedEvidence","FailedEvidence","Unknown"]
  $ jq -c '[.gaps[].kind]' < "$tmp/noexec.json"
  ["MissingEvidence","MissingEvidence","MissingEvidence"]

The store's record settles the obligation that no program can check:
`declared-by-a-human` names a `manual-` declaration, so no check
exists for it, and the store's attestation for it is why it produces
no gap in EITHER run. A gate that executed nothing and a gate that
executed everything agree on it, because the evidence for it is a
human's word and not a check.

  $ jq -c '[.gaps[].obligation_id]' < "$tmp/exec.json"
  ["probe-fails","dir-missing","sibling-cannot-be-set-up"]
  $ jq -c '[.gaps[].obligation_id]' < "$tmp/noexec.json"
  ["probe-fails","dir-missing","sibling-cannot-be-set-up"]

The switch is named in the usage string, so a reader of `mathc gate
--help` learns that it exists without reading the source.

  $ mathc gate --help 2>&1 | head -1
  usage: mathc gate [--scope|--no-scope] [--execute|--no-execute] BASE HEAD
  $ mathc gate --help 2>&1 | grep -c -- "--no-execute"
  2

  $ cd /
  $ rm -rf "$tmp"
