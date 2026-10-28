mathc gate --no-scope --no-execute -- the AUDIT question: every active
decision, read from the store, with no verifier run -- with the §15
phase-aware verdict (algebra §15) wired in lib/gate.ml:gate_v32 and
bin/Mathc.ml:do_gate now applies the §20 kernel rules, and `do_gate`
composes the two verdicts (phase-aware Block wins, otherwise the v3.0
attestation verdict stands).

Scenario 1 — protected path (`lib/`) with no sibling decision
file and no `Refs:` trailer: the §20 `CoCommitDecision` rule
fires and the composed verdict is Block, exit 1. This is the
positive case for the §15/§20 wiring (per spec/algebra-3.2.md
§5, §20): a kernel change without a co-committed decision is a
knownable violation, not an unknown one.

Scenario 2 — unclassified paths (`a.txt`, `b.txt`, risk mode
`tiny` per `mathc mode`): no §20 rule applies (the change touches
no protected path and the mode is below the PreTemporalPrecedence
threshold), so the composed verdict falls back to the v3.0
attestation path: unknown, exit 3. The earlier claim that this
input blocks came from the Standard-mode reading; the kernel
classifies these paths as `tiny`.

MATH_CODING_DECISIONS_DIR and MATH_CODING_POLICY are pinned to the
repo's own `decisions/` and `policies.yaml` because this fixture
runs from a temp git repo outside the project root and
`Path_config.resolve_with` probes its candidates relative to the
process cwd, not to MATH_CODING_ROOT. Without the pins the loader
finds no decisions and no policy floors, so no §20 rule can fire
and the gate reports `obligations: 0` / verdict `pass`. The
obligation count moves with the live decision set, so the
projection asserts invariants rather than counts.

The gate's default is now the scoped, executing merge gate. This fixture
asks the AUDIT question -- every active decision, read from the store --
and says so with `--no-scope`, and it runs no verifier at all with
`--no-execute`: a verifier that runs `dune runtest` inside a `dune
runtest` recurses until the test times out.

Acceptance gate for §15 wiring in
decisions/3-2-cli-catalog.yaml (mode subcommand catalog) and
decisions/algebra-3.2.yaml (the 3.2-ideal algebra itself).

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ git init -q
  $ git config user.email "t@t"
  $ git config user.name "t"
  $ echo a > a.txt
  $ git add . && git commit -q -m initial
  $ mkdir -p lib
  $ echo 'let x = 1' > lib/foo.ml
  $ git add . && git commit -q -m "kernel change without a decision"
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_DECISIONS_DIR="decisions" MATH_CODING_POLICY="policies.yaml" bash -c 'mathc gate --no-scope --no-execute HEAD~1 HEAD > /tmp/gate-v32-block.out; ec=$?; jq -c "del(.now) | {verdict, obligations_positive: (.obligations > 0)}" < /tmp/gate-v32-block.out; echo "exit=$ec"'
  {"verdict":"block","obligations_positive":true}
  exit=1
  $ echo c > c.txt
  $ git add . && git commit -q -m third
  $ echo d > d.txt
  $ git add . && git commit -q -m fourth
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_DECISIONS_DIR="decisions" MATH_CODING_POLICY="policies.yaml" MATH_CODING_ATTESTATION_STORE="$tmp/does-not-exist" bash -c 'mathc gate --no-scope --no-execute HEAD~1 HEAD > /tmp/gate-v32.out; ec=$?; jq -c "del(.now) | {verdict, gaps_present: ((.gaps | length) > 0), obligations_positive: (.obligations > 0)}" < /tmp/gate-v32.out; echo "exit=$ec"'
  {"verdict":"unknown","gaps_present":true,"obligations_positive":true}
  exit=3
  $ cd /
  $ rm -rf "$tmp"
