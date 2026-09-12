#!/bin/sh
# tools/check-site.sh — executable spec for site-v1-design packet.
#
# Verifies site design invariants.
cd "$(dirname "$0")/../.." || exit 2

# Required files
[ -f dist/index.html ] || { echo "FAIL: dist/index.html missing" >&2; exit 1; }
[ -f dist/axioms.html ] || { echo "FAIL: dist/axioms.html missing" >&2; exit 1; }
[ -f dist/installing.html ] || { echo "FAIL: dist/installing.html missing" >&2; exit 1; }
[ -f dist/assets/tokens.css ] || { echo "FAIL: dist/assets/tokens.css missing" >&2; exit 1; }

# 7 axioms listed
axiom_count=$(grep -c '<span class="axiom">A[0-9]</span>' dist/axioms.html)
if [ "$axiom_count" -lt 7 ]; then
  echo "FAIL: only $axiom_count axioms listed (expected 7)" >&2
  exit 1
fi

# 45 packet pages
pages=$(ls dist/math/*.html 2>/dev/null | wc -l)
if [ "$pages" -lt 45 ]; then
  echo "FAIL: only $pages packet pages (expected 45+)" >&2
  exit 1
fi

# No CDN references (axiom A3 material basis)
if grep -rE "googleapis|cdnjs|jsdelivr|unpkg" dist/ 2>/dev/null; then
  echo "FAIL: CDN reference found" >&2
  exit 1
fi

# No JavaScript (axiom A3 plain text only)
js_files=$(find dist/ -name '*.js' 2>/dev/null | wc -l)
if [ "$js_files" -ne 0 ]; then
  echo "FAIL: $js_files JavaScript files in dist/" >&2
  exit 1
fi

echo "site design OK: $pages pages, $axiom_count axioms, no CDN, no JS"
exit 0
