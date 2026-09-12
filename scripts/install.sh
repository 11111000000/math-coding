#!/bin/sh
# scripts/install.sh — math-coding v1.0 installer.
#
# Builds the OCaml binary and installs to $XDG_DATA_HOME/math-coding/.
# One static binary, no per-project payload.

set -u

VERSION="${MATH_CODING_VERSION:-0.1.0}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALL_DIR="$DATA/math-coding/$VERSION"
CURRENT_LINK="$DATA/math-coding/current"

cd "$(dirname "$0")/.." || exit 1

mkdir -p "$INSTALL_DIR"
dune build --profile=release || { echo "build failed" >&2; exit 1; }

BIN=_build/default/src/main.exe
[ -f "$BIN" ] || { echo "build artifact missing: $BIN" >&2; exit 1; }

cp "$BIN" "$INSTALL_DIR/math-coding"
chmod +x "$INSTALL_DIR/math-coding"

# Replace current symlink if pointing elsewhere.
if [ -L "$CURRENT_LINK" ] || [ -e "$CURRENT_LINK" ]; then
    cur_target=$(readlink "$CURRENT_LINK" 2>/dev/null || true)
    if [ "$cur_target" != "$VERSION" ]; then
        rm -f "$CURRENT_LINK"
    fi
fi
[ -L "$CURRENT_LINK" ] || ln -s "$VERSION" "$CURRENT_LINK"

echo "installed math-coding $VERSION"
echo "  binary: $INSTALL_DIR/math-coding"
echo "  symlink: $CURRENT_LINK -> $VERSION"

