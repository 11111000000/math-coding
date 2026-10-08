mathc gate BASE HEAD with an attestation store whose entries include
a decisive fail attestation for one obligation emits verdict
"block" and exits 1 (constitution.md Invariant 14 — exit honesty).
The remaining obligations either pass or surface as
MissingEvidence; the aggregate ignores MissingEvidence and treats
only FailedEvidence as the blocking signal per the
gate-attestation-store-fill commitment. Acceptance gate for
obligation gate-real-verdict (negative case) and
gate-exit-honest in bootstrap/gate-attestation-store-fill-decision.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ git init -q
  $ git config user.email "t@t"
  $ git config user.name "t"
  $ echo a > a.txt
  $ git add . && git commit -q -m initial
  $ echo b > b.txt
  $ git add . && git commit -q -m second
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_ATTESTATION_STORE="$DUNE_SOURCEROOT/tests/fixtures/gate-fail/attestations" bash -c 'mathc gate HEAD~1 HEAD > /tmp/gate-fail.out; ec=$?; jq -c "del(.now) | {verdict, has_failed_gap: ([.gaps[].kind] | any(. == \"FailedEvidence\")), obligations}" < /tmp/gate-fail.out; echo "exit=$ec"'
  {"verdict":"block","has_failed_gap":true,"obligations":183}
  exit=1
  $ cd /
  $ rm -rf "$tmp"
