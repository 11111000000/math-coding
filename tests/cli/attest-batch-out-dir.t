`mathc attest-batch` writes into the wrong place, or crashes, or
poisons the store. Three defects, pinned here.

1. The output directory is resolved through
 `lib/path_config.ml` (env-var → `.math-coding/` when it exists →
 legacy `attestations/` → synthesised default), NOT a hardcoded
 `.math-coding/attestations`. A legacy-layout project therefore
 gets its attestations next to its decisions instead of in a
 second, empty tree.
2. Missing parent directories are created (`mkdir -p`). The
 previous single-level `Unix.mkdir` left `mathc: internal error:
 Unix.Unix_error(Unix.ENOENT, "mkdir", ...)` on any fresh target.
3. A manifest header row (`decision_id<TAB>obligation_id<TAB>...`),
 pasted out of a Markdown table, is skipped rather than parsed as
 data. It used to emit `decision_id-obligation_id.json` — an
 attestation naming a decision that does not exist.

All cases are hermetic: they `cd` into a fresh `mktemp -d` and use
relative paths, so the expectations carry no host-specific prefix.

Nested output directory that does not exist yet: created, no crash.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d) && cd "$tmp"
  $ export MATH_CODING_ROOT="$tmp"
  $ printf 'd1\to1\treview\thuman:me\n' > m.tsv
  $ mathc attest-batch --manifest=m.tsv --out=a/b/c 2>&1 | sed 's|^wrote |wrote |'
  wrote a/b/c/d1-o1.json
  $ test -f a/b/c/d1-o1.json && echo "nested out dir: created"
  nested out dir: created

A header row is skipped; the data row after it is emitted.

  $ printf 'decision_id\tobligation_id\tkind_\tproducer_identity\tresult\nd1\to1\treview\thuman:me\tpass\n' > h.tsv
  $ mathc attest-batch --manifest=h.tsv --out=hdr 2>&1
  wrote hdr/d1-o1.json
  $ test ! -f hdr/decision_id-obligation_id.json && echo "no header artefact"
  no header artefact
  $ ls hdr | wc -l
  1

An invalid `kind_` is refused with the schema enum in the message.

  $ printf 'd1\to1\trevew\thuman:me\tpass\n' > k.tsv
  $ if mathc attest-batch --manifest=k.tsv --out=bad 2>/dev/null; then
  >   echo "FAIL: expected exit 2 on bad kind"; exit 1
  > else
  >   echo "bad kind refused (exit $?)"
  > fi
  bad kind refused (exit 2)
  $ mathc attest-batch --manifest=k.tsv --out=bad 2>&1 | grep -q 'kind_ must be one of test|review|build|analysis|observation' && echo "enum named in the diagnostic"
  enum named in the diagnostic
  $ test ! -d bad && echo "nothing written on a refused manifest"
  nothing written on a refused manifest

An invalid `result` is refused the same way.

  $ printf 'd1\to1\treview\thuman:me\tmaybe\n' > r.tsv
  $ if mathc attest-batch --manifest=r.tsv --out=bad2 2>/dev/null; then
  >   echo "FAIL: expected exit 2 on bad result"; exit 1
  > else
  >   echo "bad result refused (exit $?)"
  > fi
  bad result refused (exit 2)

`--kind` on the --from=decisions path is validated against the same
enum (it previously accepted anything and wrote an unloadable file).

  $ if mathc attest-batch --from=none --kind=nope 2>/dev/null; then
  >   echo "FAIL: expected exit 2 on bad --kind"; exit 1
  > else
  >   echo "bad --kind refused (exit $?)"
  > fi
  bad --kind refused (exit 2)

An unwritable output directory is an exit-2 diagnostic naming the
path, not `mathc: internal error`.

  $ if mathc attest-batch --manifest=m.tsv --out=/proc/x/y 2>"$tmp/ab.err"; then
  >   echo "FAIL: expected non-zero exit on unwritable out"; exit 1
  > else
  >   echo "unwritable out refused (exit $?)"
  > fi
  unwritable out refused (exit 2)
  $ grep -q 'mathc attest-batch: cannot create /proc/x/y' "$tmp/ab.err" && echo "diagnostic names the path"
  diagnostic names the path
  $ rm -f "$tmp/ab.err"

`--from=decisions` reads the decisions dir through the resolver: in
this scratch project the default `.math-coding/decisions` does not
exist and neither does the legacy one, so the walker reports nothing
rather than silently reading the repository the harness runs in.

  $ if mathc attest-batch --from=decisions --producer=human:integration-test --dry-run >/dev/null 2>"$tmp/ab2.err"; then
  >   echo "FAIL: expected exit 2 with no decisions"; exit 1
  > else
  >   echo "empty project refused (exit $?)"
  > fi
  empty project refused (exit 2)
  $ grep -q 'no parseable decisions under .*\.math-coding/decisions' "$tmp/ab2.err" && echo "scanner reports the resolved dir"
  scanner reports the resolved dir
  $ rm -f "$tmp/ab2.err"

Cleanup.

  $ cd /
  $ rm -rf "$tmp"
