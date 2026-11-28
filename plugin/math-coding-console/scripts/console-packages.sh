#!/bin/sh
# The packages of the JavaScript projects of this repository.
#
# The development shell can offer the packages from the store: a derivation
# with a fixed output fetches them once, and the store path is then the
# package tree itself. The checks of the console run in copies of the tree,
# and every copy would otherwise download the same packages again - the
# battery of the project spent minutes on downloads it had already paid for.
#
# The store is used when it is there and the network when it is not, so a
# machine without the development shell still works.
#
# Usage:
#   . "$ROOT/plugin/math-coding-console/scripts/console-packages.sh"
#   console_packages_install "$PROJECT" "$STORE_DIRECTORY"
#
# The function does nothing when the packages are already installed.

console_packages_install() {
  project=$1
  store=$2
  if [ -x "$project/node_modules/.bin/tsx" ]; then
    return 0
  fi
  if [ -n "$store" ] && [ -d "$store/node_modules" ]; then
    rm -rf "$project/node_modules"
    ln -s "$store/node_modules" "$project/node_modules"
    return 0
  fi
  (cd "$project" && npm ci --ignore-scripts --no-audit --no-fund --prefer-offline >/dev/null)
}
