#!/bin/sh
# Build the static site into site/dist. The claim map is not computed here:
# it is the output of `mathc map --json`, so the site cannot show a state
# the tool itself does not report.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DIST="$ROOT/site/dist"

dune build --root "$ROOT" site/render.exe bin/mathc.exe

rm -rf "$DIST"
mkdir -p "$DIST"
cp -R "$ROOT/site/src/." "$DIST/"
cp "$ROOT/skills/math-coding/references/METHODOLOGY.md" "$DIST/METHODOLOGY.md"

# `mathc map` prints the map and exits 0, 1 or 3 depending on the verdict.
# All three carry the same JSON, and the site must render a red or unknown
# map exactly as honestly as a green one.
MAP="$DIST/map.json"
set +e
"$ROOT/_build/default/bin/mathc.exe" --root "$ROOT" map --json > "$MAP"
status=$?
set -e
case "$status" in
  0 | 1 | 3) ;;
  *)
    printf 'site: the map failed with exit %d\n' "$status" >&2
    exit "$status"
    ;;
esac

META="generated from spec.json @ $(git -C "$ROOT" rev-parse --short HEAD) on $(date -u +%Y-%m-%d) UTC"
"$ROOT/_build/default/site/render.exe" build "$ROOT" "$DIST" "$META" "$MAP"

# The sitemap is written from the files the build has actually produced, so it
# names every published page of the site and nothing else: it cannot drift
# from the pages it names. The error page is not a page of the site - it
# answers an address that is not there - so it stays out of the sitemap.
ORIGIN="https://11111000000.github.io/math-coding/"
sitemap_url() {
  if [ "$1" = "index.html" ]; then
    printf '%s' "$ORIGIN"
  else
    printf '%s%s' "$ORIGIN" "$1"
  fi
}
{
  printf '<?xml version="1.0" encoding="UTF-8"?>\n'
  printf '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
  # the home page comes first, the rest follows in a stable order
  printf '  <url>\n    <loc>%s</loc>\n  </url>\n' "$(sitemap_url index.html)"
  for page in $(cd "$DIST" && find . -name '*.html' ! -name '404.html' -print \
    | sed 's|^\./||' | LC_ALL=C sort)
  do
    if [ "$page" = "index.html" ]; then
      continue
    fi
    printf '  <url>\n    <loc>%s</loc>\n  </url>\n' "$(sitemap_url "$page")"
  done
  printf '</urlset>\n'
} > "$DIST/sitemap.xml"

# The robots file allows the site and points at the sitemap above.
{
  printf 'User-agent: *\n'
  printf 'Allow: /\n'
  printf '\n'
  printf 'Sitemap: %ssitemap.xml\n' "$ORIGIN"
} > "$DIST/robots.txt"

printf 'site: built %s\n' "$DIST"
