#!/bin/sh
# core/install/uninstall.sh — math-coding v0.993 uninstaller.
#
# Usage: sh core/install/uninstall.sh <target-dir> [--purge-shared]
#
# Removes the project wrapper + .mathrc and (if --local layout)
# .math-coding/. Shared payload at $XDG_DATA_HOME/math-coding/ is
# kept by default; --purge-shared removes it.

set -u

TARGET=""
PURGE_SHARED=0

while [ $# -gt 0 ]; do
    case "$1" in
        --purge-shared) PURGE_SHARED=1; shift ;;
        --help|-h) echo "usage: uninstall.sh <target-dir> [--purge-shared]" >&2; exit 2 ;;
        -*) echo "unknown flag: $1" >&2; exit 2 ;;
        *) TARGET="$1"; shift ;;
    esac
done

[ -z "$TARGET" ] && { echo "usage: uninstall.sh <target-dir> [--purge-shared]" >&2; exit 2; }
TARGET="$(cd "$TARGET" && pwd)"

WRAPPER="$TARGET/math-coding"
LOCAL_PAYLOAD="$TARGET/.math-coding"

# Remove project wrapper.
[ -f "$WRAPPER" ] && rm -f "$WRAPPER"

# Remove legacy .math-coding/ if present (local layout).
if [ -d "$LOCAL_PAYLOAD" ]; then
    rm -rf "$LOCAL_PAYLOAD"
fi

# Drop .math-coding/ from .gitignore.
GITIGNORE="$TARGET/.gitignore"
if [ -f "$GITIGNORE" ] && grep -q "^.math-coding/$" "$GITIGNORE"; then
    grep -v "^.math-coding/$" "$GITIGNORE" > "$GITIGNORE.tmp"
    mv "$GITIGNORE.tmp" "$GITIGNORE"
fi

# Optional: purge shared payload.
if [ "$PURGE_SHARED" = "1" ]; then
    DATA="${XDG_DATA_HOME:-$HOME/.local/share}/math-coding"
    if [ -d "$DATA" ]; then
        rm -rf "$DATA"
        echo "purged shared payload at $DATA"
    fi
fi

echo "uninstalled math-coding from $TARGET"
echo "  .mathrc preserved (user config)"
