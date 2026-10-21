mathc precommit batch-validates every `decisions/*.yaml` (or the
explicit path list) by shelling out to `mathc validate` per file.
The exit code is the worst of the per-file exit codes (0 if all
accept, 1 if any reject, 2 if any input error).

Each case uses the live project root as cwd so that the
`decisions/` directory is populated.

`mathc precommit` (no args) walks decisions/*.yaml and emits a
one-line summary plus a per-file verdict. The exact file count
and per-bucket counts drift as new decisions land; the assertion
locks the summary shape, not the numeric content:

  $ cd "$DUNE_SOURCEROOT"
  $ if ec=$(mathc precommit > /tmp/precommit-all.txt 2>/dev/null; echo $?); then \
  >   [[ "$ec" =~ ^[012]$ ]] && echo "exit=$ec in {0,1,2}: ok"; \
  > else echo "FAIL: mathc precommit aborted"; fi
  exit=0 in {0,1,2}: ok
  $ head -1 /tmp/precommit-all.txt | grep -qE '^mathc precommit: [0-9]+ files: [0-9]+ accepted, [0-9]+ rejected, [0-9]+ input-err$'
  $ test "$(grep -cE ': (accept|parse-ok)$' /tmp/precommit-all.txt)" -gt 0 && echo "verdict rows present: ok"
  verdict rows present: ok

Single-file mode (`mathc precommit FILE`) treats the file as a
single-item batch. The tracked file
`decisions/mathc-counters-subcommand-2026-10.yaml` is well-formed
and accepts (the per-file verdict stays `accept`
in `precommit`'s human output; only `validate` switched its token
to `parse-ok`):

  $ cd "$DUNE_SOURCEROOT"
  $ mathc precommit decisions/mathc-counters-subcommand-2026-10.yaml
  mathc precommit: 1 files: 1 accepted, 0 rejected, 0 input-err
    decisions/mathc-counters-subcommand-2026-10.yaml: accept

`mathc precommit nonexistent.yaml` exits 2 (input error from
the underlying mathc validate; the file does not exist):

  $ cd "$DUNE_SOURCEROOT"
  $ mathc precommit /tmp/nonexistent-precommit.yaml > /dev/null 2>/dev/null; ec=$?; echo "exit=$ec"
  exit=2

`mathc precommit --format=json` emits a JSON object on stdout
(per-file verdicts + counts). The shape includes `total`,
`accepted`, `rejected`, `input_err`, and a `files[]` array.

  $ tmpj=$(mktemp -d)/precommit-one.json
  $ cd "$DUNE_SOURCEROOT"
  $ mathc precommit --format=json decisions/mathc-counters-subcommand-2026-10.yaml \
  >   2>/dev/null > "$tmpj"
  $ grep -q '"total":1' "$tmpj" \
  >   && grep -q '"accepted":1' "$tmpj" \
  >   && grep -q '"rejected":0' "$tmpj" \
  >   && grep -q '"input_err":0' "$tmpj" \
  >   && grep -q '"files":\[{"exit_code":0,"path"' "$tmpj" \
  >   && echo "json shape: ok"
  json shape: ok
