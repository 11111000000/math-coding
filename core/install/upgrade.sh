#!/bin/sh
# core/install/upgrade.sh — math-coding v0.854 brownfield upgrader.
#
# Usage: sh core/install/upgrade.sh <target-dir>
#
# Overwrites the .math-coding/ payload in a target project
# with the current convention's core/, theories/, docs/, and
# dispatcher. The .mathrc file is preserved (user config).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET="${1:?usage: sh core/install/upgrade.sh <target-dir>}"

TARGET="$(cd "$TARGET" && pwd)"
DEST="$TARGET/.math-coding"

if [ ! -d "$DEST" ]; then
    echo "error: $DEST does not exist; run install.sh first" >&2
    exit 2
fi

# Remove old payload, install new
for d in core theories docs; do
    if [ -d "$DEST/$d" ]; then
        rm -rf "$DEST/$d"
    fi
done

for d in core theories docs; do
    if [ -d "$REPO_ROOT/$d" ]; then
        cp -R "$REPO_ROOT/$d" "$DEST/$d"
    fi
done

cp "$REPO_ROOT/math-coding" "$DEST/math-coding"
chmod +x "$DEST/math-coding"

echo "upgraded math-coding in $DEST"