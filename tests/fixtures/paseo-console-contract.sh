#!/usr/bin/env bash
# tests/fixtures/paseo-console-contract.sh
#
# The contract of the Paseo console plugin: what it registers, where its code
# may live, and which rules it must not break.
#
# WHY THIS EXISTS. The plugin's client half runs inside the Paseo app and its
# server half runs as a daemon subprocess. Both halves fail in ways a unit
# test cannot see: an RPC contract with no handler is a promise the app can
# make and the daemon cannot keep; a client import of `server/` is a compile
# error the typechecker catches but the contract of the PLUGIN does not; a DOM
# global in client code breaks on the phone and works in the browser.
#
# WHAT IT PROVES, and what it does not. It proves that the pieces the
# console is made of are all present and wired to each other. It does NOT
# prove that the console shows the truth: that is the kernel's verdict, read
# over the plugin RPC, and it is checked by the console's own probe harness
# (plugin/math-coding-console/scripts/probe.ts) rather than by this fixture.
#
# The negative control for this fixture is
# tests/fixtures/paseo-console-negative-control.sh, which runs these same
# checks against a deliberately broken copy and requires them to FAIL.
set -uo pipefail
cd "$(dirname "$0")/../.."

PLUGIN="plugin/math-coding-console"

fail=0
ok() { printf 'ok: %s\n' "$1"; }
bad() {
  printf 'FAIL: %s\n' "$1"
  fail=1
}

if [ ! -d "$PLUGIN" ]; then
  bad "the plugin directory is missing: $PLUGIN"
  echo
  echo "paseo-console-contract: FAIL"
  exit 1
fi

# --- 1. the manifest ------------------------------------------------------
manifest="$PLUGIN/paseo-plugin.json"
if [ -f "$manifest" ]; then
  ok "the manifest exists"
  if grep -q '"id"[[:space:]]*:[[:space:]]*"math-coding-console"' "$manifest"; then
    ok "the manifest names the plugin"
  else
    bad "the manifest does not name the plugin math-coding-console"
  fi
  if grep -q '"requirements"' "$manifest" && grep -q '"paseo"' "$manifest"; then
    ok "the manifest states the Paseo version it needs"
  else
    bad "the manifest states no Paseo requirement"
  fi
else
  bad "the manifest is missing: $manifest"
fi

# --- 2. the client registers what it promises ------------------------------
client="$PLUGIN/index.client.tsx"
if [ -f "$client" ]; then
  ok "the client entry exists"
  for method in addWorkspacePanel addScreen addSidebarHeaderItem addCommandCenterItem \
               addSlashCommand addTimelineRenderer; do
    if grep -q "client\.$method(" "$client"; then
      ok "the client registers $method"
    else
      bad "the client does not register $method"
    fi
  done
else
  bad "the client entry is missing: $client"
fi

# --- 3. every contract has a handler --------------------------------------
# The sharp check. A contract without a handler is a promise the client can
# make and the daemon cannot keep; the app shows an error only when a reader
# reaches for it.
#
# The contract VARIABLE is what the server registers; the RPC NAME is what
# travels over the wire. Both are read, so the check asks the right question
# of each.
contracts="$PLUGIN/shared/contracts.ts"
server="$PLUGIN/index.server.ts"
if [ -f "$contracts" ] && [ -f "$server" ]; then
  ok "the contracts and the server entry exist"
  pairs="$(awk '
    /export const [A-Za-z0-9_]+ = defineRpc\(/ { var = $3 }
    /name:[[:space:]]*"mathcoding\./ {
      if (var != "") {
        match($0, /"mathcoding\.[a-z.]*"/)
        print var " " substr($0, RSTART + 1, RLENGTH - 2)
        var = ""
      }
    }
  ' "$contracts")"
  if [ -z "$pairs" ]; then
    bad "no RPC contract is declared in shared/contracts.ts"
  fi
  count=0
  while read -r var name; do
    [ -z "$var" ] && continue
    count=$((count + 1))
    if grep -q "server\.handle($var," "$server"; then
      ok "the daemon handles $name"
    else
      bad "the daemon has no handler for $name (the contract $var)"
    fi
  done <<EOF
$pairs
EOF
  if [ "$count" -lt 5 ]; then
    bad "the console declares only $count RPC contracts; it is a control panel, not a note"
  fi
  dupes="$(grep -o 'name:[[:space:]]*"mathcoding\.[a-z.]*"' "$contracts" | sort | uniq -d)"
  if [ -z "$dupes" ]; then
    ok "every RPC name is unique"
  else
    bad "an RPC name is declared twice: $dupes"
  fi
else
  bad "the contracts file or the server entry is missing"
fi

# --- 4. the runtime boundary ----------------------------------------------
# A client import of server/ and a server import of client/ are compile
# errors. The typechecker catches them; this check names the rule where a
# reader of the plugin will look for it.
if [ -d "$PLUGIN/client" ]; then
  hits="$(grep -rn 'from "\.\./server/\|from '"'"'\.\./server/' "$PLUGIN/client" 2>/dev/null)"
  if [ -z "$hits" ]; then
    ok "the client imports nothing from server/"
  else
    bad "the client imports from server/: $hits"
  fi
fi
if [ -d "$PLUGIN/server" ]; then
  hits="$(grep -rn 'from "\.\./client/\|from '"'"'\.\./client/' "$PLUGIN/server" 2>/dev/null)"
  if [ -z "$hits" ]; then
    ok "the server imports nothing from client/"
  else
    bad "the server imports from client/: $hits"
  fi
fi

# --- 5. no DOM globals in the client ---------------------------------------
# The plugin runs on a phone. `document`, `window` and `localStorage` exist
# in a browser and do not exist on a phone.
if [ -d "$PLUGIN/client" ]; then
  hits="$(grep -rn 'document\.\|window\.\|localStorage\|navigator\.' "$PLUGIN/client" 2>/dev/null | grep -v "client/web.ts")"
  if [ -z "$hits" ]; then
    ok "the client reaches for no DOM global"
  else
    bad "the client reaches for a DOM global: $hits"
  fi
fi

# --- 6. the shared code imports neither runtime ---------------------------
if [ -d "$PLUGIN/shared" ]; then
  hits="$(grep -rn 'node:\|react-native' "$PLUGIN/shared" 2>/dev/null)"
  if [ -z "$hits" ]; then
    ok "the shared code imports neither Node nor React Native"
  else
    bad "the shared code imports a runtime: $hits"
  fi
fi

# The rules about where the console's verdicts come from live in
# tests/fixtures/paseo-console-kernel-authority.sh, which this fixture's
# negative control also breaks.

echo
if [ "$fail" -eq 0 ]; then
  echo "paseo-console-contract: PASS"
  exit 0
fi
echo "paseo-console-contract: FAIL"
exit 1
