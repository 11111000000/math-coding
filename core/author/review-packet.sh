#!/bin/sh
# core/author/review-packet.sh — math-coding v0.992 peer-review.
#
# Usage:
#   sh math-coding review <name> --approve|--request-changes|--comment
#                              [--note="<text>"]
#                              [--by=<name>]
#
# Records a review entry (approve / request-changes / comment)
# in packet.yaml:reviews[]. v0.992: applied packets require at
# least one approve review (verified by verify.sh).
#
# The command echoes the review criteria for the reviewer to
# apply before submitting the verdict.

set -u

. "$(dirname "$0")/../lib/common.sh"

usage() {
    cat <<'EOF' >&2
usage: review-packet.sh <name>
           --approve | --request-changes | --comment
           [--note="<text>"]
           [--by=<name>]

Records a peer-review entry. v0.992 requires at least one
approve review before a packet can be applied.

Options:
    --approve            approve verdict
    --request-changes    request-changes verdict (block apply)
    --comment            non-blocking comment
    --note="<text>"      reason or comment text
    --by=<name>          reviewer identity (default: $USER)
    --help -h            this message
EOF
    exit 2
}

name=""
verdict=""
note=""
by_name="${USER:-agent}"

while [ $# -gt 0 ]; do
    case "$1" in
        --approve) verdict="approve"; shift ;;
        --request-changes) verdict="request-changes"; shift ;;
        --comment) verdict="comment"; shift ;;
        --note=*) note="${1#--note=}"; shift ;;
        --by=*) by_name="${1#--by=}"; shift ;;
        --help|-h) usage ;;
        -*) echo "unknown flag: $1" >&2; usage ;;
        *) name="$1"; shift ;;
    esac
done

[ -z "$name" ] && usage
[ -z "$verdict" ] && { echo "error: --approve, --request-changes, or --comment required" >&2; usage; }

DEST="$MATH_DIR/$name"
[ -d "$DEST" ] || { echo "error: $DEST not found" >&2; exit 2; }
[ -f "$DEST/packet.yaml" ] || { echo "error: $DEST/packet.yaml not found" >&2; exit 2; }

# Echo review criteria (informational, not blocking)
proposition=$(awk '/^## Thesis/,/^## /{ if (!/^## Thesis/ && !/^## /) print }' "$DEST/decision.md" 2>/dev/null | head -3)
operation=$(awk '/^## Operation/,/^## /{ if (!/^## Operation/ && !/^## /) print }' "$DEST/refinement.md" 2>/dev/null | head -3)
antithesis=$(awk '/^## Antithesis/,/^## /{ if (!/^## Antithesis/ && !/^## /) print }' "$DEST/decision.md" 2>/dev/null | head -3)

echo "Reviewing: $name"
echo ""
echo "Apply review criteria (see SKILL.md 'Field checklists'):"
echo "  Proposition: [ ] falsifiable  [ ] specific  [ ] one sentence"
echo "  Antithesis:  [ ] strongest  [ ] domain-specific  [ ] not strawman"
echo "  Synthesis:    [ ] acknowledges both thesis and antithesis  [ ] explains HOW"
echo "  Operation:    [ ] describes behavior  [ ] not implementation detail"
echo "  Test:         [ ] executable  [ ] asserts expected value"
echo "  Epistemic:    [ ] all assumptions have appropriate markers"
echo "                [ ] 'fact' markers have evidence"
echo ""
echo "  Proposition: $proposition"
echo "  Antithesis:  $antithesis"
echo "  Operation:    $operation"
echo ""
echo "Review verdict: $verdict"
echo "Reviewer:       $by_name"
[ -n "$note" ] && echo "Note:           $note"

date=$(date -u +%Y-%m-%d)

# v0.992+: enforce self_approve_allowed
# Read packet creator and compare with --by
if [ "$verdict" = "approve" ]; then
    packet_creator=$(grep '^creator:' "$DEST/packet.yaml" | sed 's/^creator:[[:space:]]*//')
    if [ -n "$packet_creator" ] && [ "$by_name" = "$packet_creator" ] && [ "$packet_creator" != "agent" ]; then
        if [ "$SELF_APPROVE_ALLOWED" != "yes" ]; then
            echo "error: self_approve_allowed=no, but --by=$by_name matches packet creator" >&2
            echo "       a different reviewer must approve this packet" >&2
            exit 1
        fi
    fi
fi

# Append to reviews: block. If reviews: doesn't exist, create it.
tmp_yaml=$(mktemp) || { echo "error: mktemp failed" >&2; exit 1; }

if grep -q '^reviews:' "$DEST/packet.yaml"; then
    # Insert after last `  - by:` line (end of last review entry)
    awk -v by="$by_name" -v date="$date" -v verdict="$verdict" -v note="$note" '
        /^  - by:/ && !inserted {
            print
            print "  - by: " by
            print "    date: \"" date "\""
            print "    verdict: " verdict
            if (note != "") print "    note: |"
            inserted = 1
            next
        }
        inserted && /^    note: \|/ {
            print
            if (note != "") print "      " note
            note_inserted = 1
            next
        }
        inserted && !note_inserted && /^[a-z]/ {
            if (note != "") print "    note: |"
            print
            next
        }
        { print }
    ' "$DEST/packet.yaml" > "$tmp_yaml"
else
    # Create reviews: block at end
    echo "" >> "$DEST/packet.yaml"
    cat > "$tmp_yaml" <<EOF
reviews:
  - by: $by_name
    date: "$date"
    verdict: $verdict
EOF
    if [ -n "$note" ]; then
        echo "    note: |" >> "$tmp_yaml"
        echo "      $note" >> "$tmp_yaml"
    fi
    cat "$DEST/packet.yaml" >> "$tmp_yaml"
fi

mv "$tmp_yaml" "$DEST/packet.yaml"
rm -f "$tmp_yaml"

echo ""
echo "Review recorded."
echo ""
if [ "$verdict" = "approve" ]; then
    echo "If this is the first approve and lifecycle=applied, packet is ready."
fi