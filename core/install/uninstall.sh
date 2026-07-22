#!/bin/sh
# core/install/uninstall.sh — math-coding v0.992 brownfield uninstaller.
#
# Usage: sh core/install/uninstall.sh <target-dir>
#
# Removes the .math-coding/ directory from a target project.
# Does not touch .mathrc (user config).

set -u

TARGET="${1:?usage: sh core/install/uninstall.sh <target-dir>}"
TARGET="$(cd "$TARGET" && pwd)"
DEST="$TARGET/.math-coding"

if [ ! -d "$DEST" ]; then
    echo "error: $DEST does not exist" >&2
    exit 2
fi

rm -rf "$DEST"

# Remove from .gitignore
GITIGNORE="$TARGET/.gitignore"
if [ -f "$GITIGNORE" ] && grep -q "^.math-coding/$" "$GITIGNORE"; then
    grep -v "^.math-coding/$" "$GITIGNORE" > "$GITIGNORE.tmp"
    mv "$GITIGNORE.tmp" "$GITIGNORE"
fi

echo "uninstalled math-coding from $DEST"
echo "  .mathrc preserved (user config)"