#!/bin/sh
# core/author/amend-packet.sh — math-coding v0.992 amendment recorder.
#
# Usage:
#   sh math-coding amend <name> --reason="<text>" [--by=<name>]
#
# Records a formal amendment to an existing packet. Appends an
# entry to packet.yaml:amendments[] with date, by, reason, and
# the current HEAD sha as witness.
#
# v0.992: amendments are append-only. The lifecycle state of the
# packet is not changed by amend (use apply/retire for that).
# Peer-review: 1 reviewer required (no self-approve; same gate as
# normal review — single-author reviews need single_author: true).

set -u

. "$(dirname "$0")/../lib/common.sh"

usage() {
    cat <<'EOF' >&2
usage: amend-packet.sh <name> --reason="<text>" [--by=<name>]

Records a formal amendment to a packet.

Options:
    --reason="<text>"   why this amendment is being made (required)
    --by=<name>         author of the amendment (default: $USER)
    --help -h           this message
EOF
    exit 2
}

name=""
reason=""
by_name="${USER:-agent}"

while [ $# -gt 0 ]; do
    case "$1" in
        --reason=*) reason="${1#--reason=}"; shift ;;
        --by=*) by_name="${1#--by=}"; shift ;;
        --help|-h) usage ;;
        -*) echo "unknown flag: $1" >&2; usage ;;
        *) name="$1"; shift ;;
    esac
done

[ -z "$name" ] && usage
[ -z "$reason" ] && { echo "error: --reason is required" >&2; usage; }

DEST="$MATH_DIR/$name"
[ -d "$DEST" ] || { echo "error: $DEST not found" >&2; exit 2; }
[ -f "$DEST/packet.yaml" ] || { echo "error: $DEST/packet.yaml not found" >&2; exit 2; }

# v0.992: amend is forbidden on applied packets. Production-ready
# state means a peer has approved; silently rewriting the
# proposition bypasses that approval. To change an applied
# packet, retire it (with reason) and create a successor.
lifecycle=$(get_lifecycle "$DEST/packet.yaml")
if [ "$lifecycle" = "applied" ]; then
    echo "error: cannot amend an applied packet (axiom Accounting)" >&2
    echo "       applied packets have peer-reviewed propositions" >&2
    echo "       to change: sh math-coding retire $name --reason=supersession" >&2
    echo "                  sh math-coding create <new-name> --from <spec>" >&2
    exit 1
fi

date=$(date -u +%Y-%m-%d)

# v0.992: self-approve guard (same rule as review-packet).
packet_creator=$(grep '^creator:' "$DEST/packet.yaml" | sed 's/^creator:[[:space:]]*//')
if [ -n "$packet_creator" ] && [ "$by_name" = "$packet_creator" ] && [ "$packet_creator" != "agent" ]; then
    if [ "$SELF_APPROVE_ALLOWED" != "yes" ]; then
        echo "warning: amend by=$by_name matches packet creator" >&2
        echo "         a different reviewer should run: sh math-coding review $name --approve --by=<other>" >&2
    fi
fi

# Witness SHA at amend time (current HEAD).
sha=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Append entry to amendments: block. Create block if absent.
tmp_yaml=$(mktemp) || { echo "error: mktemp failed" >&2; exit 1; }

if grep -q '^amendments:' "$DEST/packet.yaml"; then
    awk -v date="$date" -v by="$by_name" -v reason="$reason" -v sha="$sha" '
        /^amendments:[[:space:]]*\[\]/ {
            print "amendments:"
            print "  - date: \"" date "\""
            print "    by: " by
            print "    reason: |"
            print "      " reason
            print "    sha: " sha
            inserted = 1
            next
        }
        /^amendments:/ && !inserted {
            print
            print "  - date: \"" date "\""
            print "    by: " by
            print "    reason: |"
            print "      " reason
            print "    sha: " sha
            inserted = 1
            next
        }
        { print }
    ' "$DEST/packet.yaml" > "$tmp_yaml"
else
    echo "" >> "$DEST/packet.yaml"
    cat > "$tmp_yaml" <<EOF
amendments:
  - date: "$date"
    by: $by_name
    reason: |
      $reason
    sha: $sha
EOF
    cat "$DEST/packet.yaml" >> "$tmp_yaml"
fi

mv "$tmp_yaml" "$DEST/packet.yaml"
rm -f "$tmp_yaml"

echo "Amended: $name"
echo "  date:   $date"
echo "  by:     $by_name"
echo "  reason: $reason"
echo "  sha:    $sha"
echo ""
echo "Edit decision.md / refinement.md as needed, then:"
echo "  git add math/$name/"
echo "  git commit -m 'amend($name): <short>'"
echo "  sh math-coding review $name --approve --by=<reviewer>"
