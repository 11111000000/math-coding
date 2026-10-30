#!/usr/bin/env bash
# tests/fixtures/paseo-console-renders.sh
#
# Every view of the math-coding console renders, with the corpus's own data.
#
# WHY THIS EXISTS. The console's client half runs inside the Paseo app. A view
# that throws at render time is invisible until somebody opens that tab, and
# the tab a person needs is often the one nobody opened that day. The check
# renders all of them, with the state the kernel actually reports.
#
# WHAT IT PROVES. Each view renders without throwing and renders the data it
# is given: the verdict, the promise worklist, the decision catalogue, the
# review queue, the evidence, the action panel, and the two sheets.
#
# WHAT IT DOES NOT PROVE. How the console looks, and how it behaves under the
# host's gestures. Those are the host's business, and they are checked by
# opening the console in Paseo.
#
# The check is skipped, not failed, when the plugin's dependencies are not
# installed: a machine without node_modules has not disproved anything.
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
  echo "paseo-console-renders: FAIL"
  exit 1
fi

if [ ! -d "$PLUGIN/node_modules" ]; then
  echo "paseo-console-renders: SKIP (the plugin's dependencies are not installed)"
  exit 0
fi

output="$(bash "$PLUGIN/scripts/render-check.sh" "$PWD" 2>&1)"
status=$?

printf '%s\n' "$output" | sed 's/^/    /'

if [ "$status" -eq 0 ]; then
  ok "every view of the console renders"
else
  bad "a view of the console did not render"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "paseo-console-renders: PASS"
  exit 0
fi
echo "paseo-console-renders: FAIL"
exit 1
