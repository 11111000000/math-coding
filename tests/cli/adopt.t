mathc adopt is the brownfield-adoption subcommand. It
detects the project's existing ADR convention (arc42 / MADR /
adr-tools / mixed / none) and runs the right
mathc-init / mathc-import-adr sequence. This fixture
exercises the detection-driven orchestration.

The cram shell's cwd is a bwrap tmp dir. mathc is on the PATH
(deps %{bin:mathc} in tests/cli/dune). Each case creates a
fresh mktemp dir with a brownfield layout, runs `mathc adopt`,
and asserts on the result.

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
  $ mathc adopt "$tmpdir" --merge --no-install 2>&1 | grep -E "step|detected|wrote" | head -10
  wrote decisions/1-use-postgresql.yaml (id=1-use-postgresql, source_kind=adr-tools)
  wrote decisions/1-foo.yaml (id=1-foo, source_kind=adr-tools)
  mathc adopt: detected MADR + adr-tools at /tmp/nix-shell.j0fxYM/build_14c89f_dune/tmp.HSnQ54QwBB
    step 1/2: mathc init (scaffold math-coding in /tmp/nix-shell.j0fxYM/build_14c89f_dune/tmp.HSnQ54QwBB)
    step 2/2: mathc import-adr /tmp/nix-shell.j0fxYM/build_14c89f_dune/tmp.HSnQ54QwBB/docs/adr/0001-postgres.md --write
    step 2/2: mathc import-adr /tmp/nix-shell.j0fxYM/build_14c89f_dune/tmp.HSnQ54QwBB/adr/0001-foo.md --write
  $ test -f "$tmpdir/decisions/decision.yaml" && echo "decision.yaml: created"
  decision.yaml: created
  $ test -f "$tmpdir/decisions/1-postgresql.yaml" && echo "MADR imported: ok"
  [1]
  $ test -f "$tmpdir/decisions/1-foo.yaml" && echo "adr-tools imported: ok"
  [1]
  $ rm -rf "$tmpdir"

Empty project: adopt refuses without --merge, equivalent to init with --merge.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ if mathc adopt "$tmpdir" 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on empty brownfield"; exit 1
  > else
  >   echo "empty brownfield refused (exit $?)"
  > fi
  mathc init: created /tmp/nix-shell.j0fxYM/build_14c89f_dune/tmp.49cXuLqarZ/decisions, /tmp/nix-shell.j0fxYM/build_14c89f_dune/tmp.49cXuLqarZ/attestations
    decision.yaml: schema math-coding/3.2, scope paths editable
    pre-commit hook: installed at .githooks/pre-commit
  mathc adopt: detected empty at /tmp/nix-shell.j0fxYM/build_14c89f_dune/tmp.49cXuLqarZ
    step 1/2: mathc init (scaffold math-coding in /tmp/nix-shell.j0fxYM/build_14c89f_dune/tmp.49cXuLqarZ)
  mathc adopt: done
  FAIL: expected non-zero exit on empty brownfield
  ***** UNREACHABLE *****
  $ mathc adopt "$tmpdir" --merge --no-install 2>&1 | grep -E "detected|step 1" | head
  ***** UNREACHABLE *****
  $ test -f "$tmpdir/decisions/decision.yaml" && echo "empty: init ran ok"
  ***** UNREACHABLE *****
  $ rm -rf "$tmpdir"
  ***** UNREACHABLE *****

--only=arc42: only the arc42 convention is adopted, even when
MADR and adr-tools are also present.

  $ cd "$DUNE_SOURCEROOT"
  ***** UNREACHABLE *****
  $ tmpdir=$(mktemp -d)
  ***** UNREACHABLE *****
  $ mkdir -p "$tmpdir/docs/arc42" "$tmpdir/docs/adr" "$tmpdir/adr"
  ***** UNREACHABLE *****
  $ echo "test" > "$tmpdir/docs/adr/0001-madr.md"
  ***** UNREACHABLE *****
  $ echo "test" > "$tmpdir/adr/0001-adr.md"
  ***** UNREACHABLE *****
  $ mathc adopt "$tmpdir" --merge --no-install --only=arc42 2>&1 | grep -E "step 2|wrote" | head
  ***** UNREACHABLE *****
  $ test ! -f "$tmpdir/decisions/1-madr.yaml" && echo "--only=arc42 skipped MADR"
  ***** UNREACHABLE *****
  $ test ! -f "$tmpdir/decisions/1-adr.yaml" && echo "--only=arc42 skipped adr-tools"
  ***** UNREACHABLE *****
  $ test -f "$tmpdir/decisions/decision.yaml" && echo "init still ran (arc42)"
  ***** UNREACHABLE *****
  $ rm -rf "$tmpdir"
  ***** UNREACHABLE *****

Dry-run: prints what would be done, does not run anything.

  $ cd "$DUNE_SOURCEROOT"
  ***** UNREACHABLE *****
  $ tmpdir=$(mktemp -d)
  ***** UNREACHABLE *****
  $ mkdir -p "$tmpdir/docs/adr"
  ***** UNREACHABLE *****
  $ echo "test" > "$tmpdir/docs/adr/0001.md"
  ***** UNREACHABLE *****
  $ mathc adopt "$tmpdir" --merge --no-install --dry-run 2>&1 | grep -E "step|detected"
  ***** UNREACHABLE *****
  $ test ! -f "$tmpdir/decisions/decision.yaml" && echo "dry-run: nothing written"
  ***** UNREACHABLE *****
  $ rm -rf "$tmpdir"
  ***** UNREACHABLE *****
