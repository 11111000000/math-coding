Verify command: walk acceptance.all[*].verifier strings and
execute them in a sandbox, returning per-obligation verdicts.

The verify command is registered in mathc as of v3.4.0-dev and
emits a per-obligation pass | fail | skipped. The exit code
is 0 when all obligations pass, 1 when any fail, 2 on input
errors (path unreadable, malformed YAML).

  $ mathc verify --help
  usage: mathc verify FILE [--format=...]
  
  $ mathc verify "$DUNE_SOURCEROOT/fixtures/conformance/decision/positive-minimal.json"
  verify: .*positive-minimal.json (re)
  .* (re)

The accept/parse-ok rename is verified by validate:

  $ mathc validate "$DUNE_SOURCEROOT/fixtures/conformance/decision/positive-minimal.json" | head -1
  parse-ok: .*positive-minimal.json (re)
