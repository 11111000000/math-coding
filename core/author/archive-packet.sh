#!/bin/sh
# core/author/archive-packet.sh — math-coding v0.991 packet archiver.
#
# Usage:
#   sh math-coding archive <name> [--confirm]
#
# Moves a retired packet from math/<name>/ to math/archived/<name>/.
# The packet is preserved in git history and remains accessible for
# review, but is excluded from verify and probe (only top-level
# math/ packets are checked).
#
# Requires:
#   - packet must be in lifecycle: retired
#   - --confirm flag (explicit acknowledgment)
#
# To permanently remove an archived packet:
#   rm -rf math/archived/<name>/
#   git add math/archived/ && git commit -m "remove archived/<name>"

set -u

. "$(dirname "$0")/../lib/common.sh"

usage() {
    cat <<'EOF' >&2
usage: archive-packet.sh <name> [--confirm]

Moves a retired packet to math/archived/<name>/.

Options:
    --confirm           required: explicit acknowledgment
    --help -h           this message
EOF
    exit 2
}

name=""
confirm=""

while [ $# -gt 0 ]; do
    case "$1" in
        --confirm) confirm=1; shift ;;
        --help|-h) usage ;;
        -*) echo "unknown flag: $1" >&2; usage ;;
        *) name="$1"; shift ;;
    esac
done

[ -z "$name" ] && usage
[ -z "$confirm" ] && { echo "error: --confirm required" >&2; usage; }

DEST="$MATH_DIR/$name"
[ -d "$DEST" ] || { echo "error: $DEST not found" >&2; exit 2; }

[ -f "$DEST/packet.yaml" ] || { echo "error: packet.yaml missing" >&2; exit 1; }

lifecycle=$(get_lifecycle "$DEST/packet.yaml")

if [ "$lifecycle" != "retired" ]; then
    echo "error: can only archive retired packets (current: $lifecycle)" >&2
    echo "       run: sh math-coding retire $name --reason=<supersession|deprecation>" >&2
    exit 1
fi

ARCHIVE_DIR="$MATH_DIR/archived"
mkdir -p "$ARCHIVE_DIR"

ARCHIVE_DEST="$ARCHIVE_DIR/$name"

if [ -e "$ARCHIVE_DEST" ]; then
    echo "error: $ARCHIVE_DEST already exists" >&2
    exit 1
fi

# Move packet to archived directory. git tracks renames.
mv "$DEST" "$ARCHIVE_DEST"

echo "Archived: $name"
echo "  moved from: $DEST"
echo "  moved to:   $ARCHIVE_DEST"
echo "  preserved in: git history (git log --follow -- math/archived/$name/)"
echo ""
echo "Note: archived packets are excluded from verify and probe."
echo "To permanently remove: rm -rf $ARCHIVE_DEST"