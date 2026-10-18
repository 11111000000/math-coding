mathc import-junit --help prints the usage line for the canonical
JUnit XML parser and exits 0. The help text that lists subcommands
(`mathc --help`) leads with `import-junit FILE` and notes `attest`
as a deprecated alias, so agents and humans discover both names
without separate lookups.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc import-junit --help
  usage: mathc import-junit FILE
    -help  Display this list of options
    --help  Display this list of options

The canonical `import-junit` line appears in the subcommand listing
of `mathc --help` with the description "parse FILE as a JUnit XML
report", and the next three continuation lines name `attest` as a
deprecated alias.

  $ mathc --help | grep -A3 'import-junit FILE'
    import-junit FILE                parse FILE as a JUnit XML report
  (canonical name; `attest` is a
  deprecated alias emitting a
  stderr warning)

The deprecated alias `attest --help` is still routable and also
points users to the canonical name: the usage string printed
upstream of the deprecation warning names `import-junit`.

  $ mathc attest --help
  warning: 'mathc attest FILE' is deprecated; use 'mathc import-junit FILE' for JUnit XML parsing. (plans/2026-11-adoption-fixes §4 B1)
  usage: mathc import-junit FILE
    -help  Display this list of options
    --help  Display this list of options
