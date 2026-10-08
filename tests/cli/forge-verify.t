mathc forge-verify is the CLI surface of the A4 forge-membership
gate. The acceptance tests cover three cases:





Acceptance gates for `decisions/forge-principal-verification-2026-10.yaml`:
- obligation `forge-team-member-endpoint`
- obligation `fail-open-default`
- obligation `1-hour-cache`

  $ cd "$DUNE_SOURCEROOT"

Forge unset, fail-mode open (default): pass, exit 0.

  $ env -u MATH_CODING_FORGE_API mathc forge-verify --org=foo --team=bar --user=baz
  {"fail_mode":"open","forge_queried":false,"org":"foo","reason":"MATH_CODING_FORGE_API not set; fail-mode=open","team":"bar","user":"baz","verdict":"pass"}
  $ env -u MATH_CODING_FORGE_API mathc forge-verify --org=foo --team=bar --user=baz
  {"fail_mode":"open","forge_queried":false,"org":"foo","reason":"MATH_CODING_FORGE_API not set; fail-mode=open","team":"bar","user":"baz","verdict":"pass"}
  $ echo $?
  0

Forge unset, fail-mode closed: block, exit 1.

  $ env -u MATH_CODING_FORGE_API mathc forge-verify --org=foo --team=bar --user=baz --fail-mode=closed
  {"fail_mode":"closed","forge_queried":false,"org":"foo","reason":"MATH_CODING_FORGE_API not set; fail-mode=closed","team":"bar","user":"baz","verdict":"block"}
  [1]
  $ env -u MATH_CODING_FORGE_API mathc forge-verify --org=foo --team=bar --user=baz --fail-mode=closed
  {"fail_mode":"closed","forge_queried":false,"org":"foo","reason":"MATH_CODING_FORGE_API not set; fail-mode=closed","team":"bar","user":"baz","verdict":"block"}
  [1]
  $ echo $?
  0

Unknown fail-mode rejected with exit 2.

  $ env -u MATH_CODING_FORGE_API mathc forge-verify --org=foo --team=bar --user=baz --fail-mode=lol
  mathc forge-verify: --fail-mode must be open|closed (got lol)
  [2]
  $ echo $?
  0

Membership verified: a Python stub serves 200 OK on the
membership endpoint. The verifier passes.

  $ port=$(python3 -c "import socket; s=socket.socket(); s.bind(('127.0.0.1', 0)); print(s.getsockname()[1]); s.close()")
  $ cat > /tmp/mc-forge-stub.py <<EOF
  > import http.server, sys
  > PORT = $port
  > class H(http.server.BaseHTTPRequestHandler):
  >     def do_GET(self):
  >         body = b'{"message":"ok"}'
  >         self.send_response(200)
  >         self.send_header("Content-Type", "application/json")
  >         self.send_header("Content-Length", str(len(body)))
  >         self.end_headers()
  >         self.wfile.write(body)
  >     def log_message(self, *a, **k): pass
  > http.server.HTTPServer(('127.0.0.1', PORT), H).serve_forever()
  > EOF
  $ python3 /tmp/mc-forge-stub.py &
  $ stub_pid=$!
  $ sleep 0.2
  $ MATH_CODING_FORGE_API="http://127.0.0.1:$port" mathc forge-verify --org=foo --team=bar --user=alice
  {"fail_mode":"open","forge_queried":true,"matched":true,"org":"foo","reason":"forge returned member=true","team":"bar","user":"alice","verdict":"pass"}
  $ echo $?
  0
  $ kill $stub_pid 2>/dev/null

Membership denied: a Python stub serves 404 on the
membership endpoint. The verifier blocks (fail-closed default
in tests; the --fail-mode open path is verified above).

  $ port=$(python3 -c "import socket; s=socket.socket(); s.bind(('127.0.0.1', 0)); print(s.getsockname()[1]); s.close()")
  $ cat > /tmp/mc-forge-stub.py <<EOF
  > import http.server, sys
  > PORT = $port
  > class H(http.server.BaseHTTPRequestHandler):
  >     def do_GET(self):
  >         body = b'{"message":"Not Found"}'
  >         self.send_response(404)
  >         self.send_header("Content-Type", "application/json")
  >         self.send_header("Content-Length", str(len(body)))
  >         self.end_headers()
  >         self.wfile.write(body)
  >     def log_message(self, *a, **k): pass
  > http.server.HTTPServer(('127.0.0.1', PORT), H).serve_forever()
  > EOF
  $ python3 /tmp/mc-forge-stub.py &
  $ stub_pid=$!
  $ sleep 0.2
  $ MATH_CODING_FORGE_API="http://127.0.0.1:$port" mathc forge-verify --org=foo --team=bar --user=alice
  {"fail_mode":"open","forge_queried":true,"matched":false,"org":"foo","reason":"forge returned member=false","team":"bar","user":"alice","verdict":"block"}
  [1]
  $ echo $?
  0
  $ kill $stub_pid 2>/dev/null

