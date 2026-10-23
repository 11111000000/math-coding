#!/usr/bin/env bash
# Repairs the OCaml attribute syntax `let[@warning "-32]` -> `let[@warning "-32"]`.
# The broken form is an UNTERMINATED STRING, so the lexer swallows the
# rest of the file and reports the error far from its cause.
set -uo pipefail
cd "$(dirname "$0")/.."
n=0
for f in lib/*.ml lib/*/*.ml bin/*.ml; do
  [ -f "$f" ] || continue
  c=$(grep -c 'warning "-32\]' "$f" 2>/dev/null || true)
  if [ "${c:-0}" != "0" ]; then
    sed -i 's/warning "-32\]/warning "-32"]/g' "$f"
    echo "  fixed $c in $f"; n=$((n+c))
  fi
done
echo "fix-attr: $n"
