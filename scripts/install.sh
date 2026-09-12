#!/bin/sh
# scripts/install.sh — math-coding v1.0 installer.
#
# Builds the OCaml binary and installs to $XDG_DATA_HOME/math-coding/.
# Requires OCaml 5.x + dune 3.x + ocamlfind. Easiest via flake:
#
#   nix develop --command sh scripts/install.sh
#
# Or after opam switch on the right compiler.

set -u

VERSION="${MATH_CODING_VERSION:-0.1.0}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALL_DIR="$DATA/math-coding/$VERSION"
CURRENT_LINK="$DATA/math-coding/current"

# Locate repo root regardless of where this script is invoked from.
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT" || exit 1

# Detect dune in PATH or fail clearly.
DUNE_BIN=$(command -v dune 2>/dev/null || true)
if [ -z "$DUNE_BIN" ]; then
    cat >&2 <<EOF
error: dune not found in PATH.

math-coding v1.0 is built with dune. Either:

  1. Nix shell (recommended):

       nix develop --command sh scripts/install.sh

  2. opam switch with OCaml 5.x + dune + dune-installed deps:

       opam switch create 5.2.0
       opam install dune yaml yojson alcotest qcheck
       sh scripts/install.sh

EOF
    exit 1
fi

"$DUNE_BIN" build --profile=release || { echo "build failed" >&2; exit 1; }

BIN=_build/default/src/main.exe
[ -f "$BIN" ] || { echo "build artifact missing: $BIN" >&2; exit 1; }

mkdir -p "$INSTALL_DIR"
cp "$BIN" "$INSTALL_DIR/math-coding"
chmod +x "$INSTALL_DIR/math-coding"

if [ -L "$CURRENT_LINK" ] || [ -e "$CURRENT_LINK" ]; then
    cur_target=$(readlink "$CURRENT_LINK" 2>/dev/null || true)
    if [ "$cur_target" != "$VERSION" ]; then
        rm -f "$CURRENT_LINK"
    fi
fi
[ -L "$CURRENT_LINK" ] || ln -s "$VERSION" "$CURRENT_LINK"

# Drop a small project wrapper next to the script so users can invoke
# `math-coding` directly from any project root without polluting it.
WRAPPER="$REPO_ROOT/math-coding"
if [ ! -e "$WRAPPER" ]; then
    cat > "$WRAPPER" <<'WRAP'
#!/bin/sh
# math-coding wrapper — runs shared install or local .math-coding/math-coding.
# Safe to commit: it lives at the project root and is auto-detected.
set -u
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
TARGET=""
for d in "$DATA/math-coding/current" /usr/local/share/math-coding/current; do
    if [ -x "$d/math-coding" ]; then
        TARGET="$d/math-coding"
        break
    fi
done
if [ -z "$TARGET" ] && [ -x "./.math-coding/math-coding" ]; then
    TARGET="./.math-coding/math-coding"
fi
if [ -z "$TARGET" ]; then
    echo "math-coding: no install found. Run:" >&2
    echo "    sh scripts/install.sh" >&2
    exit 127
fi
exec "$TARGET" "$@"
WRAP
    chmod +x "$WRAPPER"
fi

echo "installed math-coding $VERSION"
echo "  binary:    $INSTALL_DIR/math-coding"
echo "  symlink:   $CURRENT_LINK -> $VERSION"
echo "  wrapper:   $WRAPPER"
echo ""
echo "verify:    $WRAPPER --proposition=\"...\" check"
