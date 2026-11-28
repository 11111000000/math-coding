#!/bin/sh
# The console names the permission that is closed.
#
# Two permissions of the host are closed by default: the run of the checks of
# the project and the record of a decision of the human. A button that is
# closed without a reason is a button nobody can read, so the console names the
# switch that opens it and offers the way to the settings of the host.
#
# The check reads the fixtures of the permissions and the negative controls of
# the permissions. Every control breaks one line of the subject and asks the
# check to fail: a check that still passes means the break went unnoticed, and
# a check that cannot fail proves nothing.
#
# Exit 0 - every closed action names the switch that opens it, and the console
#          opens the settings of the host.
# Exit 1 - a closed action has no reason, the console offers no way to the
#          settings, or the check cannot fail.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
PLUGIN="$ROOT/plugin/math-coding-console"

# The checks of the permissions need the packages of the plugin. A tree that
# has the packages keeps them, and a copy of a tree borrows them from the
# tree it was made of.
. "$ROOT/plugin/math-coding-console/scripts/console-packages.sh"
console_packages_install "$ROOT" "plugin/math-coding-console"

# The fixtures of the permissions: the panel names the switch of every closed
# permission, says what always works, and opens the settings of the host when
# the human asks for them.
(cd "$PLUGIN" && ./node_modules/.bin/tsx --test test/permissions.test.ts)

# The negative controls of the permissions: each of them must catch its break.
(cd "$PLUGIN" && sh scripts/negative-controls.sh test/permissions.test.ts)

echo "verify-console-permissions: PASS"
