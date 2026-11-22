#!/bin/sh
# The local browser page must be one interface.
#
# The page imports the shared interface from the plugin package, and both
# packages carry their own node_modules. The bundle may therefore hold two
# copies of React or of the data layer. Two copies of React break the hooks
# of the shared interface, and two copies of the data layer break the query
# context: the page then mounts nothing at all and shows an empty screen.
#
# The check builds the page and counts where every package of the bundle
# came from. When a browser is on the machine, the page is also loaded and
# the queue of the human must appear in the rendered document.
#
# Exit 0 - the page is one interface and it renders.
# Exit 1 - the page carries a second copy or does not render.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
PAGE="$ROOT/console"
PLUGIN="$ROOT/plugin/math-coding-console"
failures=0

fail() {
  printf 'check-page: %s\n' "$1" >&2
  failures=$((failures + 1))
}

work=$(mktemp -d "${TMPDIR:-/tmp}/mathc-page.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

# --- the packages of both projects are needed for the build ----------------

# The packages are installed only when they are missing: an installed tree is
# not touched again while a check runs, and the check does not spend the
# network on every run.
if [ ! -x "$PLUGIN/node_modules/.bin/tsx" ]; then
  (cd "$PLUGIN" && npm ci --ignore-scripts --no-audit --no-fund --prefer-offline >/dev/null)
fi
if [ ! -x "$PAGE/node_modules/.bin/tsx" ]; then
  (cd "$PAGE" && npm ci --ignore-scripts --no-audit --no-fund --prefer-offline >/dev/null)
fi

(cd "$PAGE" && npm run build >/dev/null)

# --- one copy of every package of the interface -----------------------------

# The build with a source map names every module of the bundle and the
# directory it came from. The script counts the directories one package was
# taken from: one is enough.
(cd "$PAGE" && npx vite build --sourcemap true --outDir "$work/dist" --emptyOutDir >/dev/null)
if ! node "$PAGE/scripts/bundle-copies.mjs" "$work/dist/assets"; then
  failures=$((failures + 1))
fi

# --- the page renders the queue of the human --------------------------------

browser=""
for candidate in chromium chromium-browser google-chrome google-chrome-stable chrome; do
  if command -v "$candidate" >/dev/null 2>&1; then
    browser=$(command -v "$candidate")
    break
  fi
done

# The check exercises the code of this tree, so the binary of this tree comes
# first. The shared channel changes when the ritual of the build runs, and a
# check of the tree must not depend on what the host happens to have
# installed: the binary of the tree and the binary of the channel speak
# different versions of the format.
#
# The copy of the control has no binary of the tree, and the binary of the
# channel speaks another version of the format: it cannot read the
# specification of the tree. The page then shows an error instead of the
# queue, and the check would report a defect that the tree does not have. So
# the browser part of the check runs only where the binary of the tree is, and
# elsewhere the copies of the packages are the only evidence.
mathc=""
if [ -x "$ROOT/_build/default/bin/mathc.exe" ]; then
  mathc="$ROOT/_build/default/bin/mathc.exe"
fi

if [ -z "$browser" ]; then
  printf 'check-page: no browser on this machine, the copies are the only evidence\n'
elif [ -z "$mathc" ]; then
  printf 'check-page: the binary of this tree is not here, the copies are the only evidence\n'
else
  mkdir -p "$work/project" "$work/bin" "$work/config"
  ln -s "$mathc" "$work/bin/mathc"
  (cd "$work/project" && git init -q && "$mathc" init >/dev/null &&
    "$mathc" goal "the page shows the state of the project" "src/" "owner" >/dev/null &&
    git add -A && git -c user.email=check@example.com -c user.name=check commit -q -m "a project for the check")

  # The preferences of the console live outside the project. The check must
  # not read them: a saved language of the machine would decide the language
  # of the page and the verdict of this check. The server therefore reads an
  # empty directory of its own.
  PATH="$work/bin:$PATH" XDG_CONFIG_HOME="$work/config" \
    "$PAGE/node_modules/.bin/tsx" "$PAGE/src/server.ts" --port 0 --root "$work/project" >"$work/server.log" 2>&1 &
  server=$!

  url=""
  attempts=0
  while [ "$attempts" -lt 60 ]; do
    url=$(sed -n 's/^Math Coding console: //p' "$work/server.log" 2>/dev/null | head -1)
    [ -n "$url" ] && break
    attempts=$((attempts + 1))
    sleep 0.5
  done

  if [ -z "$url" ]; then
    fail "the local server did not start"
  else
    document="$work/page.html"
    if "$browser" --headless --no-sandbox --disable-gpu --dump-dom \
        --virtual-time-budget=10000 "$url" >"$document" 2>/dev/null; then
      # The page follows the language of the host unless the language is
      # pinned. Both titles name the same queue, so the check accepts either
      # of them and never decides by the language of the browser.
      if ! grep -qE 'Your queue|Ваша очередь' "$document"; then
        fail "the page did not render the queue of the human"
      fi
    else
      fail "the browser could not load the page"
    fi
  fi

  kill "$server" 2>/dev/null || true
  wait "$server" 2>/dev/null || true
fi

if [ "$failures" -gt 0 ]; then
  printf 'check-page: %d defect(s) in the local page\n' "$failures" >&2
  exit 1
fi

printf 'check-page: the page is one interface and it renders\n'
