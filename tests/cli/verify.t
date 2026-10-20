Verify command: walk acceptance.all[*].verifier strings and
execute them in a sandbox, returning per-obligation verdicts.

The verify command is registered in mathc as of v3.4.0-dev and
emits a per-obligation pass | fail | skipped. The exit code
is 0 when all obligations pass, 1 when any fail, 2 on input
errors (path unreadable, malformed YAML).

The `--sandbox=MODE` flag (verify-sandbox-hardening-2026-11)
is registered after `--format` and exercised separately in
tests/cli/verify-sandbox-*.t. The manual usage line passed
to Arg.parse does not enumerate it (kernel behaviour; the
flag itself appears in the auto-generated option list).

  $ cd "$DUNE_SOURCEROOT"
  $ mathc verify --help
  usage: mathc verify FILE [--format=...]
    --format  Output format: text (default) or json
    --sandbox  Sandbox mode: none|minimal|strict (default from MATH_CODING_VERIFY_SANDBOX or 'none'). Strict applies RLIMIT_NPROC=1 NOFILE=64 FSIZE + closes inherited FDs; Linux only - falls back with a warning on macOS.
    -help  Display this list of options
    --help  Display this list of options

  $ mathc verify fixtures/conformance/decision/positive-minimal.json 2>/dev/null
  verify: fixtures/conformance/decision/positive-minimal.json
    bounded-fallback-amplification: skipped

The accept/parse-ok rename is verified by validate:

  $ mathc validate fixtures/conformance/decision/positive-minimal.json 2>/dev/null | head -1
  parse-ok: fixtures/conformance/decision/positive-minimal.json
