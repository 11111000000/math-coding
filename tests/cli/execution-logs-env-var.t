mathc record writes execution-log events to the path-resolver's
decisions_dir, and mathc stats reads from the same location.
Per F10 fix #2 in decisions/path-resolver-audit-2026-11.yaml the
resolve_* helpers in lib/path_config.ml own the path; the
defaults honour env MATH_CODING_DECISIONS_DIR first.

Setup: a tmpdir project with `dune-project`, .math-coding/decisions/
directory, an empty attestation store. Export
MATH_CODING_DECISIONS_DIR=.math-coding/decisions to override the
pre-fix hardcoded path. MATH_CODING_ROOT pins find_project_root
to the scratch tree.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ cp dune-project "$tmpdir/"
  $ mkdir -p "$tmpdir/.math-coding/decisions" "$tmpdir/.math-coding/attestations"
  $ export MATH_CODING_ROOT="$tmpdir"
  $ export MATH_CODING_DECISIONS_DIR=".math-coding/decisions"
  $ export MATH_CODING_ATTESTATIONS_DIR=".math-coding/attestations"
  $ export MATH_CODING_FIXED_TIME=2026-11-01T00:00:00Z
  $ export MATH_CODING_USER=human:test@local

`mathc session-start` anchors the wall-clock so `record` accepts
the event without MC-SESSION-MISSING.

  $ mathc session-start >/dev/null

`mathc record --class feature-add` writes the event line to
`<root>/<MATH_CODING_DECISIONS_DIR>/execution-logs.jsonl`,
NOT to the legacy `decisions/execution-logs.jsonl`.

  $ mathc record --decision-id bootstrap-v3 --scale step-count --value 7 >/dev/null
  $ test -f "$tmpdir/.math-coding/decisions/execution-logs.jsonl" \
  >   && echo "wrote to .math-coding/: ok"
  wrote to .math-coding/: ok
  $ test ! -f "$tmpdir/decisions/execution-logs.jsonl" \
  >   && echo "no legacy write: ok"
  no legacy write: ok

`mathc stats` reads from the same resolver-resolved path. The
sample count includes the just-recorded event (n=1).

  $ mathc stats --scale step-count | jq -c '{n, p50: .quantiles.p50}'
  {"n":1,"p50":null}

Cleanup.

  $ cd /
  $ rm -rf "$tmpdir"
