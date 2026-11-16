#!/bin/sh
# The claim host-sheet covers the sheet of the host: the surface of the host
# has to reach the content of the sheet, because the host draws the sheet
# outside the tree of the panel. The focused check draws the content of the
# sheet in a tree of its own and asks the claim detail of the queue to appear
# there; the render check draws every view of the console, the sheet of the
# host among them.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
PLUGIN="$ROOT/plugin/math-coding-console"

cd "$PLUGIN"

# The check needs the packages of the plugin. Without them it cannot start,
# and the control of the claim would look like a caught break.
npm ci --ignore-scripts --no-audit --no-fund --prefer-offline >/dev/null

./node_modules/.bin/tsx --test test/host-sheet.test.ts
./node_modules/.bin/tsx scripts/render-check.tsx

echo "verify-host-sheet: PASS"
