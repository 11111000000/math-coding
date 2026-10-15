`mathc/precommit` is exposed as a read-only MCP method
(decision `ux-3-precommit-subcommand-2026-10`, registered in
the read-only allowlist alongside `mathc/validate`,
`mathc/explain`, `mathc/packages`, `mathc/mode`,
`mathc/re-evaluate`, `mathc/rebuttals`, `mathc/self-check`,
`mathc/find`). This is distinct from the read-write methods
(`mathc/gate`, `mathc/attest`, `mathc/record`,
`mathc/re-evaluate-decisions`) which are gated behind the
`MCP_READ_WRITE` env var (decision
`mcp-read-write-env-gate-2026-10`).

Two invariants are exercised. Case (a): the `mathc/precommit`
MCP method returns a JSON-shaped summary (with a `total`,
`accepted`, `rejected`, `input_err`, and `files[]` field).
Case (b): `mathc/precommit` is in the read-only allowlist, so
when the read-write gate is OFF the method still works while
the four read-write methods are rejected with -32601.

The fixture invokes mathc_mcp as a subprocess.

  $ cd "$DUNE_SOURCEROOT"
  $ unset MCP_READ_WRITE
  $ printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":1,"method":"mathc/precommit","params":{}}' \
  >     | mathc_mcp \
  >     > /tmp/precommit-readonly-1.json 2>/dev/null
  $ grep -q '"id":1' /tmp/precommit-readonly-1.json \
  >   && grep -q '"total":' /tmp/precommit-readonly-1.json \
  >   && grep -q '"accepted":' /tmp/precommit-readonly-1.json \
  >   && grep -q '"files":\[' /tmp/precommit-readonly-1.json \
  >   && echo "mathc/precommit MCP method: returns a summary-shaped JSON"
  mathc/precommit MCP method: returns a summary-shaped JSON

`mathc/precommit` accepts a `paths` parameter (a JSON array of
file paths to validate). The fixture pins one well-formed file
and one nonexistent file; the response must report `input_err`
>= 1 for the missing path.

  $ cd "$DUNE_SOURCEROOT"
  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":2,"method":"mathc/precommit","params":{"paths":["decisions/1-foo.yaml","/tmp/nope-precommit-mcp.yaml"]}}' \
  >     | mathc_mcp > /tmp/precommit-readonly-2.json 2>/dev/null; then \
  >   grep -q '"id":2' /tmp/precommit-readonly-2.json \
  >     && grep -q '"input_err":1' /tmp/precommit-readonly-2.json \
  >     && grep -q '"accepted":1' /tmp/precommit-readonly-2.json \
  >     && echo "mathc/precommit paths param: mixed accept/input_err reported" \
  >     || echo "FAIL: mathc/precommit paths param shape wrong"; \
  >   else echo "FAIL: mathc_mcp exit non-zero"; fi
  mathc/precommit paths param: mixed accept/input_err reported

`mathc/precommit` (gate=off): read-only method still reachable
while the four read-write methods are rejected with -32601.

  $ cd "$DUNE_SOURCEROOT"
  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":3,"method":"mathc/precommit","params":{}}' \
  >     | env MCP_READ_WRITE=off mathc_mcp 2>&1 \
  >     | grep -q '"id":3'; then \
  >   echo "mathc/precommit (gate=off): read-only method still reachable"; \
  > else echo "FAIL: mathc/precommit gated by env"; fi
  mathc/precommit (gate=off): read-only method still reachable
