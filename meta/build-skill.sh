#!/bin/sh
# meta/build-skill.sh — math-coding v0.992 SKILL.md generator.
#
# Usage:
#   sh meta/build-skill.sh <agent>          # write SKILL.md
#   sh meta/build-skill.sh <agent> --check  # exit 1 if SKILL.md stale
#
# Reads sources from core/spec/, core/theories/, KNOWN_LIMITATIONS.md,
# then assembles SKILL.md from a hand-authored template at
# extensions/agents/<agent>/SKILL.template.md.
#
# Sources (single source of truth):
#   core/spec/axioms.md
#   core/spec/fsm.md
#   core/theories/*.md (8 files)
#   KNOWN_LIMITATIONS.md
#
# Output:
#   extensions/agents/<agent>/SKILL.md
#
# The hand-authored preamble and postamble in SKILL.template.md
# stay intact; only the BEGIN/END GENERATED block is replaced.
#
# axiom A2 (Curry-Howard): SKILL.md is the projection of the
# spec into agent-readable form. axiom A5 (Accounting): every
# generated block carries its source SHA as a witness.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

usage() {
    cat <<'EOF' >&2
usage: meta/build-skill.sh <agent> [--check]

<agent>: opencode (default: opencode)
--check: only verify SKILL.md is up-to-date; exit 1 if stale
EOF
    exit 2
}

[ $# -ge 1 ] || usage
agent="$1"
shift || true

mode="write"
for arg in "$@"; do
    case "$arg" in
        --check) mode="check" ;;
        *) echo "unknown flag: $arg" >&2; usage ;;
    esac
done

# Sources.
AXIOMS="$REPO_ROOT/core/spec/axioms.md"
FSM="$REPO_ROOT/core/spec/fsm.md"
THEORIES_DIR="$REPO_ROOT/core/theories"
LIMITATIONS="$REPO_ROOT/KNOWN_LIMITATIONS.md"

TEMPLATE="$REPO_ROOT/extensions/agents/$agent/SKILL.template.md"
OUTPUT="$REPO_ROOT/extensions/agents/$agent/SKILL.md"

[ -f "$TEMPLATE" ] || { echo "error: $TEMPLATE not found" >&2; exit 2; }
[ -f "$OUTPUT" ]   || { echo "note: $OUTPUT not yet generated (first run)" >&2; }

# Compute SHAs for witnesses.
axioms_sha=$(git -C "$REPO_ROOT" ls-files -s "$AXIOMS" 2>/dev/null | awk '{print $2}' | cut -c1-7)
[ -z "$axioms_sha" ] && axioms_sha=$(git -C "$REPO_ROOT" hash-object "$AXIOMS" 2>/dev/null | cut -c1-7)
fsm_sha=$(git -C "$REPO_ROOT" ls-files -s "$FSM" 2>/dev/null | awk '{print $2}' | cut -c1-7)
[ -z "$fsm_sha" ] && fsm_sha=$(git -C "$REPO_ROOT" hash-object "$FSM" 2>/dev/null | cut -c1-7)
limit_sha=$(git -C "$REPO_ROOT" ls-files -s "$LIMITATIONS" 2>/dev/null | awk '{print $2}' | cut -c1-7)
[ -z "$limit_sha" ] && limit_sha=$(git -C "$REPO_ROOT" hash-object "$LIMITATIONS" 2>/dev/null | cut -c1-7)

