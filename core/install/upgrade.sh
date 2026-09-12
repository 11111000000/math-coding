#!/bin/sh
# core/install/upgrade.sh — math-coding v0.993 shared upgrader.
#
# Usage: sh core/install/upgrade.sh
#
# Refreshes the shared install at $XDG_DATA_HOME/math-coding/<ver>/
# from the current source-repo. The active symlink `current` keeps
# pointing at this version. Project wrappers resolve at runtime;
# nothing in the project repo changes.

set -u

. "$(dirname "$0")/../lib/common.sh"

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
DATA_DIR="$DATA/math-coding"
VERSION_DIR="$DATA_DIR/$VERSION"
CURRENT_LINK="$DATA_DIR/current"

if [ ! -L "$CURRENT_LINK" ] && [ ! -e "$CURRENT_LINK" ]; then
    echo "error: $CURRENT_LINK missing; run install.sh first" >&2
    exit 2
fi

mkdir -p "$VERSION_DIR" || { echo "error: cannot create $VERSION_DIR" >&2; exit 1; }

for d in core extensions; do
    if [ -d "$REPO_ROOT/$d" ]; then
        rm -rf "$VERSION_DIR/$d"
        cp -R "$REPO_ROOT/$d" "$VERSION_DIR/$d"
    fi
done

if [ -f "$REPO_ROOT/math-coding" ]; then
    cp "$REPO_ROOT/math-coding" "$VERSION_DIR/math-coding"
    chmod +x "$VERSION_DIR/math-coding"
fi

# Re-point current to this version.
cur_target=$(readlink "$CURRENT_LINK" 2>/dev/null || true)
if [ "$cur_target" != "$VERSION" ]; then
    rm -f "$CURRENT_LINK"
    ln -s "$VERSION" "$CURRENT_LINK"
fi

echo "upgraded shared install → $VERSION_DIR"
echo "  symlink: $CURRENT_LINK → $VERSION"
