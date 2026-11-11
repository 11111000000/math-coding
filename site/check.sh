#!/bin/sh
# Verifier for the site-render claim: rebuild the site and confirm that
# the generated map contains every claim from spec.json with the exact
# state the kernel computes. A claim dropped by the generator, or a
# state that disagrees with Project.states, fails the check.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

sh "$ROOT/site/build.sh" >/dev/null
"$ROOT/_build/default/site/render.exe" check "$ROOT" "$ROOT/site/dist"
