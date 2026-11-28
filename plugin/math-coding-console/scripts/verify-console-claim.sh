#!/bin/sh
# The claim console-trust-boundary covers two projects: the Paseo plugin and
# the browser page. Neither project reads the packages of the other, so their
# checks run side by side. The steps that need the installed packages wait for
# the install, and the audit runs first because it needs no packages at all.
#
# The heavy steps run two at a time and never more. Three node processes at
# once do not fit on a small machine, and a killed step is indistinguishable
# from a broken subject: the check would refute a claim that is whole. The
# bound of scripts/negative-controls.sh keeps the same rule for the controls.
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

# The packages of both projects are taken one after another, the way
# console/scripts/check-page.sh takes them. Two installs at the same time
# need twice the memory, and on a small machine the installer is killed. A
# tree that has the packages keeps them, and a copy of a tree borrows them
# from the tree it was made of: the copy installs them only when the tree
# cannot lend them.
. "$ROOT/plugin/math-coding-console/scripts/console-packages.sh"
status=0
console_packages_install "$ROOT" "plugin/math-coding-console" || status=1
console_packages_install "$ROOT" "console" || status=1
if [ "$status" -ne 0 ]; then
  echo "verify-console: the packages are not installed" >&2
  exit 1
fi

# The type checks do not read each other's results, so they run side by side.
status=0
(cd "$PLUGIN" && npm run typecheck) &
plugin_typecheck=$!
(cd "$PAGE" && npm run typecheck) &
page_typecheck=$!
wait "$plugin_typecheck" || status=1
wait "$page_typecheck" || status=1
if [ "$status" -ne 0 ]; then
  echo "verify-console: a type check failed" >&2
  exit 1
fi

# The negative controls need the machine to themselves: each of them runs a
# copy of the subject, and they are bounded by their own script.
(cd "$PLUGIN" && npm run test:negative) || {
  echo "verify-console: a negative control failed" >&2
  exit 1
}

# The tests of the plugin and the check of the page follow, two at a time.
status=0
(cd "$PLUGIN" && npm test) &
plugin_test=$!
(cd "$PLUGIN" && npm run test:render) &
plugin_render=$!
wait "$plugin_test" || status=1
wait "$plugin_render" || status=1
if [ "$status" -ne 0 ]; then
  echo "verify-console: a test of the plugin failed" >&2
  exit 1
fi

status=0
(cd "$PAGE" && npm test) &
page_test=$!
(cd "$PAGE" && npm run build) &
page_build=$!
wait "$page_test" || status=1
wait "$page_build" || status=1
if [ "$status" -ne 0 ]; then
  echo "verify-console: a test or the build of the page failed" >&2
  exit 1
fi

echo "verify-console: PASS"
