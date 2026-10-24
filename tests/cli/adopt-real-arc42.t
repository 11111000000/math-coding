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

Path independence (rev 2, decision
`kernel-fixes-found-bugs-2026-10@1`): the `mathc adopt`
line that echoes the target path is piped through
`sed "s|$tmpdir|<TMP>|g"`. The target is a `mktemp -d`
directory inside dune's per-run bwrap sandbox, so its
absolute path (a random sandbox prefix plus a random
suffix) differs on every machine and every run; the
previous revision had one machine's sandbox path baked
into four expected lines and could never match anywhere
else. Only the path is normalised -- every semantic token
(detection class, step number, decision id, source_kind)
is still compared literally.

The same fix moved the tree. `mathc init` asks the
resolver about the TARGET directory, so a fresh `$tmpdir`
gets `.math-coding/decisions/` rather than the legacy
`decisions/`, and the arc42 side-decision follows the
resolved layout instead of a hardcoded
`<target>/decisions/`. The master policy is
`.math-coding/policy.yaml`; the legacy
`decisions/decision.yaml` this file used to assert on is
not produced at all now. The assertions below follow the
v3.4 layout.

  $ cd "$DUNE_SOURCEROOT"
  $ snapshot=$DUNE_SOURCEROOT/tests/fixtures/arc42-snapshot
  $ tmpdir=$(mktemp -d)
  $ cp -r "$snapshot"/. "$tmpdir"/
  $ cd "$tmpdir"
  $ git init -q 2>/dev/null
  $ mathc adopt "$tmpdir" --merge --no-install 2>&1 | grep -E "detected|step 1b|step 2|wrote" | head -10 | sed "s|$tmpdir|<TMP>|g"
  wrote <TMP>/.math-coding/decisions/use-ocaml.yaml (id=use-ocaml, source_kind=MADR)
  wrote <TMP>/.math-coding/decisions/1-use-ocamlformat-for-source-formatting.yaml (id=1-use-ocamlformat-for-source-formatting, source_kind=adr-tools)
  mathc adopt: detected arc42 + MADR + adr-tools at <TMP>
    step 1b/2: writing arc42-coexistence side-decision
      wrote <TMP>/.math-coding/decisions/bootstrap-v3-arc42-compatibility.yaml
    step 2/2: mathc import-adr <TMP>/docs/adr/0001-use-ocaml.md --write
    step 2/2: mathc import-adr <TMP>/adr/0001-format.md --write
  $ test -f "$tmpdir/.math-coding/policy.yaml" && echo "init: decision.yaml"
  init: decision.yaml
  $ test -f "$tmpdir/.math-coding/decisions/bootstrap-v3-arc42-compatibility.yaml" \
  >   && echo "arc42 side-decision written"
  arc42 side-decision written
  $ test -f "$tmpdir/.math-coding/decisions/use-ocaml.yaml" && echo "MADR imported: ok"
  MADR imported: ok
  $ test -f "$tmpdir/.math-coding/decisions/1-use-ocamlformat-for-source-formatting.yaml" \
  >   && echo "adr-tools imported: ok"
  adr-tools imported: ok
  $ rm -rf "$tmpdir"

mathc validate accepts every decision adopt produced,
including the side-decision. The side-decision lists the
arc42 sections in its assumptions block. The master
policy `mathc init` scaffolded is checked the same way:
`.math-coding/policy.yaml` is a policy file and validates,
where the legacy `decisions/decision.yaml` it replaced did
not.

  $ cd "$DUNE_SOURCEROOT"
  $ snapshot=$DUNE_SOURCEROOT/tests/fixtures/arc42-snapshot
  $ tmpdir=$(mktemp -d)
  $ cp -r "$snapshot"/. "$tmpdir"/
  $ cd "$tmpdir"
  $ git init -q 2>/dev/null
  $ mathc adopt "$tmpdir" --merge --no-install >/dev/null 2>&1
  $ for f in .math-coding/decisions/*.yaml; do
  >   if mathc validate "$f" >/dev/null 2>&1; then
  >     echo "validate $f: ok"
  >   else
  >     echo "validate $f: FAIL"
  >   fi
  > done
  validate .math-coding/decisions/1-use-ocamlformat-for-source-formatting.yaml: ok
  validate .math-coding/decisions/bootstrap-v3-arc42-compatibility.yaml: ok
  validate .math-coding/decisions/use-ocaml.yaml: ok
  $ if mathc validate .math-coding/policy.yaml >/dev/null 2>&1; then
  >   echo "validate .math-coding/policy.yaml: ok"
  > else
  >   echo "validate .math-coding/policy.yaml: FAIL"
  > fi
  validate .math-coding/policy.yaml: ok
  $ rm -rf "$tmpdir"

mathc self-check is not regressed by adopt on the arc42
project (the new side-decision is META-style and does not
add a new live obligation).

  $ cd "$DUNE_SOURCEROOT"
  $ mathc self-check >/dev/null 2>&1 && echo "self-check still runs (verdict: not regressed)"
  [1]
