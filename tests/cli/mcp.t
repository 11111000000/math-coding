mathc_mcp is a JSON-RPC 2.0 server over stdio. It reads one
request per line on stdin, writes one response per line on
stdout, and exits 0 on graceful EOF (the protocol layer
carries the error in the response body, NOT in the exit
code; only signal-killed subprocesses produce non-zero exits).
This cram test exercises the seven read-only methods, the two
error paths, and the multi-request session shape.

The cram shell's cwd is a bwrap tmp dir. mathc_mcp is on the
PATH (deps %{bin:mathc_mcp} in tests/cli/dune), but path
arguments (e.g. decisions/decision.yaml for mathc/validate)
must be relative to the project root, not the cram cwd. The
cram test cd's to $DUNE_SOURCEROOT at the top of every case
that needs to resolve a project-relative path.

  $ cd "$DUNE_SOURCEROOT"
  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":1,"method":"mathc/packages"}' \
  >     | $INSIDE_DUNE/bin/mathc_mcp.exe \
  >     | tee /tmp/mcp-test-1.json \
  >     | grep -q '"id":1'; then \
  >     grep -q '"exit_code":0' /tmp/mcp-test-1.json && \
  >     grep -q '"policy_id":"bootstrap-v3"' /tmp/mcp-test-1.json && \
  >     echo "mathc/packages: id, exit_code, policy_id all ok"; \
  >   else echo "FAIL: id=1 not found"; fi
  mathc/packages: id, exit_code, policy_id all ok

  $ cd "$DUNE_SOURCEROOT"
  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":2,"method":"mathc/validate","params":{"path":"decisions/decision.yaml"}}' \
  >     | $INSIDE_DUNE/bin/mathc_mcp.exe \
  >     | tee /tmp/mcp-test-2.json \
  >     | grep -q '"verdict":"parse-ok"'; then \
  >     grep -q '"exit_code":0' /tmp/mcp-test-2.json && \
  >     echo "mathc/validate: parse-ok with exit_code=0 ok"; \
  >   else echo "FAIL: parse-ok verdict not present"; fi
  mathc/validate: parse-ok with exit_code=0 ok

  $ if printf 'not valid json\n' | $INSIDE_DUNE/bin/mathc_mcp.exe \
  >     | tee /tmp/mcp-test-3.json \
  >     | grep -q '"code":-32700'; then \
  >     grep -q '"message":"Parse error' /tmp/mcp-test-3.json && \
  >     echo "parse error: code=-32700, message starts with 'Parse error'"; \
  >   else echo "FAIL: code=-32700 not found"; fi
  parse error: code=-32700, message starts with 'Parse error'

  $ if printf '%s\n' \
  >     '{"jsonrpc":"2.0","id":3,"method":"mathc/gate"}' \
  >     | $INSIDE_DUNE/bin/mathc_mcp.exe \
  >     | tee /tmp/mcp-test-4.json \
  >     | grep -q '"code":-32602'; then \
  >     grep -q 'Invalid params' /tmp/mcp-test-4.json && \
  >     echo "missing params: code=-32602, message names the param issue"; \
  >   else echo "FAIL: code=-32602 not found"; fi
  missing params: code=-32602, message names the param issue

  $ printf '%s\n%s\n' \
  >   '{"jsonrpc":"2.0","id":10,"method":"mathc/packages"}' \
  >   '{"jsonrpc":"2.0","id":11,"method":"mathc/self-check"}' \
  >   | $INSIDE_DUNE/bin/mathc_mcp.exe > /tmp/mcp-test-5.json
  $ wc -l < /tmp/mcp-test-5.json | tr -d ' '
  2
  $ head -1 /tmp/mcp-test-5.json | grep -q '"id":10' && echo "first id=10 ok"
  first id=10 ok
  $ tail -1 /tmp/mcp-test-5.json | grep -q '"id":11' && echo "second id=11 ok"
  second id=11 ok

  $ printf '%s\n' \
  >   '{"jsonrpc":"2.0","id":99,"method":"mathc/packages"}' \
  >   | $INSIDE_DUNE/bin/mathc_mcp.exe > /dev/null
  $ echo $?
  0
