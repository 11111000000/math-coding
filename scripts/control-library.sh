#!/bin/sh
# A library of negative controls for common classes of change.
# Usage: control-library.sh MODE FILE
set -eu

mode=${1:?mode}
file=${2:?file}

case "$mode" in
  invert-boolean)
    sed -i 's/= true/= false/g' "$file"
    ;;
  break-constant)
    sed -i 's/let bound = [0-9][0-9]*/let bound = 0/' "$file"
    ;;
  drop-check)
    sed -i '/if not condition/,+1d' "$file"
    ;;
  break-string)
    sed -i 's/expected/broken/' "$file"
    ;;
  *)
    printf 'control-library: unknown mode: %s\n' "$mode" >&2
    exit 2
    ;;
esac
