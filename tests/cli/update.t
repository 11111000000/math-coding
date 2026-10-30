`mathc update [--channel=stable|edge|<ver>] [--yes]` is the
self-update subcommand (decision `mathc-update-subcommand-2026-10`).
It shells out to `scripts/install-tooling/install.sh` (POSIX) or
`install.ps1` (Windows) with `--version=<resolved>`. The companion
flag on `mathc version` is `--check`, which exits 0 when the locally
installed version matches the latest stable release and exits 1
(printing the newer tag) when an upgrade is available.

This fixture exercises the documented flag set on `mathc update
--help`, the user-declined path (`mathc update` with empty stdin,
exit 1), the default `mathc version --check` (exit 0 on a tree
whose VERSION matches the upstream latest tag), and the unknown-
channel error path (exit 2).

  $ cd "$DUNE_SOURCEROOT"
  $ $INSIDE_DUNE/bin/mathc.exe update --help
  usage: mathc update [--channel=stable|edge|<ver>] [--yes]
  
  Replaces the installed mathc binary by shelling out to
  scripts/install-tooling/install.sh (POSIX) or install.ps1
  (Windows) with --version=<resolved>.
  
  options:
    --channel=stable        default; resolves to the latest v*.*.* tag
    --channel=edge          install the rolling `edge` build
    --channel=vX.Y.Z        pin to a specific tag
    --yes                   skip the confirmation prompt
  
  exit codes:
    0   install succeeded
    1   user declined (no --yes)
    2   input error (unknown --channel value)
    3   network or filesystem error

`mathc update` without `--yes` and with empty stdin prints the
prompt, then declines; exit 1. This guards against silent mutation
of the installed binary.

  $ cd "$DUNE_SOURCEROOT"
  $ printf '' | $INSIDE_DUNE/bin/mathc.exe update
  mathc update: replace the installed mathc binary? [y/N] mathc update: declined; no changes made
  [1]

`mathc version --check` exits 0 when the local VERSION matches the
upstream latest stable tag (no output) and exits 1 (printing the
newer tag) when an upgrade is available. On a tree whose VERSION
equals the latest upstream tag, the exit is 0 with empty stdout.

  $ cd "$DUNE_SOURCEROOT"
  $ $INSIDE_DUNE/bin/mathc.exe version --check

The `--check` path must not regress the default `mathc version`
output. The version banner stays unchanged.

The banner carries `math-coding <VERSION>: bootstrap`, where
`<VERSION>` is whatever lives at the top of `$DUNE_SOURCEROOT/VERSION`
(the kernel reads it at startup). We sed-normalise `<VERSION>`
to `<VER>` so the banner does not pin a stale literal when the
repo's VERSION is bumped.

  $ cd "$DUNE_SOURCEROOT"
  $ version=$(grep -v '^\s*$' "$DUNE_SOURCEROOT/VERSION" | head -1)
  $ $INSIDE_DUNE/bin/mathc.exe version 2>&1 | sed "s|${version}|<VER>|g"
  math-coding <VER>: bootstrap

`mathc update --channel=bogus` rejects unknown channels with exit 2
(input error). Guards against typo'd channel names.

  $ cd "$DUNE_SOURCEROOT"
  $ $INSIDE_DUNE/bin/mathc.exe update --channel=bogus --yes
  mathc update: unknown channel: bogus (expected stable|edge|v<X.Y.Z>)
  [2]