# Collect theory SHAs.
theories_list=$(ls "$THEORIES_DIR"/*.md 2>/dev/null | grep -v README | sort)
theories_sha_list=""
for t in $theories_list; do
    name=$(basename "$t" .md)
    sha=$(git -C "$REPO_ROOT" ls-files -s "$t" 2>/dev/null | awk '{print $2}' | cut -c1-7)
    [ -z "$sha" ] && sha=$(git -C "$REPO_ROOT" hash-object "$t" 2>/dev/null | cut -c1-7)
    theories_sha_list="$theories_sha_list $name:$sha"
done

# Extract axiom cards: heading + first sentence (Statement).
emit_axiom_cards() {
    awk '
    BEGIN { in_axiom=0; collecting=0 }
    # New axiom heading: reset, remember heading (defer processing until we know if a Statement follows).
    /^## A[0-9]+\./ {
        # Flush any pending axiom without a discovered period.
        if (in_axiom && stmt != "") {
            print "  " heading
            print "  > " stmt
        }
        heading=$0
        in_axiom=1
        stmt=""
        next
    }
    # End of file / horizontal rule: flush pending.
    /^---$/ || /^$/ && collecting {
        if (in_axiom && stmt != "") {
            idx=index(stmt, ".")
            first = (idx > 0) ? substr(stmt, 1, idx - 1) : stmt
            print "  " heading
            print "  > " first
        }
        collecting=0
        in_axiom=0
        stmt=""
    }
    in_axiom && /^\*\*Statement\*\*/ {
        line=$0
        sub(/^\*\*Statement\*\*:[[:space:]]*/, "", line)
        stmt=line
        idx=index(stmt, ".")
        if (idx > 0) {
            print "  " heading
            print "  > " substr(stmt, 1, idx - 1)
            in_axiom=0
            stmt=""
        } else {
            collecting=1
        }
        next
    }
    collecting {
        # Accumulate lines until we hit a period, end marker, or next axiom.
        idx=index($0, ".")
        if (idx > 0) {
            stmt = stmt " " substr($0, 1, idx - 1)
            # Trim leading space.
            sub(/^ /, "", stmt)
            print "  " heading
            print "  > " stmt
            collecting=0
            in_axiom=0
            stmt=""
        } else {
            stmt = stmt " " $0
            sub(/^ /, "", stmt)
        }
    }
    END {
        # Flush any trailing axiom without period.
        if (in_axiom && stmt != "") {
            idx=index(stmt, ".")
            first = (idx > 0) ? substr(stmt, 1, idx - 1) : stmt
            print "  " heading
            print "  > " first
        }
    }
    ' "$AXIOMS"
}

# Extract FSM transitions as a single line of text.
emit_fsm_card() {
    sed -n '/^S = .*draft/,/^I(s) = invariant/p' "$FSM" | head -n 8
}

# Theory list: one line per theory.
emit_theory_list() {
    for t in $theories_list; do
        name=$(basename "$t" .md)
        # First heading from theory file.
        head -n 1 "$t" | sed 's/^# //'
        echo "  - $name.md"
    done
}

# Limitations digest: each numbered section header is one item.
emit_limitations() {
    sed -n 's/^## \([0-9][0-9]*\.\)/\1/p' "$LIMITATIONS" | head -n 13
}

# Compose generated block.
gen_block() {
    cat <<HEADER
<!-- BEGIN GENERATED by meta/build-skill.sh — DO NOT EDIT BY HAND -->
<!-- Sources: core/spec/axioms.md@$axioms_sha, core/spec/fsm.md@$fsm_sha, core/theories/*.md, KNOWN_LIMITATIONS.md@$limit_sha -->

HEADER
    cat <<'SUBSECTION'
### Axioms (compact)

SUBSECTION
    emit_axiom_cards
    cat <<'SUBSECTION'

### FSM (compact)

SUBSECTION
    emit_fsm_card
    cat <<'SUBSECTION'

### Theories (compact)

SUBSECTION
    emit_theory_list
    cat <<'SUBSECTION'

### Limitations (digest)

SUBSECTION
    emit_limitations
    cat <<EOF

<!-- END GENERATED — source SHAs above are witnesses (axiom A5) -->
EOF
}

# Build SKILL.md: split template on BEGIN/END markers, replace generated block.
# (Done inline below using sed + gen_block — no shell pipeline needed.)

if [ "$mode" = "check" ]; then
    # Build expected output and compare to current SKILL.md.
    expected=$(mktemp)
    {
        sed '/<!-- BEGIN GENERATED/,$d' "$TEMPLATE"
        gen_block
        sed '1,/<!-- END GENERATED/d' "$TEMPLATE"
    } > "$expected"
    if cmp -s "$expected" "$OUTPUT" 2>/dev/null; then
        rm -f "$expected"
        echo "ok: $OUTPUT up-to-date"
        exit 0
    fi
    rm -f "$expected"
    echo "stale: $OUTPUT differs from template + sources" >&2
    echo "  run: sh meta/build-skill.sh $agent" >&2
    exit 1
fi

# Write mode: emit SKILL.md with template preamble + generated block + postamble.
{
    # Lines up to <!-- BEGIN GENERATED --> (exclusive).
    sed '/<!-- BEGIN GENERATED/,$d' "$TEMPLATE"
    gen_block
    # Lines after <!-- END GENERATED --> (exclusive).
    sed '1,/<!-- END GENERATED/d' "$TEMPLATE"
} > "$OUTPUT.new"

mv "$OUTPUT.new" "$OUTPUT"
echo "wrote: $OUTPUT"
