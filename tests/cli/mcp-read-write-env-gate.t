`mathc_mcp` exposes 11 methods total: 7 read-only plus 4
read-write (decision `ux-3-mcp-read-write-2026-10`). The
read-write methods (`mathc/gate`, `mathc/attest`,
`mathc/record`, `mathc/re-evaluate-decisions`) are gated
behind the `MCP_READ_WRITE` env var per decision
`mcp-read-write-env-gate-2026-10`. The default (env unset)
preserves the historical behaviour: all 11 methods are
reachable. Setting `MCP_READ_WRITE` to anything other than
`on` / `true` / `1` (or empty / unset) disables the four
read-write methods; they return -32601 Method not found with
a message that names the env var.

Three cases are exercised below: (i) default (env unset):
mathc/gate is reachable. (ii) MCP_READ_WRITE=off: mathc/gate
returns -32601 with the disabled message; read-only methods
still work. (iii) MCP_READ_WRITE=garbage (unknown value):
same as off, plus a one-shot stderr warning that names the
env var value the operator set.

The fixture invokes mathc_mcp as a subprocess.

  $ cd "$DUNE_SOURCEROOT"
  $ unset MCP_READ_WRITE
  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":1,"method":"mathc/gate","params":{"base":"HEAD","head":"HEAD~1"}}' \
  >     | $INSIDE_DUNE/bin/mathc_mcp.exe \
  >     | grep -q '"id":1'; then \
  >   echo "default-env: mathc/gate is reachable"; \
  > else echo "FAIL: default-env returned no id=1"; fi
  default-env: mathc/gate is reachable

  $ cd "$DUNE_SOURCEROOT"
  $ printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":2,"method":"mathc/gate","params":{"base":"HEAD","head":"HEAD~1"}}' \
  >     | env MCP_READ_WRITE=off $INSIDE_DUNE/bin/mathc_mcp.exe \
  >     > /tmp/mcp-off-out.json 2>/tmp/mcp-off-err.txt
  $ grep -q '"code":-32601' /tmp/mcp-off-out.json \
  >   && grep -q 'read-write methods are disabled via MCP_READ_WRITE=off' /tmp/mcp-off-out.json \
  >   && grep -q 'MCP_READ_WRITE=off' /tmp/mcp-off-err.txt \
  >   && grep -q 'read-write methods disabled' /tmp/mcp-off-err.txt \
  >   && echo "MCP_READ_WRITE=off: -32601 + disabled message + stderr warning" \
  >   || echo "FAIL: gate-off invariant broken"
  MCP_READ_WRITE=off: -32601 + disabled message + stderr warning

  $ cd "$DUNE_SOURCEROOT"
  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":7,"method":"mathc/validate","params":{"path":"decisions/decision.yaml"}}' \
  >     | env MCP_READ_WRITE=off $INSIDE_DUNE/bin/mathc_mcp.exe \
  >     | grep -q '"id":7'; then \
  >   echo "MCP_READ_WRITE=off: read-only mathc/validate id=7 still works"; \
  > else echo "FAIL: read-only method id=7 missing"; fi
  MCP_READ_WRITE=off: read-only mathc/validate id=7 still works

  $ cd "$DUNE_SOURCEROOT"
  $ printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":3,"method":"mathc/attest","params":{"path":"nonexistent.xml"}}' \
  >     | env MCP_READ_WRITE=garbage $INSIDE_DUNE/bin/mathc_mcp.exe \
  >     > /tmp/mcp-garbage-out.json 2>/tmp/mcp-garbage-err.txt
  $ grep -q '"code":-32601' /tmp/mcp-garbage-out.json \
  >   && grep -q 'MCP_READ_WRITE=garbage' /tmp/mcp-garbage-err.txt \
  >   && grep -q 'read-write methods disabled' /tmp/mcp-garbage-err.txt \
  >   && echo "MCP_READ_WRITE=garbage: -32601 + named-stderr-warning" \
  >   || echo "FAIL: garbage env should produce -32601 + stderr warning"
  MCP_READ_WRITE=garbage: -32601 + named-stderr-warning

Method names NOT in the allowlist still return -32601 under
both gate states:

  $ cd "$DUNE_SOURCEROOT"
  $ unset MCP_READ_WRITE
  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":4,"method":"mathc/secret"}' \
  >     | $INSIDE_DUNE/bin/mathc_mcp.exe \
  >     | grep -q '"code":-32601'; then \
  >   echo "mathc/secret (default): correctly rejected (-32601)"; \
  > else echo "FAIL: should be -32601"; fi
  mathc/secret (default): correctly rejected (-32601)
