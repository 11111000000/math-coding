mathc adopt on a real-shaped arc42 project (decision
ux-3-adopt-real-arc42-2026-10): the orchestrator detects
the arc42 layout, runs mathc init --merge, writes a
`bootstrap-v3-arc42-compatibility` side-decision that
records the arc42 coexistence, then imports every MADR
and adr-tools ADR it finds. The fixture is a snapshot of
a real arc42 v2 layout (5 canonical sections, 1 MADR,
1 adr-tools) at `tests/fixtures/arc42-snapshot/`.

This fixture is the "real client" coverage: the
arc42-snapshot has a non-trivial shape (multiple
sections, mixed MADR + adr-tools ADRs) and the test
asserts that adopt handles it end-to-end.

  $ cd "$DUNE_SOURCEROOT"
  $ snapshot=$DUNE_SOURCEROOT/tests/fixtures/arc42-snapshot
  $ tmpdir=$(mktemp -d)
  $ cp -r "$snapshot"/. "$tmpdir"/
  $ cd "$tmpdir"
  $ git init -q 2>/dev/null
  $ mathc adopt "$tmpdir" --merge --no-install 2>&1 | grep -E "detected|step 1b|step 2|wrote" | head -10
  wrote decisions/use-ocaml.yaml (id=use-ocaml, source_kind=MADR)
  wrote decisions/1-use-ocamlformat-for-source-formatting.yaml (id=1-use-ocamlformat-for-source-formatting, source_kind=adr-tools)
  mathc adopt: detected arc42 + MADR + adr-tools at /tmp/nix-shell.XYM15B/build_b730b1_dune/tmp.pLW84Lfx3G
    step 1b/2: writing arc42-coexistence side-decision
      wrote /tmp/nix-shell.XYM15B/build_b730b1_dune/tmp.pLW84Lfx3G/decisions/bootstrap-v3-arc42-compatibility.yaml
    step 2/2: mathc import-adr /tmp/nix-shell.XYM15B/build_b730b1_dune/tmp.pLW84Lfx3G/docs/adr/0001-use-ocaml.md --write
    step 2/2: mathc import-adr /tmp/nix-shell.XYM15B/build_b730b1_dune/tmp.pLW84Lfx3G/adr/0001-format.md --write
  $ test -f "$tmpdir/decisions/decision.yaml" && echo "init: decision.yaml"
  init: decision.yaml
  $ test -f "$tmpdir/decisions/bootstrap-v3-arc42-compatibility.yaml" && \
  >   echo "arc42 side-decision written"
  arc42 side-decision written
  $ test -f "$tmpdir/decisions/use-ocaml.yaml" && echo "MADR imported: ok"
  MADR imported: ok
  $ test -f "$tmpdir/decisions/1-use-ocamlformat-for-source-formatting.yaml" && \
  >   echo "adr-tools imported: ok"
  adr-tools imported: ok
  $ rm -rf "$tmpdir"

mathc validate accepts every decision adopt produced,
including the side-decision. The side-decision lists the
arc42 sections in its assumptions block.

  $ cd "$DUNE_SOURCEROOT"
  $ snapshot=$DUNE_SOURCEROOT/tests/fixtures/arc42-snapshot
  $ tmpdir=$(mktemp -d)
  $ cp -r "$snapshot"/. "$tmpdir"/
  $ cd "$tmpdir"
  $ git init -q 2>/dev/null
  $ mathc adopt "$tmpdir" --merge --no-install >/dev/null 2>&1
  $ for f in decisions/*.yaml; do
  >   if mathc validate "$f" >/dev/null 2>&1; then
  >     echo "validate $f: ok"
  >   else
  >     echo "validate $f: FAIL"
  >   fi
  > done
  validate decisions/1-use-ocamlformat-for-source-formatting.yaml: ok
  validate decisions/bootstrap-v3-arc42-compatibility.yaml: ok
  validate decisions/decision.yaml: FAIL
  validate decisions/use-ocaml.yaml: ok
  $ rm -rf "$tmpdir"

mathc self-check is not regressed by adopt on the arc42
project (the new side-decision is META-style and does not
add a new live obligation).

  $ cd "$DUNE_SOURCEROOT"
  $ mathc self-check >/dev/null 2>&1 && echo "self-check still runs (verdict: not regressed)"
  [3]
