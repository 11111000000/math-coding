#!/bin/sh
# core/author/abandon-packet.sh — math-coding v0.992 packet abandoner.
#
# Usage:
#   sh math-coding abandon <name> [--reason="<text>"]
#
# Transitions a draft packet to abandoned. Use this when a
# packet was created but will not be implemented (proposition
# proved wrong, requirement cancelled, etc.).
#
# v0.991: lifecycle FSM has 4 states.
#   draft → applied (apply)
#   draft → abandoned (abandon — this command)
#   draft → retired (retire --reason=deprecation)
#   applied → retired (retire)
#   retired, abandoned — terminal
#
# If lifecycle_abandoned_enabled=no in .mathrc, this command
# refuses to run.

set -u

. "$(dirname "$0")/../lib/common.sh"

usage() {
    cat <<'EOF' >&2
usage: abandon-packet.sh <name> [--reason="<text>"]

Transitions a draft packet to abandoned.

Options:
    --reason="<text>"   reason for abandonment
    --help -h           this message
EOF
    exit 2
}

if [ "$LIFECYCLE_ABANDONED_ENABLED" != "yes" ]; then
    echo "error: lifecycle_abandoned_enabled=no in .mathrc; abandon command disabled" >&2
    exit 1
fi

name=""
reason=""

while [ $# -gt 0 ]; do
    case "$1" in
        --reason=*) reason="${1#--reason=}"; shift ;;
        --help|-h) usage ;;
        -*) echo "unknown flag: $1" >&2; usage ;;
        *) name="$1"; shift ;;
    esac
done

[ -z "$name" ] && usage

DEST="$MATH_DIR/$name"
[ -d "$DEST" ] || { echo "error: $DEST not found" >&2; exit 2; }
[ -f "$DEST/packet.yaml" ] || { echo "error: $DEST/packet.yaml not found" >&2; exit 2; }

lifecycle=$(get_lifecycle "$DEST/packet.yaml")

case "$lifecycle" in
    draft)
        ;;
    applied)
        echo "error: cannot abandon applied packet; use 'retire' instead" >&2
        exit 1
        ;;
    retired)
        echo "warning: packet already retired" >&2
        ;;
    abandoned)
        echo "warning: packet already abandoned" >&2
        ;;
    *)
        echo "error: invalid lifecycle '$lifecycle'" >&2
        exit 1
        ;;
esac

# Transition to abandoned
sed -i 's/^lifecycle: .*/lifecycle: abandoned/' "$DEST/packet.yaml"

if ! grep -q '^abandon_reason:' "$DEST/packet.yaml"; then
    if [ -n "$reason" ]; then
        sed -i "/^lifecycle: abandoned$/a\\
abandon_reason: $reason" "$DEST/packet.yaml"
    fi
fi

echo "Abandoned: $name"
echo "  lifecycle: abandoned (terminal)"
[ -n "$reason" ] && echo "  reason: $reason"
echo ""
echo "Note: abandoned packets are excluded from 'applied' and"
echo "remain in math/ for historical record. To remove entirely,"
echo "use git rm and commit."