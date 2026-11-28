#!/bin/sh
# The packages of the JavaScript projects of this repository.
#
# The checks of the console run in copies of the tree, and a copy of the tree
# carries no packages: every copy installs them again, and the battery of the
# project pays for the same packages once per claim. The rule of the
# installation lives here and not in five copies of it, and the cache of the
# downloads keeps the network out of the copies.
#
# A copy does not have to pay at all: it borrows the packages of the tree it
# was made of. The packages are lent only when the lock that names them has
# not changed since they were installed, so a copy never checks a subject it
# did not build.
#
# Usage:
#   . "$ROOT/plugin/math-coding-console/scripts/console-packages.sh"
#   console_packages_install "$ROOT" "plugin/math-coding-console"
#
# The function does nothing when the packages are already installed.

# The tree a copy of the tree was made from. The copy is a clone of the tree,
# and the clone keeps the way back to it.
console_packages_source() {
  git -C "$1" remote get-url origin 2>/dev/null || true
}

# The packages of a tree may be lent to a copy of it only when they are the
# packages of its lock: the lock that names them must not have changed since
# they were installed.
console_packages_lendable() {
  lent_tree=$1
  lent_project=$2
  [ -x "$lent_tree/$lent_project/node_modules/.bin/tsx" ] || return 1
  [ -f "$lent_tree/$lent_project/node_modules/.package-lock.json" ] || return 1
  [ -f "$lent_tree/$lent_project/package-lock.json" ] || return 1
  [ "$lent_tree/$lent_project/package-lock.json" \
      -ot "$lent_tree/$lent_project/node_modules/.package-lock.json" ]
}

# The packages are installed into the project, or borrowed from the tree the
# project was copied from.
console_packages_install() {
  wanted_tree=$1
  wanted_project=$2
  wanted_path="$wanted_tree/$wanted_project"
  if [ -x "$wanted_path/node_modules/.bin/tsx" ]; then
    return 0
  fi
  lending_tree=$(console_packages_source "$wanted_tree")
  case "$lending_tree" in
    /*) ;;
    *) lending_tree="" ;;
  esac
  if [ -n "$lending_tree" ] && console_packages_lendable "$lending_tree" "$wanted_project"; then
    ln -s "$lending_tree/$wanted_project/node_modules" "$wanted_path/node_modules"
    echo "console-packages: the packages of $wanted_project are lent by the tree"
    return 0
  fi
  (cd "$wanted_path" && npm ci --ignore-scripts --no-audit --no-fund --prefer-offline >/dev/null)
}
