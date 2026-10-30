mathc gate --no-scope --no-execute BASE HEAD -- the AUDIT question: every
active decision, read from the store, with no verifier run -- with an
attestation store whose only candidate attestation carries a stale
materials_digest emits verdict "unknown" (Kernel Invariant 9 —
freshness). The stale attestation's obligation surfaces as a
StaleEvidence gap; other obligations without attestations surface as
MissingEvidence.
Neither gap kind is decisive, so the verdict stays `unknown` (exit
3) rather than flipping to pass. Acceptance gate for obligation
gate-real-verdict (negative case) in
bootstrap/gate-attestation-store-fill-decision.yaml.

MATH_CODING_DECISIONS_DIR is pinned to the repo's own `decisions/`
because this fixture runs from a temp git repo outside the project
root and `Path_config.resolve_with` probes its candidates relative
to the process cwd, not to MATH_CODING_ROOT. Without the pin the
loader finds no decisions at all and the gate reports
`obligations: 0` / verdict `pass`. The obligation and gap counts
move with the live decision set, so the projection asserts
invariants rather than counts.

The gate's default is now the scoped, executing merge gate. This fixture
asks the AUDIT question -- every active decision, read from the store --
and says so with `--no-scope`, and it runs no verifier at all with
`--no-execute`: a verifier that runs `dune runtest` inside a `dune
runtest` recurses until the test times out.

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
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_DECISIONS_DIR="decisions" MATH_CODING_ATTESTATION_STORE="$DUNE_SOURCEROOT/tests/fixtures/gate-stale/attestations" bash -c '$INSIDE_DUNE/bin/mathc.exe gate --no-scope --no-execute HEAD~1 HEAD > /tmp/gate-stale.out; ec=$?; jq -c "del(.now) | {verdict, has_stale_gap: (.gaps_by_kind.StaleEvidence > 0), no_failed_gap: ((.gaps_by_kind.FailedEvidence // 0) == 0), obligations_positive: (.obligations > 0)}" < /tmp/gate-stale.out; echo "exit=$ec"'
  {"verdict":"unknown","has_stale_gap":true,"no_failed_gap":true,"obligations_positive":true}
  exit=3
  $ cd /
  $ rm -rf "$tmp"
