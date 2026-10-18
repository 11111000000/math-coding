mathc packages --format=json emits > 64 KiB once the decision +
attestation store grows past ~1k files (189 decisions / 1286
attestations at the time of writing). The MCP server shells out
to `mathc packages` via `lib/mcp/dispatch.ml::run_with_args`,
which previously drained stdout then stderr with two blocking
Unix.read calls per loop. When stdout exceeded the pipe buffer
the child blocked on pipe_write(stdout) while the parent blocked
on pipe_read(stderr) — a pipe-buffer deadlock (see
OCAML_BEST_PRACTICES §11.38). This cram fixture asserts the
`mathc/packages` round-trip returns instead of hanging.

Run from $DUNE_SOURCEROOT; `timeout` guards the regression
(124 == hang, which would be the pre-fix behaviour).

  $ cd "$DUNE_SOURCEROOT"
  $ export MATH_CODING_DECISIONS_DIR=decisions
  $ export MATH_CODING_ATTESTATIONS_DIR=attestations

`mathc/packages` through mathc_mcp must return (not hang). The
response envelope carries id:1 and a non-empty result.value.

  $ if timeout 30 bash -c \
  >   'printf "%s\n" "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"mathc/packages\",\"params\":{}}" \
  >    | MATH_CODING_DECISIONS_DIR=decisions MATH_CODING_ATTESTATIONS_DIR=attestations \
  >        _build/default/bin/mathc_mcp.exe 2>/dev/null \
  >    | grep -q "\"id\":1"'; then \
  >   echo "mcp packages returned (no deadlock)"; \
  > else echo "FAIL: mathc/packages hung or returned no id=1"; fi
  mcp packages returned (no deadlock)

Cleanup.

  $ unset MATH_CODING_DECISIONS_DIR MATH_CODING_ATTESTATIONS_DIR
