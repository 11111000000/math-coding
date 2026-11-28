#!/bin/sh
# The packages of the JavaScript projects of this repository.
#
# The checks of the console run in copies of the tree, and a copy of the
# tree carries no packages: every copy installs them again. The rule of the
# installation lives here and not in five copies of it, and the cache of the
# downloads keeps the network out of the copies.
#
# Usage:
#   . "$ROOT/plugin/math-coding-console/scripts/console-packages.sh"
#   console_packages_install "$PROJECT"
#
# The function does nothing when the packages are already installed.

console_packages_install() {
  project=$1
  if [ -x "$project/node_modules/.bin/tsx" ]; then
    return 0
  fi
  (cd "$project" && npm ci --ignore-scripts --no-audit --no-fund --prefer-offline >/dev/null)
}
