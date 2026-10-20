mathc adopt is the brownfield-adoption subcommand. It
detects the project's existing ADR convention (arc42 / MADR /
adr-tools / mixed / none) and runs the right
mathc-init / mathc-import-adr sequence. This fixture
exercises the detection-driven orchestration.

The cram shell's cwd is a bwrap tmp dir. mathc is on the PATH
(deps %{bin:mathc} in tests/cli/dune). Each case creates a
fresh mktemp dir with a brownfield layout, runs `mathc adopt`,
and asserts on the result.

Every `mathc adopt` line that echoes the target path is piped
through `sed "s|$tmpdir|<TMP>|g"` before comparison. The target
is a `mktemp -d` dir whose absolute path lives inside dune's
per-run bwrap sandbox (`/tmp/nix-shell.XXXXXX/build_...`), so
it differs on every machine and every run; the previous
expectations had one machine's sandbox path baked in and could
never match anywhere else. Only the path is normalised -- every
semantic token (exit code, detection class, step, decision id)
is still compared literally.

Each case runs from $DUNE_SOURCEROOT. Rev 2
(`decisions/kernel-fixes-found-bugs-2026-10@1`): `mathc init` asks
the resolver about the TARGET dir, not about the process cwd, so a
fresh `$tmpdir` gets the v3.4 `.math-coding/` tree instead of
inheriting this repository's legacy `decisions/`. Rev 1 documented
that inheritance as if it were the design; it was the bug. The
`adopt` sub-commands also inherit `MATH_CODING_ROOT=<target>`, so
imported ADRs land in the project being adopted rather than in
whatever repository the operator was standing in.

MADR + adr-tools project: adopt imports all ADRs.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mkdir -p "$tmpdir/docs/adr" "$tmpdir/adr"
  $ cat > "$tmpdir/docs/adr/0001-postgres.md" <<EOF
  > # 1. Use PostgreSQL
  > 
  > ## Status
  > 
  > Accepted
  > 
  > ## Context
  > 
  > We need a primary DB.
  > 
  > ## Decision
  > 
  > PostgreSQL.
  > EOF
  $ cat > "$tmpdir/adr/0001-foo.md" <<EOF
  > # 1. Foo
  > 
  > ## Status
  > 
  > Accepted
  > 
  > ## Context
  > 
  > Foo.
  > 
  > ## Decision
  > 
  > Foo.
  > EOF
  $ mathc adopt "$tmpdir" --merge --no-install > adopt.log 2>&1
  $ sed "s|$tmpdir|<TMP>|g" adopt.log | grep -E 'step|detected'
  mathc adopt: detected MADR + adr-tools at <TMP>
    step 1/2: mathc init (scaffold math-coding in <TMP>)
    step 2/2: mathc import-adr <TMP>/docs/adr/0001-postgres.md --write
    step 2/2: mathc import-adr <TMP>/adr/0001-foo.md --write
  $ sed "s|$tmpdir|<TMP>|g" adopt.log | grep -c '^wrote <TMP>/.math-coding/decisions/'
  2
  $ test -f "$tmpdir/.math-coding/policy.yaml" && echo "decision.yaml: created"
  decision.yaml: created
  $ test -f "$tmpdir/.math-coding/decisions/1-use-postgresql.yaml" && echo "MADR imported: ok"
  MADR imported: ok
  $ test -f "$tmpdir/.math-coding/decisions/1-foo.yaml" && echo "adr-tools imported: ok"
  adr-tools imported: ok
  $ rm -rf "$tmpdir"

Empty project: adopt does NOT refuse. The brownfield gate is
scoped to non-empty projects only: `--merge bypass the
brownfield refuse (default: refuse on non-empty; empty projects
always pass)` (decisions/ux-3-adopt-subcommand-2026-10, Flags).
The kernel implements it as `let pass_merge = match kind with
Detect.Empty -> true | _ -> !merge in` in bin/Mathc.ml::do_adopt.

An empty target therefore takes the greenfield path -- `mathc
init` with no --merge -- and exits 0. The previous expectation
here asserted a non-zero exit, which the kernel never produced
for Detect.Empty; the refusal it meant to cover is exercised in
the next block, where the target really is a brownfield.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mathc adopt "$tmpdir" --no-install >/dev/null 2>&1; echo "exit=$?"
  exit=0
  $ test -f "$tmpdir/.math-coding/policy.yaml" && echo "empty: init ran ok"
  empty: init ran ok
  $ rm -rf "$tmpdir"

Non-empty brownfield without --merge: adopt refuses with exit 3
and scaffolds nothing. This is the refusal the empty case above
is explicitly exempt from.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mkdir -p "$tmpdir/docs/adr"
  $ printf '# 1. Keep the DB\n\n## Status\n\nAccepted\n\n## Context\n\nc\n\n## Decision\n\nd\n' > "$tmpdir/docs/adr/0001-db.md"
  $ mathc adopt "$tmpdir" --no-install 2>&1 >/dev/null | sed "s|$tmpdir|<TMP>|g"
  mathc adopt: refusing to proceed in brownfield project; pass --merge to override.
  $ mathc adopt "$tmpdir" --no-install >/dev/null 2>&1; echo "exit=$?"
  exit=3
  $ test ! -d "$tmpdir/decisions" && echo "refused: nothing scaffolded"
  refused: nothing scaffolded
  $ rm -rf "$tmpdir"

--only=arc42: only the arc42 convention is adopted, even when
MADR and adr-tools are also present.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mkdir -p "$tmpdir/docs/arc42" "$tmpdir/docs/adr" "$tmpdir/adr"
  $ echo "test" > "$tmpdir/docs/adr/0001-madr.md"
  $ echo "test" > "$tmpdir/adr/0001-adr.md"
  $ mathc adopt "$tmpdir" --merge --no-install --only=arc42 2>&1 | grep -E "step 2|wrote" | head | sed "s|$tmpdir|<TMP>|g"
      wrote <TMP>/.math-coding/decisions/bootstrap-v3-arc42-compatibility.yaml
  $ test ! -f "$tmpdir/.math-coding/decisions/1-madr.yaml" && echo "--only=arc42 skipped MADR"
  --only=arc42 skipped MADR
  $ test ! -f "$tmpdir/.math-coding/decisions/1-adr.yaml" && echo "--only=arc42 skipped adr-tools"
  --only=arc42 skipped adr-tools
  $ test -f "$tmpdir/.math-coding/policy.yaml" && echo "init still ran (arc42)"
  init still ran (arc42)
  $ rm -rf "$tmpdir"

Dry-run: prints what would be done, does not run anything.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mkdir -p "$tmpdir/docs/adr"
  $ echo "test" > "$tmpdir/docs/adr/0001.md"
  $ mathc adopt "$tmpdir" --merge --no-install --dry-run 2>&1 | grep -E "step|detected" | sed "s|$tmpdir|<TMP>|g"
  mathc adopt: detected MADR (docs/adr/) at <TMP>
    step 1/2: mathc init (scaffold math-coding in <TMP>)
    step 2/2: mathc import-adr <TMP>/docs/adr/0001.md --write
  $ test ! -f "$tmpdir/.math-coding/policy.yaml" && echo "dry-run: nothing written"
  dry-run: nothing written
  $ rm -rf "$tmpdir"
