#!/usr/bin/env bash
# scripts/render.sh — build the math-coding site.
#
# Pipeline:
#   1. Build the mathc binary via `scripts/dev build`.
#   2. Run `mc render --out dist/ --lang=both` to render the
#      site in English and Russian (any site/<name>.ru.md sibling
#      is rendered to dist/<name>.ru.html).
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
# --lang=both emits both the English .html and the Russian
# .ru.html for every article that has a sibling. Sites that do
# not yet ship a Russian translation still get the English page;
# the Russian .ru.html is omitted when its source is absent.
_build/install/default/bin/mathc render --out dist --lang=both

echo "[3/4] copying assets..."
mkdir -p dist/assets
cp -f assets/style.css dist/assets/style.css
cp -f assets/site.js dist/assets/site.js 2>/dev/null || true

echo "[4/4] verifying dist/..."

required=(
  dist/index.html
  dist/axioms.html
  dist/methodology.html
  dist/manifesto.html
  dist/foundations.html
  dist/workflow.html
  dist/faq.html
  dist/readme.html
  dist/contributing.html
  dist/bootstrap-gate.html
  dist/packages.html
  dist/assets/style.css
  dist/index.json
)

# Per-decision pages — meta files excluded (matches lib/packages.ml)
for d in decisions/*.yaml decisions/*.yml decisions/*.json; do
  [ -f "$d" ] || continue
  base=$(basename "$d")
  case "$base" in
    decision.yaml|obligations.yaml|obligation-count-reconcile.yaml|gate-attestation-store-fill-decision.yaml|ONBOARDING.md|rationale.md) continue ;;
  esac
  base=$(basename "$d" .yaml)
  base=$(basename "$base" .yml)
  base=$(basename "$base" .json)
  required+=( "dist/decisions/${base}.html" )
done

# Per-axiom pages — index.md excluded
for a in axioms/*.md; do
  [ -f "$a" ] || continue
  base=$(basename "$a" .md)
  case "$base" in
    index) continue ;;
  esac
  required+=( "dist/axioms/${base}.html" )
done

# Russian siblings — only when the source `<name>.ru.md` exists.
# The bilingual_pairs_complete obligation is asserted by
# tests/render.ml; the allowlist here mirrors that policy.
for s in site/*.ru.md; do
  [ -f "$s" ] || continue
  base=$(basename "$s" .ru.md)
  required+=( "dist/${base}.ru.html" )
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

echo "render OK: dist/ contains ${#required[@]} files."
echo ""
echo "preview locally:"
echo "  python3 -m http.server -d dist/ 8000"