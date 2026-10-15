#!/usr/bin/env bash
# scripts/render.sh — build the math-coding site.
#
# Pipeline:
#   1. Build the mathc binary via `scripts/dev build`.
#   2. Run `mathc render --out dist/ --lang=all` to render the
#      site in English, Russian, and Chinese (any
#      site/<name>.ru.md or site/<name>.zh.md sibling is rendered
#      to dist/<name>.ru.html or dist/<name>.zh.html).
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

echo "[2/4] running mathc render..."
mkdir -p dist
# --lang=all emits the English .html, the Russian .ru.html, and
# the Chinese .zh.html for every article that has the
# corresponding source. Sites that do not yet ship a Russian or
# Chinese translation still get the English page; the .ru.html
# and .zh.html are omitted when their sources are absent. The
# index pages (index.html, index.ru.html, index.zh.html) are
# emitted unconditionally per language.
_build/install/default/bin/mathc render --out dist --lang=all

echo "[3/4] copying assets..."
mkdir -p dist/assets
cp -f assets/style.css dist/assets/style.css
cp -f assets/site.js dist/assets/site.js 2>/dev/null || true
# Copy any SVG illustrations (Phase 2 of site-quality-illustrations-2026-10
# plus future additions). The list is glob-derived so a new
# asset/*.svg is picked up without a script change; the verify
# pass at [4/4] catches missing files.
for svg in assets/*.svg; do
  [ -f "$svg" ] || continue
  cp -f "$svg" "dist/assets/$(basename "$svg")"
done

echo "[4/4] verifying dist/..."

required=(
  dist/index.html
  dist/index.ru.html
  dist/index.zh.html
  dist/axioms.html
  dist/methodology.html
  dist/manifesto.html
  dist/foundations.html
  dist/workflow.html
  dist/faq.html
  dist/readme.html
  dist/contributing.html
  dist/bootstrap-gate.html
  dist/install.html
  dist/packages.html
  dist/differences.html
  dist/assets/style.css
  dist/index.json
  dist/dashboard.html
  dist/graph.html
  dist/graph.json
)

# Per-decision pages — meta files excluded (matches lib/packages.ml)
# Uses the YAML `id:` field, not the filename, because some
# decisions keep a `-<date>` suffix in the filename but the
# render path strips it (e.g., `exit-code-symmetry-2026-10.yaml`
# with `id: exit-code-symmetry` produces
# `dist/decisions/exit-code-symmetry.html`).
for d in decisions/*.yaml decisions/*.yml decisions/*.json; do
  [ -f "$d" ] || continue
  base=$(basename "$d")
  case "$base" in
    decision.yaml|obligations.yaml|obligation-count-reconcile.yaml|gate-attestation-store-fill-decision.yaml|ONBOARDING.md|rationale.md) continue ;;
  esac
  decision_id=$(awk '/^id:[[:space:]]/{print $2; exit}' "$d" 2>/dev/null)
  if [ -z "$decision_id" ]; then
    # Fall back to filename for non-YAML/legacy files.
    decision_id=$(basename "$d" .yaml)
    decision_id=$(basename "$decision_id" .yml)
    decision_id=$(basename "$decision_id" .json)
  fi
  required+=( "dist/decisions/${decision_id}.html" )
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

# Chinese siblings — only when the source `<name>.zh.md` exists.
# Mirrors the Russian-sibling allowlist above.
for s in site/*.zh.md; do
  [ -f "$s" ] || continue
  base=$(basename "$s" .zh.md)
  required+=( "dist/${base}.zh.html" )
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