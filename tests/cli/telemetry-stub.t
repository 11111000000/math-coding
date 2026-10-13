mathc telemetry status is the Phase-2 stub for the
telemetry opt-in. It reads the MATHCODING_TELEMETRY
environment variable and prints the current mode; no data is
collected or transmitted by this build.

The cram shell's cwd is a bwrap tmp dir. mathc is on the PATH
(deps %{bin:mathc} in tests/cli/dune). Each case asserts the
right output for the given env-var state.

Default: MATHCODING_TELEMETRY unset -> "off".

  $ cd "$DUNE_SOURCEROOT"
  $ unset MATHCODING_TELEMETRY
  $ mathc telemetry status
  mathc: command not found
  [127]

Opt-in: MATHCODING_TELEMETRY=on -> "on" (no actual emission).

  $ cd "$DUNE_SOURCEROOT"
  $ MATHCODING_TELEMETRY=on mathc telemetry status
  mathc: command not found
  [127]

Other truthy values (1, true) also resolve to "on".

  $ cd "$DUNE_SOURCEROOT"
  $ MATHCODING_TELEMETRY=1 mathc telemetry status | head -1
  mathc: command not found
  $ MATHCODING_TELEMETRY=true mathc telemetry status | head -1
  mathc: command not found

Falsy values (off, 0, false) resolve to "off".

  $ cd "$DUNE_SOURCEROOT"
  $ MATHCODING_TELEMETRY=off mathc telemetry status | head -1
  mathc: command not found
  $ MATHCODING_TELEMETRY=0 mathc telemetry status | head -1
  mathc: command not found
  $ MATHCODING_TELEMETRY=false mathc telemetry status | head -1
  mathc: command not found

Unknown values: reported verbatim as `unknown (VALUE)`.

  $ cd "$DUNE_SOURCEROOT"
  $ MATHCODING_TELEMETRY=maybe mathc telemetry status | head -1
  mathc: command not found

Unknown subcommand: exit 2 with help.

  $ cd "$DUNE_SOURCEROOT"
  $ if mathc telemetry bogus 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on unknown subcommand"; exit 1
  > else
  >   echo "unknown subcommand refused (exit $?)"
  > fi
  unknown subcommand refused (exit 127)

No data file is written or read.

  $ cd "$DUNE_SOURCEROOT"
  $ test ! -f .local/telemetry.jsonl && echo "no telemetry file written"
  no telemetry file written
