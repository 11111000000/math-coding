mathc re-evaluate-decisions writes post-run attestations into
the canonical MATH_CODING_ATTESTATIONS_DIR rather than the
legacy MATH_CODING_ATTESTATION_STORE. Per F10 fix #3 in
decisions/path-resolver-audit-2026-11.yaml the dispatcher
now calls resolve_store_root (defined at lib/Mathc.ml:2991)
for both read and write so the two flows can no longer
diverge.

Setup: a tmpdir project with .math-coding/decisions/ and
.math-coding/attestations/. Export
MATH_CODING_ATTESTATIONS_DIR=.math-coding/attestations so
attestations land in the env-var path, NOT the legacy
`attestations/` at the project root.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ cp dune-project "$tmpdir/"
  $ mkdir -p "$tmpdir/.math-coding/decisions" "$tmpdir/.math-coding/attestations"
  $ cp -r decisions/3-2-cli-catalog.yaml "$tmpdir/.math-coding/decisions/"
  $ export MATH_CODING_ROOT="$tmpdir"
  $ export MATH_CODING_DECISIONS_DIR=".math-coding/decisions"
  $ export MATH_CODING_ATTESTATIONS_DIR=".math-coding/attestations"
  $ unset MATH_CODING_ATTESTATION_STORE || true

`mathc re-evaluate-decisions A0` emits per-obligation
attestations into the env-var-resolved store.

  $ mathc re-evaluate-decisions A0 >/dev/null
  $ test -d "$tmpdir/.math-coding/attestations" \
  >   && echo "store dir exists: ok"
  store dir exists: ok
  $ ls "$tmpdir/.math-coding/attestations/" | head -1 | grep -qE 't1-2-A0-3-2-cli-catalog' \
  >   && echo "post-run attestations landed in env-var store: ok"
  post-run attestations landed in env-var store: ok
  $ test ! -d "$tmpdir/attestations" \
  >   && echo "no legacy store write: ok"
  no legacy store write: ok

Cleanup.

  $ cd /
  $ rm -rf "$tmpdir"
