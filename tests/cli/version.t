mathc exits 0 and prints the bootstrap hello on the canonical
version subcommand. The version string is read from the
`VERSION` file at the project root at run time, so a single
`mathc version` invocation reflects whatever that file
holds. The cram shell's cwd is a bwrap tmp dir; the real
project root is exposed by dune as $DUNE_SOURCEROOT, so the
test references the file via that path. The printed version
must equal the first non-empty line of the VERSION file.

  $ grep -v '^[[:space:]]*$' "$DUNE_SOURCEROOT/VERSION" | head -1
  3.1.0-alpha-final
  $ mathc version
  math-coding 3.1.0-alpha-final: bootstrap
