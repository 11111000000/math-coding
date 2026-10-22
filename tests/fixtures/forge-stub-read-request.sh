#!/usr/bin/env bash
# tests/fixtures/forge-stub-read-request.sh
#
# Verifier for decisions/forge-stub-read-request-2026-10.yaml.
#
# `tests/support/forge_stub/forge_stub.ml` is the HTTP target of the
# probes in `tests/rebuttal_forge_stub.ml`. Three properties are
# asserted here BEHAVIOURALLY — the stub is started and a raw socket
# request is written to it, because the defect class is "the server
# does not answer", and no amount of grepping a source file can tell
# a server that answers from one that hangs:
#
#   (A) A request whose head ends with the blank line is answered
#       with 200. Until 2026-10-22 `read_request` never returned on
#       the blank line: it called `Unix.read` until EOF, so a client
#       that sent headers and waited (curl, on keep-alive) left the
#       stub blocked and owed it no response.
#   (B) A SECOND connection on the same port is answered too.
#       `with_stub` spends one connection on `wait_until_ready` and
#       the probe under test then opens another; a single-shot server
#       answered the first, exited, and handed the second to
#       ECONNREFUSED — which `forge_mirror` maps to `[]`.
#   (C) A request written with bare-LF line endings is answered too:
#       both `\r\n` and `\n` must terminate a line.
#
# No curl, no python: bash's own `/dev/tcp` is enough, so the fixture
# has no dependency beyond a built stub. A regression shows up as a
# `timeout` kill (rc 124) after the 10s budget, not as a hang.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

stub_rel=_build/default/tests/support/forge_stub/forge_stub.exe
# Source scripts/dev-env.sh inside a subshell, the pattern
# tests/fixtures/dev-cleanup-is-scoped.sh uses: it keeps the cached
# dev-shell entry point (no `nix develop` store lock per call) without
# a top-level `.` that shellcheck cannot resolve.
if ! bash -c 'source scripts/dev-env.sh
  mc_run_in_shell "dune build --root . tests/support/forge_stub/forge_stub.exe"' \
     >/dev/null 2>&1; then
  bad "could not build $stub_rel"
  echo "forge-stub-read-request: FAIL"
  exit 1
fi
ok "stub builds"

stub="$PWD/$stub_rel"
body='[{"rebutter":"fixture"}]'

# A port is free when connecting to it is refused.
pick_port() {
  local p
  for p in "$@"; do
    if ! (exec 3<>"/dev/tcp/127.0.0.1/$p") 2>/dev/null; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  return 1
}

port=$(pick_port 21400 21401 21402 21403 21404 21405)
if [ -z "${port:-}" ]; then
  bad "no free port among 21400-21405"
  echo "forge-stub-read-request: FAIL"
  exit 1
fi

# Write $1 to the socket and print the whole response. rc=124 means
# the stub never answered: that is the regression this fixture
# exists to catch, so let it surface as an empty string.
send_request() {
  timeout 5 env REQ="$1" PORT="$port" bash -c '
    exec 3<>"/dev/tcp/127.0.0.1/$PORT" || exit 1
    printf "%s" "$REQ" >&3
    cat <&3
  '
}

"$stub" "$port" "$body" &
stub_pid=$!
trap 'kill "$stub_pid" 2>/dev/null; wait "$stub_pid" 2>/dev/null' EXIT

req_crlf=$'GET /comments?commit=fixture HTTP/1.1\r\nHost: 127.0.0.1\r\nAccept: */*\r\n\r\n'
req_lf=$'GET /comments?commit=fixture HTTP/1.1\nHost: 127.0.0.1\n\n'

# (A) The stub needs a moment to bind; retry the real request until
# the deadline rather than probing with a throwaway connection.
resp1=""
deadline=$((SECONDS + 10))
while [ "$SECONDS" -lt "$deadline" ]; do
  # stderr is dropped on the retries only: "connection refused" per
  # attempt is the expected state while the stub is still binding.
  if resp1=$(send_request "$req_crlf" 2>/dev/null); then
    break
  fi
  resp1=""
  sleep 0.2
done

if [ -z "$resp1" ]; then
  bad "(A) no response to a CRLF request within 10s"
elif ! printf '%s' "$resp1" | grep -q '^HTTP/1.1 200 OK'; then
  bad "(A) response is not 200: $(printf '%s' "$resp1" | head -1)"
else
  ok "(A) CRLF request answered 200"
fi

if printf '%s' "$resp1" | grep -qi '^Connection: close'; then
  ok "(A) response carries Connection: close"
else
  bad "(A) response lacks Connection: close"
fi

body1=${resp1#*$'\r\n\r\n'}
if [ "$body1" = "$body" ]; then
  ok "(A) response body is the one argv passed"
else
  bad "(A) response body is '$body1', expected '$body'"
fi

# (B) The readiness probe consumed connection one; this is connection
# two, the one the forge_mirror path actually uses.
resp2=$(send_request "$req_crlf")
if [ -z "$resp2" ]; then
  bad "(B) the second connection on port $port went unanswered"
elif ! printf '%s' "$resp2" | grep -q '^HTTP/1.1 200 OK'; then
  bad "(B) second connection answered: $(printf '%s' "$resp2" | head -1)"
else
  ok "(B) second connection also answered 200"
fi

# (C) Bare-LF line endings.
resp3=$(send_request "$req_lf")
if [ -z "$resp3" ]; then
  bad "(C) no response to a bare-LF request"
elif ! printf '%s' "$resp3" | grep -q '^HTTP/1.1 200 OK'; then
  bad "(C) bare-LF request answered: $(printf '%s' "$resp3" | head -1)"
else
  ok "(C) bare-LF request answered 200"
fi

if kill -0 "$stub_pid" 2>/dev/null; then
  ok "stub still serving after three connections"
else
  bad "stub exited before serving all three connections"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "forge-stub-read-request: PASS"
  exit 0
fi
echo "forge-stub-read-request: FAIL"
exit 1
