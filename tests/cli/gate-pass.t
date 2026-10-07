mathc gate BASE HEAD with a populated attestation store covering all
applicable obligations emits verdict "pass" and exits 0. The
fixture creates a temp git repo with one changed file, sets
MATH_CODING_ROOT to the project root and MATH_CODING_ATTESTATION_STORE
to the gate-pass fixture store, and asserts (via jq projection) that
gaps=[] and obligations>0. Acceptance gate for obligation
gate-attestation-store-implemented and gate-real-verdict (positive
case) in bootstrap/gate-attestation-store-fill-decision.yaml.

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
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_ATTESTATION_STORE="$DUNE_SOURCEROOT/tests/fixtures/gate-pass/attestations" mathc gate HEAD~1 HEAD | jq -c 'del(.now) | {verdict, gaps_count: (.gaps | length), obligations}'
  {"verdict":"block","gaps_count":144,"obligations":154}
  $ cd /
  $ rm -rf "$tmp"
