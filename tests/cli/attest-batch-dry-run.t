mathc attest-batch --dry-run prints one canonical-JSON attestation per
row to stdout and does NOT write any files. This is the operator's
preview path: a non-destructive way to verify the manifest before
committing to the attestation store.

The exact JSON shape (sort_keys, no whitespace, ensure_ascii=False)
MUST match what `--manifest` + `--out` writes — the `dry-run` flag
only changes the I/O destination, not the per-row payload.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d) && cd "$tmpdir"
  $ mkdir -p .math-coding/attestations  # present but empty
  $ before=$(ls .math-coding/attestations | wc -l)
  $ mathc attest-batch \
  >   --manifest="$DUNE_SOURCEROOT/tests/cli/fixtures/attest-batch/manifest.tsv" \
  >   --dry-run > /tmp/attest-batch-dry-run.stdout.jsonl

Three lines of stdout, one per manifest row.

  $ python3 -c "
  > import sys
  > n = 0
  > for line in open('/tmp/attest-batch-dry-run.stdout.jsonl'):
  >     assert line.endswith('\n'), repr(line)
  >     assert line.count('{') == line.count('}'), line
  >     n += 1
  > assert n == 3, n
  > print('dry-run rows:', n)
  > "
  dry-run rows: 3

No files were created in the attestations directory. The dry-run
is non-destructive: pre-existing files (if any) are NOT modified
either.

  $ after=$(ls .math-coding/attestations | wc -l)
  $ test "$before" = "$after" && echo "dry-run: file count unchanged ($before)"
  dry-run: file count unchanged (0)

The JSON shape is the same as the written file: parse the stdout
JSON and assert the `id` equals SHA-256 of the canonical body
(excluding `id`). This is the same rule the write-mode enforces
(see tests/cli/attest-batch-positive.t for the write-side check).

  $ python3 -c "
  > import hashlib, json
  > ok = 0
  > for line in open('/tmp/attest-batch-dry-run.stdout.jsonl'):
  >     d = json.loads(line)
  >     body = {k: v for k, v in d.items() if k != 'id'}
  >     payload = json.dumps(body, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
  >     expected = 'sha256:' + hashlib.sha256(payload).hexdigest()
  >     assert d['id'] == expected, (d['subject'], d['id'], expected)
  >     ok += 1
  > print('dry-run rows with valid id:', ok)
  > "
  dry-run rows with valid id: 3
  $ rm -f /tmp/attest-batch-dry-run.stdout.jsonl

  $ cd "$DUNE_SOURCEROOT"
  $ rm -rf "$tmpdir"
