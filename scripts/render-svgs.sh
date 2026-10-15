#!/usr/bin/env bash
# scripts/render-svgs.sh
#
# Renders every assets/*.svg into PNG snapshots via headless Chromium,
# with the project's style.css applied (mimics the GitHub Pages rendering).
# Outputs land under assets/_renders/ which is gitignored.
#
# Use this after editing an SVG to verify visually that nothing got clipped.
#
# Usage:
#   scripts/render-svgs.sh            # render all
#   scripts/render-svgs.sh foo.svg    # render just foo.svg
#
# Exit codes:
#   0 — all renders OK
#   1 — chromium not found
#   2 — render failed
set -euo pipefail

cd "$(dirname "$0")/.."

CHROMIUM="${CHROMIUM:-/run/current-system/sw/bin/chromium}"
if ! command -v "$CHROMIUM" >/dev/null 2>&1; then
  echo "error: chromium not found at $CHROMIUM" >&2
  exit 1
fi

OUT_DIR="assets/_renders"
mkdir -p "$OUT_DIR"

HTML="$(mktemp --suffix=.html)"
trap "rm -f $HTML" EXIT

{
  echo '<!doctype html><html><head><meta charset="utf-8">'
  echo "<link rel=\"stylesheet\" href=\"file://$PWD/assets/style.css\">"
  echo '</head><body><main class="site-main">'
  for f in "$@"; do
    if [ ! -f "$f" ]; then f="assets/$(basename "$f" .svg).svg"; fi
    if [ ! -f "$f" ]; then echo "skip: $f" >&2; continue; fi
    name=$(basename "$f" .svg)
    echo "<figure class=\"mathc-figure mathc-figure-inline\"><img src=\"file://$PWD/$f\"></figure>"
  done
  echo '</main></body></html>'
} > "$HTML"

# Compute total window height: each figure at ~aspect of its viewBox + 32px padding.
TOTAL_H=200
for f in "$@"; do
  if [ -f "$f" ]; then
    vb=$(grep -oE 'viewBox="[^"]+"' "$f" | head -1 | sed 's/viewBox="//; s/"//')
    if [ -n "$vb" ]; then
      w=$(echo "$vb" | awk -F'[ \t]+' '{print $3}')
      h=$(echo "$vb" | awk -F'[ \t]+' '{print $4}')
      TOTAL_H=$((TOTAL_H + h * 576 / w + 32))
    fi
  fi
done

"$CHROMIUM" --headless --disable-gpu --no-sandbox --hide-scrollbars \
  --window-size=900,"$TOTAL_H" \
  --screenshot="$OUT_DIR/all.png" \
  "file://$HTML" 2>&1 | tail -1
echo "rendered to $OUT_DIR/all.png"