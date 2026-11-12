#!/bin/sh
# Verifier for the interface of the site.
#
# It answers two questions with evidence, not with an opinion:
#   1. On a phone screen the navigation keeps every item and every frame.
#   2. The English and the Russian pages are drawn by the same typefaces.
#
# The first part reads the published stylesheet and the published pages.
# The second part measures the rendered pages in a 360 px viewport with a
# real browser.
#
# Exit 0 — the interface holds.
# Exit 1 — it does not.
# Exit 3 — the check could not measure (no browser, no python). That is not
# evidence of success, so the claim stays unknown instead of green.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DIST="$ROOT/site/dist"
CSS="$DIST/assets/style.css"
failures=0

fail() {
  printf 'check-ui: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# --- the published site must be the one that is measured ------------------

if [ ! -f "$DIST/index.html" ] || [ ! -f "$CSS" ] ||
   [ -n "$(find "$ROOT/site/src" -newer "$DIST/index.html" -print -quit 2>/dev/null)" ]; then
  if command -v dune >/dev/null 2>&1; then
    sh "$ROOT/site/build.sh" >/dev/null
  elif [ ! -f "$DIST/index.html" ]; then
    printf 'check-ui: the site is not built and dune is not available\n' >&2
    exit 3
  fi
fi

if [ ! -f "$CSS" ]; then
  printf 'check-ui: the stylesheet is missing from the built site\n' >&2
  exit 1
fi

# --- the typefaces are declared, local and cover both alphabets ----------

# A family is only usable for both languages when one of its faces covers
# the Cyrillic range U+0400-045F.
if ! awk '
  /^@font-face/ { buf = $0; next }
  { buf = buf " " $0 }
  /^}/ {
    if (buf ~ /font-family: "JetBrains Mono"/ && buf ~ /U\+0400-045F/) mono = 1;
    if (buf ~ /font-family: "Source Serif 4"/ && buf ~ /U\+0400-045F/) serif = 1;
    buf = "";
  }
  END { exit (mono && serif) ? 0 : 1 }
' "$CSS"; then
  fail "a typeface has no face that covers the Cyrillic range"
fi

if grep -q 'url("http' "$CSS" || grep -q '@import[^;]*http' "$CSS"; then
  fail "a typeface is loaded from the network instead of from the site"
fi

for family in "JetBrains Mono" "Source Serif 4"; do
  if ! grep -q "font-family: \"$family\"" "$CSS"; then
    fail "the typeface $family is not declared"
  fi
done

# --- no rule may take a frame away from a button or a navigation item ---

if ! awk '
  function check(selector, body) {
    if (selector ~ /cta|nav-link/ &&
        (body ~ /border-bottom:[ ]*0[;]/ || body ~ /border:[ ]*0[;]/)) bad = 1;
  }
  /\{/ {
    selector = $0; sub(/\{.*/, "", selector);
    if ($0 !~ /\}/) { body = ""; next }
    check(selector, $0);
    next;
  }
  /^\}/ { check(selector, body); selector = ""; body = ""; next }
  { body = body " " $0 }
  END { exit bad ? 1 : 0 }
' "$CSS"; then
  fail "a rule takes the bottom frame away from a button or a navigation item"
fi

if ! grep -q 'grid-template-areas' "$CSS"; then
  fail "the navigation is not laid out by a grid"
fi

if ! awk '
  /^nav\.site-nav a\.nav-link\.active/ { buf = $0; next }
  { buf = buf " " $0 }
  /^}/ {
    if (buf ~ /border-bottom-color/) active = 1;
    buf = "";
  }
  END { exit active ? 0 : 1 }
' "$CSS"; then
  fail "the active navigation item has no visible bottom frame"
fi

# --- every page preloads a font that is really there ----------------------

for page in $(find "$DIST" -name '*.html' | sort); do
  for href in $(sed -n 's/.*rel="preload"[^>]*href="\([^"]*\)".*/\1/p' "$page"); do
    dir=$(dirname "$page")
    resolved=$(cd "$dir/$(dirname "$href")" 2>/dev/null && pwd)/$(basename "$href")
    if [ ! -f "$resolved" ]; then
      fail "$page preloads a font that does not exist: $href"
    fi
  done
done

# --- every page offers the same navigation -------------------------------

# The navigation is written by hand on every page, and a page that forgets
# one item hides it from its reader. The items are compared by target, so
# the English and the Russian pages must offer the same ones.
nav_targets() {
  sed -n '/<div class="nav-inner">/,/<\/div>/p' "$1" \
    | sed -n 's/.*href="\([^"]*\)".*/\1/p' \
    | sed -e 's|^\.\./||' -e 's/\.ru\.html$/.html/' \
    | sort | tr '\n' ' '
}

reference=$(nav_targets "$DIST/index.html")
for page in $(find "$DIST" -name '*.html' | sort); do
  found=$(nav_targets "$page")
  if [ "$found" != "$reference" ]; then
    fail "$page offers a different navigation: $found"
  fi
done

# --- the rendered pages, measured in a phone viewport ---------------------

if ! command -v python3 >/dev/null 2>&1; then
  printf 'check-ui: python3 is required to measure the layout\n' >&2
  exit 3
fi

set +e
python3 "$ROOT/site/ui-probe.py" --dist "$DIST" \
  --pages index.html,index.ru.html,claims/core-laws.html \
  --width 360 --verify
measured=$?
set -e

if [ "$measured" -ne 0 ]; then
  exit "$measured"
fi

if [ "$failures" -gt 0 ]; then
  printf 'check-ui: %d defect(s) in the published site\n' "$failures" >&2
  exit 1
fi

printf 'check-ui: the navigation, the frames and the typefaces hold\n'
