mathc exits 0 and prints the bootstrap hello on the canonical
version subcommand. The cram shell's cwd is a bwrap tmp dir; the
real project root is exposed by dune as $DUNE_SOURCEROOT, so tests
reference fixtures via "$DUNE_SOURCEROOT/fixtures/...". Cram
captures stdout, so the output contains the absolute path; expected
lines below use `*` glob (or `(re)` regexes) to match the path
prefix without baking a user-specific worktree location into the
.t file.

  $ mathc version
  math-coding 3.0-alpha: bootstrap
