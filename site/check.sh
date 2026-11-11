#!/bin/sh
# Verifier for the site-render claim: rebuild the site and confirm that
# the published pages show exactly the map of `mathc map --json`, that every
# claim of spec.json is present with its state, that the canonical
# methodology is delivered, and that every local link resolves.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

sh "$ROOT/site/build.sh" >/dev/null
"$ROOT/_build/default/site/render.exe" check "$ROOT" "$ROOT/site/dist" \
  "$ROOT/site/dist/map.json"
