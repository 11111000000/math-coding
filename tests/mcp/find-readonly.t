`mathc/find` is exposed as a read-only MCP method
(decision `mathc-find-subcommand-2026-10`, and registered
in the read-only allowlist alongside `mathc/validate`,
`mathc/explain`, `mathc/packages`, `mathc/mode`,
`mathc/re-evaluate`, `mathc/rebuttals`, `mathc/self-check`).
This is distinct from the read-write methods
(`mathc/gate`, `mathc/attest`, `mathc/record`,
`mathc/re-evaluate-decisions`) which are gated behind the
`MCP_READ_WRITE` env var (decision
`mcp-read-write-env-gate-2026-10`).

Two invariants are exercised. Case (a): the `mathc/find`
MCP method returns success JSON shaped as a `mathc packages`
payload filtered by keyword. Case (b): `mathc/find` is in the
read-only allowlist, so when the gate is OFF the method still
works while the four read-write methods are rejected with
-32601.

The fixture invokes mathc_mcp as a subprocess.

  $ cd "$DUNE_SOURCEROOT"
  $ unset MCP_READ_WRITE
  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":1,"method":"mathc/find","params":{"keyword":"mcp"}}' \
  >     | mathc_mcp \
  >     > /tmp/find-readonly-1.json 2>/dev/null; then \
  >   grep -q '"id":1' /tmp/find-readonly-1.json \
  >     && grep -q 'mcp-agent-auto-connect-2026-10' /tmp/find-readonly-1.json \
  >     && echo "mathc/find MCP method: returns a packages-shaped JSON" \
  >     || echo "FAIL: mathc/find response missing"; \
  > else echo "FAIL: mathc_mcp exit non-zero"; fi
  mathc/find MCP method: returns a packages-shaped JSON

  $ cd "$DUNE_SOURCEROOT"
  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":2,"method":"mathc/find","params":{"keyword":"mcp"}}' \
  >     | env MCP_READ_WRITE=off mathc_mcp 2>&1 \
  >     | grep -q '"id":2'; then \
  >   echo "mathc/find (gate=off): read-only method still reachable"; \
  > else echo "FAIL: mathc/find gated by env"; fi
  mathc/find (gate=off): read-only method still reachable

  $ cd "$DUNE_SOURCEROOT"
  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":3,"method":"mathc/gate","params":{"base":"HEAD","head":"HEAD~1"}}' \
  >     | env MCP_READ_WRITE=off mathc_mcp 2>&1 \
  >     | grep -q '"code":-32601'; then \
  >   echo "mathc/gate (gate=off): correctly rejected (-32601)"; \
  > else echo "FAIL: gate should be -32601"; fi
  mathc/gate (gate=off): correctly rejected (-32601)
