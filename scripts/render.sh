#!/bin/sh
# scripts/render.sh -- generate the math-coding v2.0-Y static site.
#
# Pipeline:
#   1. Build the OCaml binary via dune.
#   2. Run `mathc render` to populate dist/.
#   3. Verify that all expected files exist.
#
# Usage:
#   sh scripts/render.sh           # uses local _build
#   nix develop --command sh scripts/render.sh

set -u

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT" || exit 1

DUNE=$(command -v dune 2>/dev/null || true)
if [ -z "$DUNE" ]; then
    echo "error: dune not found in PATH." >&2
    echo "  run via: nix develop --command sh scripts/render.sh" >&2
    exit 1
fi

echo "[1/3] building mathc binary..."
"$DUNE" build core/main.exe || { echo "build failed" >&2; exit 1; }

BIN=_build/default/core/main.exe
if [ ! -x "$BIN" ]; then
    echo "error: build artifact missing: $BIN" >&2
    exit 1
fi

echo "[2/3] running mathc render..."
"$BIN" render || { echo "render failed" >&2; exit 1; }

echo "[3/3] verifying dist/..."

required="dist/index.html dist/manifesto.html dist/foundations.html dist/workflow.html dist/faq.html dist/agents.html dist/contributing.html dist/readme.html dist/readme-ru.html dist/manifesto-narrative.html dist/packets.html dist/extensions.html dist/assets/style.css"

missing=0
for f in $required; do
    if [ ! -f "$f" ]; then
        echo "  MISSING: $f"
        missing=$((missing + 1))
    fi
done

# Verify each packet page exists.
for d in math/*/; do
    if [ -f "$d/packet.md" ]; then
        name=$(basename "$d")
        f="dist/packets/$name.html"
        if [ ! -f "$f" ]; then
            echo "  MISSING: $f"
            missing=$((missing + 1))
        fi
    fi
done

if [ "$missing" -ne 0 ]; then
    echo "render incomplete: $missing missing files" >&2
    exit 1
fi

# Verify index.html has MathJax and Mermaid CDN script tags.
if ! grep -q "mathjax@3" dist/index.html; then
    echo "  index.html missing MathJax CDN script" >&2
    exit 1
fi
if ! grep -q "mermaid@10" dist/index.html; then
    echo "  index.html missing Mermaid CDN script" >&2
    exit 1
fi

echo "render OK: dist/ contains the full static site."
echo ""
echo "deploy:"
echo "  rsync -av dist/ /path/to/gh-pages/"
echo "  or: cp -r dist/* ."