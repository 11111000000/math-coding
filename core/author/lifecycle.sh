#!/bin/sh
# core/author/lifecycle.sh — math-coding v0.993 unified lifecycle tool.
#
# Replaces core/author/{apply,review,retire,stable,archive,amend}-packet.sh
# and core/author/abandon-packet.sh, config.sh, extract-packet.sh.
#
# Subcommands and dispatch:
#   apply <name> [opts]      core/author/apply-packet.sh
#   review <name> [opts]     core/author/review-packet.sh
#   retire <name> [opts]     core/author/retire-packet.sh
#   abandon <name> [opts]    inline (was core/author/abandon-packet.sh)
#   stable <name> [opts]     inline (was core/author/stable.sh)
#   archive <name> [opts]    inline (was core/author/archive-packet.sh)
#   amend <name> [opts]      inline (was core/author/amend-packet.sh)
#   extract <name>           inline (was core/author/extract-packet.sh)
#
# Inline subcommands are short enough to live here; the larger ones
# (apply, review, retire) keep their own files for clarity.

set -u

. "$(dirname "$0")/../lib/common.sh"

usage() {
    cat <<EOF >&2
usage: lifecycle.sh <subcommand> <name> [options]

Subcommands:
    apply <name>           Record SHA witness and transition to applied.
    review <name>          Peer-review.
    retire <name>          Transition to retired.
    abandon <name>         Transition draft → abandoned.
    stable <name>          Mark packet as stable_since today.
    archive <name>         Move to math/archived/.
    amend <name>           Record a formal amendment.
    extract <name>         Emit YAML spec for an existing packet to stdout.
EOF
    exit 2
}

[ $# -ge 1 ] || usage
subcmd="$1"; shift

# Legacy: `lifecycle.sh <name> <state>` (no subcommand).
# Detect by second-arg being a known lifecycle state.
if [ $# -ge 1 ] && case "$subcmd" in
    applied|retired|abandoned|draft) true ;;
    *) false ;;
esac; then
    # subcmd is actually the name, second arg is the state.
    state="$subcmd"
    name="${1:-}"
    shift || true
    case "$state" in
        applied)   exec sh "$REPO_ROOT/core/author/apply-packet.sh" "$name" "$@" ;;
        retired)   exec sh "$REPO_ROOT/core/author/retire-packet.sh" "$name" "$@" ;;
        abandoned) exec sh "$REPO_ROOT/core/author/lifecycle.sh" abandon "$name" "$@" ;;
        draft)     echo "error: cannot transition to 'draft' (use create for new packet)" >&2; exit 1 ;;
        *)         echo "error: unknown state '$state'" >&2; exit 2 ;;
    esac
fi

