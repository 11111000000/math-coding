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
printf 'site: built %s\n' "$DIST"
