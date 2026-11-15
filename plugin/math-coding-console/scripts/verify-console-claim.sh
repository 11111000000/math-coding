#!/bin/sh
# The claim console-trust-boundary covers two projects: the Paseo plugin and
# the browser page. Neither project reads the packages of the other, so their
# checks run side by side. The steps that need the installed packages wait for
# the install, and the audit runs first because it needs no packages at all.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
PLUGIN="$ROOT/plugin/math-coding-console"
PAGE="$ROOT/console"

status=0

# The audit is a rule of the build: the shared interface may not name the host
# package. It needs no packages, so a broken subject stops here.
(cd "$PLUGIN" && npm run audit:client) || status=1
if [ "$status" -ne 0 ]; then
  echo "verify-console: the client audit failed" >&2
  exit 1
fi

# The packages of both projects are installed side by side.
(cd "$PLUGIN" && npm ci --ignore-scripts --no-audit --no-fund --prefer-offline >/dev/null) &
install_plugin=$!
(cd "$PAGE" && npm ci --ignore-scripts --no-audit --no-fund --prefer-offline >/dev/null) &
install_page=$!

status=0
wait "$install_plugin" || status=1
wait "$install_page" || status=1
if [ "$status" -ne 0 ]; then
  echo "verify-console: the packages are not installed" >&2
  exit 1
fi

# The type checks and the negative controls do not read each other's results,
# so they run side by side.
(cd "$PLUGIN" && npm run typecheck) &
plugin_typecheck=$!
(cd "$PAGE" && npm run typecheck) &
page_typecheck=$!
(cd "$PLUGIN" && npm run test:negative) &
plugin_negative=$!

status=0
wait "$plugin_typecheck" || status=1
wait "$page_typecheck" || status=1
wait "$plugin_negative" || status=1
if [ "$status" -ne 0 ]; then
  echo "verify-console: a type check or a negative control failed" >&2
  exit 1
fi

# The tests and the build are the last steps.
(cd "$PLUGIN" && npm test) &
plugin_test=$!
(cd "$PLUGIN" && npm run test:render) &
plugin_render=$!
(cd "$PAGE" && npm test) &
page_test=$!
(cd "$PAGE" && npm run build) &
page_build=$!

status=0
wait "$plugin_test" || status=1
wait "$plugin_render" || status=1
wait "$page_test" || status=1
wait "$page_build" || status=1
if [ "$status" -ne 0 ]; then
  echo "verify-console: a test or the build failed" >&2
  exit 1
fi

echo "verify-console: PASS"
