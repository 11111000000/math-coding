#!/bin/sh
# Every negative control breaks one line of the console and asks the check
# that covers it to fail. The copy keeps the same relative layout as the
# working tree, because the console imports the shared layer of the plugin;
# node_modules stay symlinked to the working tree. A control that does not
# catch its break fails the whole script.
set -eu

CONSOLE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
PLUGIN=$(CDPATH= cd -- "$CONSOLE/../plugin/math-coding-console" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

FILTER=${1:-}

if [ ! -x "$CONSOLE/node_modules/.bin/tsx" ]; then
  echo "negative-control: the packages are not installed" >&2
  exit 1
fi

prepare() {
  dir=$1
  mkdir -p "$dir/plugin/math-coding-console" "$dir/console"
  cp -R "$PLUGIN/shared" "$PLUGIN/client" "$PLUGIN/test" "$dir/plugin/math-coding-console/"
  cp -R "$CONSOLE/src" "$CONSOLE/test" "$dir/console/"
  cp "$CONSOLE/package.json" "$CONSOLE/tsconfig.json" "$dir/console/"
  ln -s "$CONSOLE/node_modules" "$dir/console/node_modules"
  if [ -d "$PLUGIN/node_modules" ]; then
    ln -s "$PLUGIN/node_modules" "$dir/plugin/math-coding-console/node_modules"
  fi
}

# A control breaks one line and asks the whole console test suite to fail.
# The suite has to fail: a suite that still passes means the break went
# unnoticed.
control() {
  name=$1
  file=$2
  expression=$3
  if [ -n "$FILTER" ] && [ "$name" != "$FILTER" ]; then
    return 0
  fi
  dir="$WORK/control-$name"
  prepare "$dir"
  sed -i "$expression" "$dir/$file"
  if (cd "$dir/console" && ./node_modules/.bin/tsx --test test/*.test.ts >/dev/null 2>&1); then
    echo "negative-control: FAIL $name (the broken copy still passed)" >&2
    exit 1
  fi
  echo "negative-control: ok $name"
  rm -rf "$dir"
}

# The origin gate must refuse a write that carries no origin at all.
control origin-gate console/src/server.ts \
  's/if (origin === undefined) return false;/if (origin === undefined) return true;/'

# A failed refresh must replace the snapshot with the error.
control stale-snapshot plugin/math-coding-console/client/console.tsx \
  's/) : snapshotQuery.isError ? (/) : false ? (/'

# The error boundary must catch an exception instead of passing it through.
control error-boundary console/src/error-boundary.tsx \
  's/return { error: error instanceof Error ? error : new Error(String(error)) };/return { error: null };/'

echo "negative-control: every broken copy was caught"