case "$subcmd" in
    apply)
        exec sh "$REPO_ROOT/core/author/apply-packet.sh" "$@"
        ;;
    review)
        exec sh "$REPO_ROOT/core/author/review-packet.sh" "$@"
        ;;
    retire)
        exec sh "$REPO_ROOT/core/author/retire-packet.sh" "$@"
        ;;
    abandon)
        name="${1:?usage: lifecycle.sh abandon <name> [--reason=\"...\"]}"
        DEST="$MATH_DIR/$name"
        [ -d "$DEST" ] || { echo "error: $DEST not found" >&2; exit 2; }
        reason=""
        for arg in "$@"; do
            case "$arg" in
                --reason=*) reason="${arg#--reason=}" ;;
                --reason)   shift; reason="$1" ;;
            esac
        done
        lc=$(get_lifecycle "$DEST/packet.yaml")
        case "$lc" in
            draft) new_lc="abandoned" ;;
            applied|retired)
                echo "error: cannot transition $lc → abandoned; use retire" >&2
                exit 1
                ;;
            abandoned)
                echo "info: $name already abandoned" >&2
                exit 0
                ;;
            *)
                echo "error: invalid lifecycle '$lc'" >&2
                exit 1
                ;;
        esac
        awk -v v="$new_lc" -v r="$reason" '
            /^lifecycle:/ { print "lifecycle: " v; next }
            /^abandon_reason:/ { print "abandon_reason: " r; next }
            { print }
            END {
                if (r != "") print "abandon_reason: " r
            }
        ' "$DEST/packet.yaml" > "$DEST/packet.yaml.tmp" && \
            mv "$DEST/packet.yaml.tmp" "$DEST/packet.yaml"
        echo "$name: draft → abandoned"
        ;;
    stable)
        name="${1:?usage: lifecycle.sh stable <name> [--unmark]}"
        DEST="$MATH_DIR/$name"
        [ -d "$DEST" ] || { echo "error: $DEST not found" >&2; exit 2; }
        date=$(date -u +%Y-%m-%d)
        if [ "${2:-}" = "--unmark" ]; then
            awk '
                /^stable_since:/ { print "stable_since: null"; next }
                { print }
            ' "$DEST/packet.yaml" > "$DEST/packet.yaml.tmp" && \
                mv "$DEST/packet.yaml.tmp" "$DEST/packet.yaml"
            echo "$name: stable_since cleared"
        else
            awk -v d="$date" '
                /^stable_since:/ { print "stable_since: " d; next }
                { print }
            ' "$DEST/packet.yaml" > "$DEST/packet.yaml.tmp" && \
                mv "$DEST/packet.yaml.tmp" "$DEST/packet.yaml"
            echo "$name: stable_since=$date"
        fi
        ;;
    archive)
        name="${1:?usage: lifecycle.sh archive <name> [--confirm]}"
        DEST="$MATH_DIR/$name"
        [ -d "$DEST" ] || { echo "error: $DEST not found" >&2; exit 2; }
        [ "${2:-}" = "--confirm" ] || {
            echo "error: archive moves the packet out of math/; pass --confirm" >&2
            exit 1
        }
        lc=$(get_lifecycle "$DEST/packet.yaml")
        if [ "$lc" != "retired" ] && [ "$lc" != "abandoned" ]; then
            echo "error: only retired/abandoned packets can be archived (was $lc)" >&2
            exit 1
        fi
        ARCHIVE_DIR="$MATH_DIR/archived"
        mkdir -p "$ARCHIVE_DIR"
        git -C "$REPO_ROOT" mv "$DEST" "$ARCHIVE_DIR/$name" 2>/dev/null || \
            mv "$DEST" "$ARCHIVE_DIR/$name"
        echo "$name: moved to math/archived/$name/"
        ;;
    amend)
        name="${1:?usage: lifecycle.sh amend <name> --reason=\"...\"}"
        DEST="$MATH_DIR/$name"
        [ -d "$DEST" ] || { echo "error: $DEST not found" >&2; exit 2; }
        lc=$(get_lifecycle "$DEST/packet.yaml")
        if [ "$lc" = "applied" ]; then
            echo "error: cannot amend an applied packet (use retire + new packet)" >&2
            exit 1
        fi
        reason=""
        by_name="${USER:-agent}"
        for arg in "$@"; do
            case "$arg" in
                --reason=*) reason="${arg#--reason=}" ;;
                --by=*)     by_name="${arg#--by=}" ;;
            esac
        done
        [ -z "$reason" ] && { echo "error: --reason=\"...\" required" >&2; exit 1; }
        sha=$(git -C "$REPO_ROOT" log -1 --format=%H 2>/dev/null)
        date=$(date -u +%Y-%m-%d)
        tmp=$(mktemp)
        awk -v by="$by_name" -v date="$date" -v reason="$reason" -v sha="$sha" '
            /^amendments:/ { in_block = 1; print; next }
            in_block && /^[^ ]/ { in_block = 0 }
            in_block && /^  - / {
                print "  - date: \"" date "\""
                print "    by: " by
                print "    reason: \"" reason "\""
                print "    sha: " sha
                next
            }
            { print }
            END {
                if (!in_block) {
                    print "amendments:"
                    print "  - date: \"" date "\""
                    print "    by: " by
                    print "    reason: \"" reason "\""
                    print "    sha: " sha
                }
            }
        ' "$DEST/packet.yaml" > "$tmp" && mv "$tmp" "$DEST/packet.yaml"
        echo "$name: amendment recorded"
        ;;
    extract)
        name="${1:?usage: lifecycle.sh extract <name>}"
        DEST="$MATH_DIR/$name"
        [ -d "$DEST" ] || { echo "error: $DEST not found" >&2; exit 2; }
        awk '
            /^## Thesis/,/^## /' "$DEST/decision.md" | head -20 | sed 's/^/  /'
        ;;
    *)
        echo "lifecycle.sh: unknown subcommand '$subcmd'" >&2
        usage >&2
        ;;
esac
