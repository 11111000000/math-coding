#!/bin/sh
# core/author/retire-packet.sh — math-coding v0.992 packet retirer.
#
# Usage:
#   sh math-coding retire <name> --reason=<supersession|deprecation>
#                                [--supersede-with=<new-name>]
#                                [--from=<spec.yaml>]
#
# Transitions the packet to retired.
#
# Without --supersede-with, this is the simple two-step supersession:
#
#   sh math-coding retire <name> --reason=supersession
#   sh math-coding create <new-name> --from spec.yaml
#   # then add to new packet.yaml: supersession: math/<name>/
#
# With --supersede-with, this is the atomic one-step supersession:
#
#   sh math-coding retire <name> --reason=supersession \
#       --supersede-with=<new-name> --from=<spec.yaml>
#
#   1. Read spec from --from=<spec.yaml>
#   2. Create new packet <new-name> via create logic
#   3. Add supersession: math/<name>/ to new packet.yaml
#   4. Transition <name> to retired
#   5. verify both
#
# --reason=deprecation transitions the packet to retired without
# a successor. The packet remains for historical reference but
# is no longer applied.

set -u

. "$(dirname "$0")/../lib/common.sh"

usage() {
    cat <<'EOF' >&2
usage: retire-packet.sh <name> --reason=<supersession|deprecation>
           [--supersede-with=<new-name>]
           [--from=<spec.yaml>]

Transitions the packet to retired. Optionally creates a
successor in one atomic operation.

Options:
    --reason=supersession|deprecation
                                 retire reason (required)
    --supersede-with=<new-name>  create successor (atomic)
    --from=<spec.yaml>           spec for successor (with --supersede-with)
    --help -h                    this message
EOF
    exit 2
}

name=""
reason=""
supersede_with=""
spec_file=""

while [ $# -gt 0 ]; do
    case "$1" in
        --reason=*) reason="${1#--reason=}"; shift ;;
        --supersede-with=*) supersede_with="${1#--supersede-with=}"; shift ;;
        --from=*) spec_file="${1#--from=}"; shift ;;
        --help|-h) usage ;;
        -*) echo "unknown flag: $1" >&2; usage ;;
        *) name="$1"; shift ;;
    esac
done

[ -z "$name" ] && usage
[ -z "$reason" ] && { echo "error: --reason=<supersession|deprecation> required" >&2; usage; }

case "$reason" in
    supersession|deprecation) ;;
    *) echo "error: --reason must be 'supersession' or 'deprecation'" >&2; exit 1 ;;
esac

DEST="$MATH_DIR/$name"
[ -d "$DEST" ] || { echo "error: $DEST not found" >&2; exit 2; }
[ -f "$DEST/packet.yaml" ] || { echo "error: $DEST/packet.yaml not found" >&2; exit 2; }

# Check current lifecycle
lifecycle=$(get_lifecycle "$DEST/packet.yaml")

case "$lifecycle" in
    retired)
        echo "warning: packet already retired" >&2
        ;;
    draft|applied)
        ;;
    *)
        echo "error: invalid lifecycle '$lifecycle'" >&2
        exit 1
        ;;
esac

# If --supersede-with: atomic supersession workflow
if [ -n "$supersede_with" ]; then
    [ "$reason" != "supersession" ] && { echo "error: --supersede-with requires --reason=supersession" >&2; exit 1; }
    [ -z "$spec_file" ] && { echo "error: --supersede-with requires --from=<spec.yaml>" >&2; exit 1; }
    [ ! -f "$spec_file" ] && { echo "error: $spec_file not found" >&2; exit 2; }

    NEW_DEST="$MATH_DIR/$supersede_with"
    [ -e "$NEW_DEST" ] && { echo "error: $NEW_DEST already exists" >&2; exit 1; }

    # 1. Create new packet from spec
    echo "Creating successor: $supersede_with"
    if ! sh "$REPO_ROOT/core/author/create-packet.sh" "$supersede_with" --from "$spec_file" >/dev/null 2>&1; then
        echo "error: failed to create successor packet" >&2
        exit 1
    fi

    # 2. Add supersession: math/<name>/ to new packet.yaml
    if ! grep -q '^supersession:' "$NEW_DEST/packet.yaml"; then
        sed -i "/^task_id: /a\\
supersession: math/$name/" "$NEW_DEST/packet.yaml"
    fi

    # 3. Transition old packet to retired
    sed -i 's/^lifecycle: .*/lifecycle: retired/' "$DEST/packet.yaml"
    if ! grep -q '^retire_reason:' "$DEST/packet.yaml"; then
        sed -i "/^lifecycle: retired$/a\\
retire_reason: $reason" "$DEST/packet.yaml"
    fi

    # 4. verify
    if sh "$REPO_ROOT/core/check/verify.sh" >/dev/null 2>&1; then
        echo "Atomic supersession complete."
        echo "  retired: $name"
        echo "  successor: $supersede_with (supersession: math/$name/)"
        echo "  verify: ok"
    else
        echo "Atomic supersession: verify FAILED"
        exit 1
    fi
    exit 0
fi

# Simple retire (no successor)
sed -i 's/^lifecycle: .*/lifecycle: retired/' "$DEST/packet.yaml"
if ! grep -q '^retire_reason:' "$DEST/packet.yaml"; then
    sed -i "/^lifecycle: retired$/a\\
retire_reason: $reason" "$DEST/packet.yaml"
fi

echo "Retired: $name"
echo "  reason: $reason"
echo "  applications[]: frozen (no new SHA can be added)"

if [ "$reason" = "supersession" ]; then
    echo ""
    echo "Next: create the successor manually:"
    echo "  sh math-coding create <new-name> --from spec.yaml"
    echo "  # then add to new packet.yaml:"
    echo "  #   supersession: math/$name/"
    echo ""
    echo "Or use atomic supersession:"
    echo "  sh math-coding retire $name --reason=supersession \\"
    echo "      --supersede-with=<new-name> --from=<spec.yaml>"
fi