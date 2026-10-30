#!/usr/bin/env bash
# plugin/math-coding-console/scripts/render-check.sh
#
# Render every view of the console in Node, with the real state of a real
# repository.
#
# The console's client half runs inside the Paseo app, where React Native
# provides the primitives. Here those primitives are replaced by the smallest
# stubs that let a view RENDER, and the state comes from the kernel through
# the same handler the daemon runs.
#
# What it proves: each view renders without throwing, with the corpus's own
# data. What it does not prove: how the console looks, and how it behaves
# under the host's gestures. Those are checked by opening the console in
# Paseo.
#
#   ./scripts/render-check.sh [repository-root]
set -uo pipefail
cd "$(dirname "$0")/.."

ROOT="${1:-$PWD}"
# The bundle lives INSIDE the plugin, so that node resolves the external
# packages (react, react-dom, zod) from the plugin's own node_modules.
OUT="$PWD/node_modules/.render-check"
rm -rf "$OUT"
mkdir -p "$OUT"
trap 'rm -rf "$OUT"' EXIT

if [ ! -d node_modules/esbuild ]; then
  printf 'render-check: esbuild is not installed (npm install)\n' >&2
  exit 2
fi

node -e '
const esbuild = require("esbuild");
const path = require("path");
esbuild.build({
  entryPoints: [path.resolve("scripts/render-check.ts")],
  bundle: true,
  platform: "node",
  format: "cjs",
  target: "node22",
  jsx: "automatic",
  outfile: process.argv[1],
  logLevel: "error",
  alias: {
    "react-native": path.resolve("scripts/stubs/react-native.tsx"),
    "@getpaseo/plugin/client/ui": path.resolve("scripts/stubs/host.tsx"),
    "@getpaseo/plugin/client": path.resolve("scripts/stubs/host.tsx"),
  },
  external: ["react", "react-dom", "zod"],
}).then(() => process.exit(0)).catch((e) => { console.error(String(e)); process.exit(1); });
' "$OUT/render-check.cjs" || exit 2

node "$OUT/render-check.cjs" "$ROOT"
