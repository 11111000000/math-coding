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
  $ $INSIDE_DUNE/bin/mathc.exe telemetry status
  mathc telemetry: off
    transport: not configured (Phase 2 stub; tracked: decisions/ux-3-telemetry-stub-2026-10.yaml)
    See decisions/ux-3-telemetry-stub-2026-10.yaml.
    No data is collected or transmitted by this build.

Opt-in: MATHCODING_TELEMETRY=on -> "on" (no actual emission).

  $ cd "$DUNE_SOURCEROOT"
  $ MATHCODING_TELEMETRY=on $INSIDE_DUNE/bin/mathc.exe telemetry status
  mathc telemetry: on
    transport: not configured (Phase 2 stub; tracked: decisions/ux-3-telemetry-stub-2026-10.yaml)
    See decisions/ux-3-telemetry-stub-2026-10.yaml.
    No data is collected or transmitted by this build.

Other truthy values (1, true) also resolve to "on".

  $ cd "$DUNE_SOURCEROOT"
  $ MATHCODING_TELEMETRY=1 $INSIDE_DUNE/bin/mathc.exe telemetry status | head -1
  mathc telemetry: on
  $ MATHCODING_TELEMETRY=true $INSIDE_DUNE/bin/mathc.exe telemetry status | head -1
  mathc telemetry: on

Falsy values (off, 0, false) resolve to "off".

  $ cd "$DUNE_SOURCEROOT"
  $ MATHCODING_TELEMETRY=off $INSIDE_DUNE/bin/mathc.exe telemetry status | head -1
  mathc telemetry: off
  $ MATHCODING_TELEMETRY=0 $INSIDE_DUNE/bin/mathc.exe telemetry status | head -1
  mathc telemetry: off
  $ MATHCODING_TELEMETRY=false $INSIDE_DUNE/bin/mathc.exe telemetry status | head -1
  mathc telemetry: off

Unknown values: reported verbatim as `unknown (VALUE)`.

  $ cd "$DUNE_SOURCEROOT"
  $ MATHCODING_TELEMETRY=maybe $INSIDE_DUNE/bin/mathc.exe telemetry status | head -1
  mathc telemetry: unknown (maybe)

Unknown subcommand: exit 2 with help.

  $ cd "$DUNE_SOURCEROOT"
  $ if $INSIDE_DUNE/bin/mathc.exe telemetry bogus 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on unknown subcommand"; exit 1
  > else
  >   echo "unknown subcommand refused (exit $?)"
  > fi
  unknown subcommand refused (exit 2)

No data file is written or read.

  $ cd "$DUNE_SOURCEROOT"
  $ test ! -f .local/telemetry.jsonl && echo "no telemetry file written"
  no telemetry file written
