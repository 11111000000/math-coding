#!/bin/sh
# scripts/install.sh — math-coding v2.0-Y installer.
#
# Builds the OCaml binary and installs to $XDG_DATA_HOME/math-coding/.
# Requires OCaml 5.x + dune 3.x.
#
#   nix develop --command sh scripts/install.sh
#
# Or after opam switch on the right compiler.

set -u

VERSION="${MATH_CODING_VERSION:-2.0.0}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALL_DIR="$DATA/math-coding/$VERSION"
CURRENT_LINK="$DATA/math-coding/current"

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT" || exit 1

DUNE_BIN=$(command -v dune 2>/dev/null || true)
if [ -z "$DUNE_BIN" ]; then
    cat >&2 <<'EOF'
error: dune not found in PATH.

math-coding is built with dune. Either:

  1. Nix shell (recommended):

       nix develop --command sh scripts/install.sh

  2. opam switch with OCaml 5.x + dune:

       opam switch create 5.2.0
       opam install dune
       sh scripts/install.sh

EOF
    exit 1
fi

"$DUNE_BIN" build --profile=release core/main.exe || { echo "build failed" >&2; exit 1; }

BIN=_build/default/core/main.exe
[ -f "$BIN" ] || { echo "build artifact missing: $BIN" >&2; exit 1; }

mkdir -p "$INSTALL_DIR"
cp "$BIN" "$INSTALL_DIR/mathc"
chmod +x "$INSTALL_DIR/mathc"

if [ -L "$CURRENT_LINK" ] || [ -e "$CURRENT_LINK" ]; then
    cur_target=$(readlink "$CURRENT_LINK" 2>/dev/null || true)
    if [ "$cur_target" != "$VERSION" ]; then
        rm -f "$CURRENT_LINK"
    fi
fi
[ -L "$CURRENT_LINK" ] || ln -s "$VERSION" "$CURRENT_LINK"

WRAPPER="$REPO_ROOT/mathc"
if [ ! -e "$WRAPPER" ]; then
    cat > "$WRAPPER" <<'WRAP'
#!/bin/sh
# mathc wrapper — runs shared install.
# Safe to commit: it contains no project state.
set -u
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
TARGET=""
for d in "$DATA/math-coding/current" /usr/local/share/math-coding/current; do
    if [ -x "$d/mathc" ]; then
        TARGET="$d/mathc"
        break
    fi
done
if [ -z "$TARGET" ]; then
    echo "mathc: no install found. Run:" >&2
    echo "    sh scripts/install.sh" >&2
    exit 127
fi
exec "$TARGET" "$@"
WRAP
    chmod +x "$WRAPPER"
fi

echo "installed mathc $VERSION"
echo "  binary:    $INSTALL_DIR/mathc"
echo "  symlink:   $CURRENT_LINK -> $VERSION"
echo "  wrapper:   $WRAPPER"
echo ""
echo "verify:    $WRAPPER help"