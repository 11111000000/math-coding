#!/usr/bin/env bash
# tests/fixtures/paseo-console-client-bundle.sh
#
# The console's client half, compiled and evaluated the way the host does it.
#
# WHY THIS EXISTS. The Paseo app loads a plugin's client half as SOURCE and
# evaluates it with a module resolver that offers exactly ten modules. A
# client half that imports `server/`, or a `node:` builtin, or a package the
# host does not carry, fails in the app and nowhere else: the typechecker
# does not know the host's allowlist, and the daemon does not compile the
# client bundle. The failure appears when somebody opens the panel, which is
# the worst moment to find it.
#
# This fixture builds the bundle against the SAME allowlist, checks that it
# imports nothing else, evaluates it, and requires that it default-exports a
# function — which is what the host requires before it registers anything.
#
# The check is skipped, not failed, when the plugin's dependencies are not
# installed.
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
  echo "paseo-console-client-bundle: FAIL"
  exit 1
fi

if [ ! -d "$PLUGIN/node_modules" ]; then
  echo "paseo-console-client-bundle: SKIP (the plugin's dependencies are not installed)"
  exit 0
fi

output="$(cd "$PLUGIN" && npx tsx scripts/client-bundle.ts 2>&1)"
status=$?

printf '%s\n' "$output" | sed 's/^/    /'

if [ "$status" -eq 0 ]; then
  ok "the client bundle compiles, imports only what the host offers, and loads"
else
  bad "the client bundle does not load"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "paseo-console-client-bundle: PASS"
  exit 0
fi
echo "paseo-console-client-bundle: FAIL"
exit 1
