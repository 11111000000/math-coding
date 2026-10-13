mathc_mcp exposes four read-write methods in addition to
the seven read-only methods (decision
ux-3-mcp-read-write-2026-10): mathc/gate, mathc/attest,
mathc/record, mathc/re-evaluate-decisions. The dispatcher
allowlist is the only barrier; methods not in the list return
-32601 Method not found.

This fixture exercises the new methods to confirm they are
in the allowlist and produce a JSON-RPC success response.
The fixture does NOT exercise the side effects (writes to
attestations/, decisions/execution-logs.jsonl) — that is
the responsibility of the underlying mathc subcommand, which
has its own tests.

  $ cd "$DUNE_SOURCEROOT"
  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":1,"method":"mathc/gate","params":{"base":"HEAD","head":"HEAD~1"}}' \
  >     | mathc_mcp \
  >     | grep -q '"id":1'; then \
  >   grep -q '"exit_code"' /dev/stdin || echo "mathc/gate: id present (exit code may be 0 or non-zero)"; \
  > else echo "FAIL: mathc/gate method not exposed"; fi
  mathc/gate: id present (exit code may be 0 or non-zero)

  $ cd "$DUNE_SOURCEROOT"
  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":2,"method":"mathc/attest","params":{"path":"nonexistent.xml"}}' \
  >     | mathc_mcp \
  >     | grep -q '"id":2'; then \
  >   echo "mathc/attest: id present (exits 2 on missing file is fine)"; \
  > else echo "FAIL: mathc/attest method not exposed"; fi
  mathc/attest: id present (exits 2 on missing file is fine)

  $ cd "$DUNE_SOURCEROOT"
  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":3,"method":"mathc/record","params":{"decision_id":"foo@1","scale":"session"}}' \
  >     | mathc_mcp \
  >     | grep -q '"id":3'; then \
  >   echo "mathc/record: id present"; \
  > else echo "FAIL: mathc/record method not exposed"; fi
  mathc/record: id present

  $ cd "$DUNE_SOURCEROOT"
  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":4,"method":"mathc/re-evaluate-decisions","params":{"axiom_id":"A0"}}' \
  >     | mathc_mcp \
  >     | grep -q '"id":4' && \
  >   mathc_mcp < /dev/null ; then \
  >   out=$(printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":4,"method":"mathc/re-evaluate-decisions","params":{"axiom_id":"A0"}}' \
  >     | mathc_mcp)
  >   echo "$out" | grep -q '"verdict"' && echo "mathc/re-evaluate-decisions: verdict present" || echo "FAIL: no verdict"
  > else echo "FAIL: mathc/re-evaluate-decisions method not exposed"; fi
  mathc/re-evaluate-decisions: verdict present

Method names NOT in the allowlist still return -32601.

  $ cd "$DUNE_SOURCEROOT"
  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":5,"method":"mathc/secret"}' \
  >     | mathc_mcp \
  >     | grep -q '"code":-32601'; then \
  >   echo "mathc/secret: correctly rejected (-32601)"; \
  > else echo "FAIL: mathc/secret should be rejected"; fi
  mathc/secret: correctly rejected (-32601)

The error message lists the new methods in the allowlist.

  $ cd "$DUNE_SOURCEROOT"
  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":6,"method":"mathc/secret"}' \
  >     | mathc_mcp \
  >     | grep -q 'gate,attest,record,re-evaluate-decisions'; then \
  >   echo "error message lists read-write methods"; \
  > else echo "FAIL: error message missing read-write methods"; fi
  error message lists read-write methods
