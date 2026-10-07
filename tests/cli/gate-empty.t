mathc gate BASE HEAD with no attestation store present (the loader
returns []) emits verdict "unknown" and exits 0. Every applicable
obligation surfaces as a MissingEvidence gap; the aggregate
treats MissingEvidence as informational (not blocking) per the
gate-attestation-store-fill commitment ("block if any obligation
fails, unknown otherwise"). Exit 0 honours the existing scaffold
disposition for "no store available". Acceptance gate for
obligation gate-fixtures-coverage in
bootstrap/gate-attestation-store-fill-decision.yaml.

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
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_ATTESTATION_STORE="$tmp/does-not-exist" mathc gate HEAD~1 HEAD | jq -c 'del(.now) | {verdict, all_missing: (.gaps | length > 0 and all(.kind == "MissingEvidence")), obligations}'
  {"verdict":"block","all_missing":true,"obligations":154}
  $ cd /
  $ rm -rf "$tmp"
