#!/bin/sh
# core/install/install.sh — math-coding v0.854 brownfield installer.
#
# Usage: sh core/install/install.sh <target-dir>
#
# Copies the convention's core/ payload, theories/,
# docs/, and the dispatcher into a target project, creating
# a `.math-coding/` directory and a `.mathrc` config.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET="${1:?usage: sh core/install/install.sh <target-dir>}"

# Resolve to absolute
TARGET="$(cd "$TARGET" && pwd)"

if [ ! -d "$TARGET" ]; then
    echo "error: target $TARGET is not a directory" >&2
    exit 2
fi

DEST="$TARGET/.math-coding"

if [ -d "$DEST" ]; then
    echo "error: $DEST already exists" >&2
    exit 1
fi

mkdir -p "$DEST"

# Copy core/, theories/, docs/, math/ (axiom packets)
for d in core theories docs math; do
    cp -R "$REPO_ROOT/$d" "$DEST/$d"
done

# Copy dispatcher
cp "$REPO_ROOT/math-coding" "$DEST/math-coding"
chmod +x "$DEST/math-coding"

# Create .mathrc if absent
if [ ! -f "$TARGET/.mathrc" ]; then
    cat > "$TARGET/.mathrc" <<'EOF'
# math-coding configuration (installed)
mode: standard
role: developer
lookahead_ok: 0
EOF
fi

# Add .math-coding/ to .gitignore if absent
GITIGNORE="$TARGET/.gitignore"
if [ -f "$GITIGNORE" ]; then
    if ! grep -q "^.math-coding/$" "$GITIGNORE"; then
        echo ".math-coding/" >> "$GITIGNORE"
    fi
else
    echo ".math-coding/" > "$GITIGNORE"
fi

echo "installed math-coding to $DEST"
echo "  core/      $(find "$DEST/core" -type f 2>/dev/null | wc -l | tr -d ' ') files"
echo "  theories/  $(find "$DEST/theories" -type f 2>/dev/null | wc -l | tr -d ' ') files"
echo "  docs/      $(find "$DEST/docs" -type f 2>/dev/null | wc -l | tr -d ' ') files"
echo "  math-coding (dispatcher)"
echo ""
echo "verify:  sh $DEST/math-coding probe"