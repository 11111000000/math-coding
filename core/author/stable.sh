#!/bin/sh
# core/author/stable.sh — math-coding v0.991 stable marker.
#
# Usage:
#   sh math-coding stable <name>
#   sh math-coding stable <name> --unmark
#
# Marks a packet as stable_since today. Opt-in metadata, not
# a lifecycle state. Signals "this packet is stable; don't
# touch without reason".
#
# No FSM impact. The packet's lifecycle (draft/applied/retired/
# abandoned) is unchanged. Only stable_since field is set/cleared.

set -u

. "$(dirname "$0")/../lib/common.sh"

usage() {
    cat <<'EOF' >&2
usage: stable.sh <name> [--unmark]

Mark a packet as stable_since today. Opt-in metadata.

Options:
    --unmark       clear stable_since (set to null)
    --help -h      this message
EOF
    exit 2
}

name=""
unmark=0

while [ $# -gt 0 ]; do
    case "$1" in
        --unmark)    unmark=1; shift ;;
        --help|-h)   usage ;;
        -*)          echo "unknown flag: $1" >&2; usage ;;
        *)           name="$1"; shift ;;
    esac
done

[ -z "$name" ] && usage

DEST="$MATH_DIR/$name"
[ -d "$DEST" ] || { echo "error: $DEST not found" >&2; exit 2; }
[ -f "$DEST/packet.yaml" ] || { echo "error: $DEST/packet.yaml not found" >&2; exit 2; }

DATE=$(date -u +%Y-%m-%d)

if [ "$unmark" = "1" ]; then
    sed -i "s/^stable_since: .*/stable_since: null/" "$DEST/packet.yaml"
    echo "Unmarked stable: $name"
    echo "  stable_since: null"
else
    if grep -q "^stable_since:" "$DEST/packet.yaml"; then
        sed -i "s/^stable_since: .*/stable_since: \"$DATE\"/" "$DEST/packet.yaml"
    else
        sed -i "/^created: /a\\
stable_since: \"$DATE\"" "$DEST/packet.yaml"
    fi
    echo "Marked stable: $name"
    echo "  stable_since: $DATE"
    echo ""
    echo "Convention is opt-in. To remove, run: sh math-coding stable $name --unmark"
fi
