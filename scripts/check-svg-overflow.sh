#!/usr/bin/env bash
# scripts/check-svg-overflow.sh
#
# Wrapper for scripts/check-svg-overflow.py invoked by
# scripts/check.sh as the "svg-overflow" step.
#
# Verifier added 2026-10-15 after SVG-illustration overflow was
# reported on GitHub Pages: <text> elements near the right edge of
# a viewBox were clipped by the browser. This script estimates each
# text element's bounding box from font metrics (char count ×
# font-size × 0.62 for monospace, × 0.55 for serif) and fails when
# the bbox overflows the root viewBox + margin.
#
# Override margin with SVG_OVERFLOW_MARGIN env var (default 5 px).
#
# Exit codes:
#   0 — all SVGs have all text inside viewBox + margin
#   1 — one or more text elements overflow
#   2 — script error (parse failure, missing python3)

set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "svg-overflow: python3 unavailable; skipping (exit 0)" >&2
    exit 0
fi

exec python3 scripts/check-svg-overflow.py "$@"
