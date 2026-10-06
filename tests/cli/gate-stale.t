mathc gate BASE HEAD with an attestation store whose only candidate
attestation carries a stale materials_digest emits verdict
"unknown" (Kernel Invariant 9 — freshness) and exits 0. The
stale attestation's obligation surfaces as a StaleEvidence gap;
other obligations without attestations surface as MissingEvidence.
Both gap kinds are non-blocking per the gate-attestation-store-fill
commitment ("block if any obligation fails, pass if every
applicable obligation passes, unknown otherwise"). Acceptance gate
for obligation gate-real-verdict (negative case) in
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
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_ATTESTATION_STORE="$DUNE_SOURCEROOT/tests/fixtures/gate-stale/attestations" mathc gate HEAD~1 HEAD | jq -c 'del(.now) | {verdict, has_stale_gap: ([.gaps[].kind] | any(. == "StaleEvidence")), obligations}'
  {"verdict":"unknown","has_stale_gap":true,"obligations":100}
  $ cd /
  $ rm -rf "$tmp"
