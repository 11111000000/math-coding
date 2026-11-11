#!/bin/sh
# Build the static site into site/dist. The only generated part is the
# claim map; it is computed by the same library code as `mathc map`,
# so the site can never show a state the tool itself does not compute.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DIST="$ROOT/site/dist"

dune build --root "$ROOT" site/render.exe

rm -rf "$DIST"
mkdir -p "$DIST"
cp -R "$ROOT/site/src/." "$DIST/"
cp "$ROOT/skills/math-coding/references/METHODOLOGY.md" "$DIST/METHODOLOGY.md"

META="generated from spec.json @ $(git -C "$ROOT" rev-parse --short HEAD) on $(date -u +%Y-%m-%d) UTC"
"$ROOT/_build/default/site/render.exe" build "$ROOT" "$DIST" "$META"
printf 'site: built %s\n' "$DIST"
