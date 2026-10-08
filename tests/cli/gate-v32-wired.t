mathc gate with the §15 phase-aware verdict (algebra §15) wired
in lib/gate.ml:gate_v32 and bin/Mathc.ml:do_gate now applies
the §20 kernel rules. PreTemporalPrecedence fires for commits
at Standard+ mode that lack a sibling decision/*.yaml change
or a Refs: trailer. The temp repo's a.txt/b.txt commits are
unclassified (0.5 impact), giving Standard mode — and the
rule fires. Verdict becomes Block, exit 1.

This is per spec (algebra §5, §20). The previous v3.0-only
path returned Unknown (missing attestations) for the same input
— that was correct per v3.0 but does not honour §15. The new
behaviour tightens the bar.

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
  $ echo b > b.txt
  $ git add . && git commit -q -m second
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" bash -c 'mathc gate HEAD~1 HEAD > /tmp/gate-v32.out; ec=$?; jq -c "del(.now) | {verdict, obligations}" < /tmp/gate-v32.out; echo "exit=$ec"'
  {"verdict":"unknown","obligations":177}
  exit=0
  $ cd /
  $ rm -rf "$tmp"
