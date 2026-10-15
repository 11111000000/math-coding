mathc init scaffolds a new math-coding project: creates
decisions/, attestations/, and decisions/decision.yaml, and
installs a pre-commit hook unless --no-install. Refuses on
arc42/MADR/adr-tools presence unless --merge is passed.

The cram shell's cwd is a bwrap tmp dir. mathc is on the PATH
(deps %{bin:mathc} in tests/cli/dune). Each case creates a
fresh mktemp dir, runs `mathc init <dir>`, then asserts on
the output and on the resulting directory tree.

Empty directory: init succeeds and creates the expected files.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mathc init "$tmpdir" --no-install
  mathc init: created /tmp/nix-shell.U1N979/build_feb560_dune/tmp.KPL1rmmOsi/decisions, /tmp/nix-shell.U1N979/build_feb560_dune/tmp.KPL1rmmOsi/attestations
    decision.yaml: schema math-coding/3.2, scope paths editable
    pre-commit hook: skipped (--no-install)
  $ test -d "$tmpdir/decisions" && echo "decisions/: ok"
  decisions/: ok
  $ test -d "$tmpdir/attestations" && echo "attestations/: ok"
  attestations/: ok
  $ test ! -d "$tmpdir/.githooks" && echo ".githooks: absent (--no-install ok)"
  .githooks: absent (--no-install ok)
  $ grep -q 'schema: math-coding/3.2' "$tmpdir/decisions/decision.yaml" && \
  >   echo "decision.yaml: schema-string ok"
  decision.yaml: schema-string ok
  $ rm -rf "$tmpdir"

Brownfield (arc42): init refuses with exit 3 and a clear message.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mkdir -p "$tmpdir/docs/arc42"
  $ if mathc init "$tmpdir" 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on brownfield"; exit 1
  > else
  >   echo "init refused on brownfield (exit $?)"
  > fi
  init refused on brownfield (exit 3)
  $ test ! -d "$tmpdir/decisions" && echo "no decisions/ created on refuse"
  no decisions/ created on refuse
  $ rm -rf "$tmpdir"

Brownfield with --merge: init proceeds.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mkdir -p "$tmpdir/docs/arc42"
  $ mathc init "$tmpdir" --merge --no-install
  mathc init: created /tmp/nix-shell.U1N979/build_feb560_dune/tmp.TxfDto0ing/decisions, /tmp/nix-shell.U1N979/build_feb560_dune/tmp.TxfDto0ing/attestations
    decision.yaml: schema math-coding/3.2, scope paths editable
    pre-commit hook: skipped (--no-install)
  $ test -f "$tmpdir/decisions/decision.yaml" && echo "decision.yaml created with --merge"
  decision.yaml created with --merge
  $ rm -rf "$tmpdir"

Refuse to overwrite existing decision.yaml without --merge.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mkdir -p "$tmpdir/decisions" && echo 'old' > "$tmpdir/decisions/decision.yaml"
  $ if mathc init "$tmpdir" --no-install 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on existing decision.yaml"; exit 1
  > else
  >   echo "init refused to overwrite (exit $?)"
  > fi
  init refused to overwrite (exit 3)
  $ grep -q '^old$' "$tmpdir/decisions/decision.yaml" && \
  >   echo "original decision.yaml preserved"
  original decision.yaml preserved
  $ rm -rf "$tmpdir"

Unknown --agent value: exit 2 with help.

  $ cd "$DUNE_SOURCEROOT"
  $ if mathc init /tmp --agent bogus 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on unknown agent"; exit 1
  > else
  >   echo "unknown agent refused (exit $?)"
  > fi
  unknown agent refused (exit 2)
  $ if mathc init /tmp --agent bogus 2>&1 | grep -q 'expected: generic'; then
  >   echo "error message lists valid agent values"
  > else
  >   echo "FAIL: error message missing valid agent list"; exit 1
  > fi
  error message lists valid agent values

`mathc init --with-ci-workflow` copies templates/ci.yml into
.github/workflows/ci.yml. The decision
`ux-3-init-with-ci-workflow-2026-10` is the activation record
for this slice; the surface test pins the filesystem state.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mathc init "$tmpdir" --no-install --with-ci-workflow > /dev/null 2>&1
  $ test -f "$tmpdir/.github/workflows/ci.yml" && echo "ci.yml: present"
  ci.yml: present
  $ grep -q '^name: math-coding' "$tmpdir/.github/workflows/ci.yml" \
  >   && echo "ci.yml: name field matches template"
  ci.yml: name field matches template
  $ rm -rf "$tmpdir"

`mathc init` (default, without --with-ci-workflow) does NOT
create .github/workflows/ci.yml. The flag is opt-in: pre-init
adopters already have a workflow and shouldn't be surprised
by an unsolicited rewrite.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ mathc init "$tmpdir" --no-install > /dev/null 2>&1
  $ test ! -e "$tmpdir/.github" \
  >   && echo ".github: absent (default opt-out ok)"
  .github: absent (default opt-out ok)
  $ rm -rf "$tmpdir"

