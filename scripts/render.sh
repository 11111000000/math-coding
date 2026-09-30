#!/usr/bin/env bash
# scripts/render.sh — build the math-coding site.
#
# Pipeline:
#   1. Build the mathc binary via `scripts/dev build`.
#   2. Run `mc render --out dist/` to render the site.
#   3. Copy `assets/style.css` to `dist/assets/style.css`.
#   4. Verify every expected file exists (per spec/semantics.md
#      §`render`).
#
# Usage:
#   scripts/render.sh           — uses local _build
#   nix develop .#test --command scripts/render.sh

set -euo pipefail
cd "$(dirname "$0")/.."

echo "[1/4] building mathc..."
scripts/dev build

echo "[2/4] running mc render..."
mkdir -p dist
_build/install/default/bin/mathc render --out dist

echo "[3/4] copying assets..."
mkdir -p dist/assets
cp -f assets/style.css dist/assets/style.css
cp -f assets/site.js dist/assets/site.js 2>/dev/null || true

echo "[4/4] verifying dist/..."

required=(
  dist/index.html
  dist/axioms.html
  dist/methodology.html
  dist/bootstrap-gate.html
  dist/packages.html
  dist/assets/style.css
  dist/index.json
)

# Per-decision pages
for d in decisions/*.yaml decisions/*.yml decisions/*.json; do
  [ -f "$d" ] || continue
  case "$(basename "$d")" in
    ONBOARDING.md|rationale.md) continue ;;
  esac
  base=$(basename "$d" .yaml)
  base=$(basename "$base" .yml)
  base=$(basename "$base" .json)
  required+=( "dist/decisions/${base}.html" )
done

# Per-axiom pages
for a in axioms/*.md; do
  [ -f "$a" ] || continue
  base=$(basename "$a" .md)
  case "$base" in
    index) continue ;;
  esac
  required+=( "dist/axioms/${base}.html" )
done

missing=0
for f in "${required[@]}"; do
  if [ ! -f "$f" ]; then
    echo "  MISSING: $f"
    missing=$((missing + 1))
  fi
done

if [ "$missing" -ne 0 ]; then
  echo "render incomplete: $missing missing files" >&2
  exit 2
fi

echo "render OK: dist/ contains $(echo "${#required[@]}") files."
echo ""
echo "preview locally:"
echo "  python3 -m http.server -d dist/ 8000"