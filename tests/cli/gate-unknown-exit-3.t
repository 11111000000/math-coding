mathc gate BASE HEAD with no attestation store present (the loader
returns []) emits verdict "unknown" and exits 3. Per
constitution.md Invariants 14 and 14b (exit honesty +
symmetric exit honesty), verdict `Unknown` MUST NOT exit 0;
collapsing it to exit 0 would be `unknown != pass` laundering
that a boolean CI script (`if mathc gate ...; then deploy; fi`)
would silently treat as pass. The new mapping (Unknown -> 3)
mirrors `do_self_check` and is asserted end-to-end here.
Acceptance gate for obligation
verdict-to-exit-matches-self-check in
decisions/exit-code-symmetry-2026-10.yaml@1.

MATH_CODING_DECISIONS_DIR is pinned to the repo's own `decisions/`
because this fixture runs from a temp git repo outside the project
root and `Path_config.resolve_with` probes its candidates relative
to the process cwd, not to MATH_CODING_ROOT. Without the pin the
loader finds no decisions, so the gate would emit `pass` with no
gaps and exit 0 — exactly the laundering this test exists to
forbid. The gap count moves with the live decision set, so the
projection asserts invariants rather than counts.

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
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_DECISIONS_DIR="decisions" MATH_CODING_ATTESTATION_STORE="$tmp/does-not-exist" bash -c 'mathc gate HEAD~1 HEAD > /tmp/gate-unk.out; ec=$?; jq -c "del(.now) | {verdict, gaps_present: ((.gaps | length) > 0), obligations_positive: (.obligations > 0)}" < /tmp/gate-unk.out; echo "exit=$ec"'
  {"verdict":"unknown","gaps_present":true,"obligations_positive":true}
  exit=3
  $ cd /
  $ rm -rf "$tmp"
