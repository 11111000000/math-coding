#!/bin/sh
# The console performs the manual steps of the method.
#
# The console is a view over the program, not a second implementation of the
# method. A step the human takes is therefore a call of `mathc` itself, with
# the arguments the program declares, and the state after the step is the
# state the program reports.
#
# The check reads the fixtures of the decision and the negative controls of the
# decision. Every control breaks one line of the subject and asks the check to
# fail: a check that still passes means the break went unnoticed, and a check
# that cannot fail proves nothing.
#
# Exit 0 - the steps come from the canonical map and are performed by the
#          program itself.
# Exit 1 - a step is offered that the map does not hold, a decision is made
#          without the confirmation of the human, or the check cannot fail.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
PLUGIN="$ROOT/plugin/math-coding-console"

# The checks of the decision need the packages of the plugin. A tree that has
# the packages keeps them, and a copy of a tree borrows them from the tree it
# was made of.
. "$ROOT/plugin/math-coding-console/scripts/console-packages.sh"
console_packages_install "$ROOT" "plugin/math-coding-console"

# The fixtures of the decision: the steps are read from the canonical map, the
# program performs them with the arguments it declares, and the state after
# the step is the state the program reports.
(cd "$PLUGIN" && ./node_modules/.bin/tsx --test test/human-decision.test.ts)

# The negative controls of the decision: each of them must catch its break.
(cd "$PLUGIN" && sh scripts/negative-controls.sh test/human-decision.test.ts)

echo "verify-human-decision: PASS"
