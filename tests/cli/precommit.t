mathc precommit batch-validates every `decisions/*.yaml` (or the
explicit path list) by shelling out to `mathc validate` per file.
The exit code is the worst of the per-file exit codes (0 if all
accept, 1 if any reject, 2 if any input error).

Each case uses the live project root as cwd so that the
`decisions/` directory is populated.

`mathc precommit` (no args) walks decisions/*.yaml and emits a
one-line summary plus a per-file verdict. The fixture project
has 9 known-rejects (per `mathc validate` of the live tree),
so the exit code is 1.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc precommit > /tmp/precommit-all.txt 2>/dev/null; ec=$?; echo "exit=$ec"
  exit=1
  $ head -1 /tmp/precommit-all.txt
  mathc precommit: 127 files: 118 accepted, 9 rejected, 0 input-err
  $ test "$(grep -c ': accept$' /tmp/precommit-all.txt)" -gt 0 && echo "accept rows present: ok"
  accept rows present: ok

Single-file mode (`mathc precommit FILE`) treats the file as a
single-item batch. The live fixture file `decisions/1-foo.yaml`
is well-formed and accepts.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc precommit decisions/1-foo.yaml
  mathc precommit: 1 files: 1 accepted, 0 rejected, 0 input-err
    decisions/1-foo.yaml: accept

`mathc precommit nonexistent.yaml` exits 2 (input error from
the underlying mathc validate; the file does not exist).

  $ cd "$DUNE_SOURCEROOT"
  $ mathc precommit /tmp/nonexistent-precommit.yaml > /dev/null 2>/dev/null; ec=$?; echo "exit=$ec"
  exit=2

`mathc precommit --format=json` emits a JSON object on stdout
(per-file verdicts + counts). The shape includes `total`,
`accepted`, `rejected`, `input_err`, and a `files[]` array.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc precommit --format=json decisions/1-foo.yaml \
  >   2>/dev/null > /tmp/precommit-one.json
  $ grep -q '"total":1' /tmp/precommit-one.json \
  >   && grep -q '"accepted":1' /tmp/precommit-one.json \
  >   && grep -q '"rejected":0' /tmp/precommit-one.json \
  >   && grep -q '"input_err":0' /tmp/precommit-one.json \
  >   && grep -q '"files":\[{"exit_code":0,"path"' /tmp/precommit-one.json \
  >   && echo "json shape: ok"
  json shape: ok
