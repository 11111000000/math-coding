#!/bin/sh
# tools/run-site.sh — executable spec for site-v1-build-toolchain packet.
#
# Re-renders the static site from math/, then verifies key invariants.
cd "$(dirname "$0")/../.." || exit 2

# Rebuild site
_build/default/src/main.exe site >/dev/null || exit 1

# Verify no empty <title> (regression test for the html_escape bug)
empty_titles=$(grep -l "<title>math-coding | </title>" dist/math/*.html 2>/dev/null | wc -l)
if [ "$empty_titles" -gt 0 ]; then
  echo "FAIL: $empty_titles empty <title> tags" >&2
  exit 1
fi

# Verify no empty <h1>
empty_h1=$(grep -l "<h1></h1>" dist/math/*.html 2>/dev/null | wc -l)
if [ "$empty_h1" -gt 0 ]; then
  echo "FAIL: $empty_h1 empty <h1> tags" >&2
  exit 1
fi

# Verify axiom packets have an axiom span
axiom_name=$(ls math/0*/*.md 2>/dev/null | head -1 | sed 's|math/||;s|/packet.md||')
if [ -n "$axiom_name" ]; then
  if ! grep -q "class=\"axiom\"" "dist/math/${axiom_name}.html"; then
    echo "FAIL: $axiom_name missing axiom span" >&2
    exit 1
  fi
fi

echo "site build OK: $(ls dist/math | wc -l) pages"
exit 0
