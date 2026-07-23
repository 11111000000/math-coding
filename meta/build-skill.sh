#!/bin/sh
# meta/build-skill.sh — math-coding v0.992 multi-agent SKILL.md generator.
#
# Usage:
#   sh meta/build-skill.sh                     # build all registered agents
#   sh meta/build-skill.sh <agent>             # build one agent
#   sh meta/build-skill.sh <agent> --check     # verify SKILL.md is current
#   sh meta/build-skill.sh --list              # list registered agents
#
# v0.992 architecture (multi-agent):
#   extensions/agents/canon/SKILL.body.template.md  — shared body (axiom cards
#                                                       generated block +
#                                                       postamble: Packet,
#                                                       FSM, Commands, etc.)
#   extensions/agents/canon/math-agent.body.md      — shared agent body
#                                                       (role, workflow,
#                                                       anti-patterns)
#   extensions/agents/<agent>/SKILL.preamble.md    — agent-specific YAML
#                                                     frontmatter + intro
#   extensions/agents/<agent>/math-agent.preamble.yaml
#                                                  — agent-specific agent
#                                                     frontmatter
#
# Generated artifacts (committed for reproducibility, axiom A3 plain text):
#   extensions/agents/<agent>/SKILL.md
#   extensions/agents/<agent>/math-agent.md
#
# Sources of truth (axiom A3, A5):
#   core/spec/axioms.md, core/spec/fsm.md, core/theories/*.md,
#   KNOWN_LIMITATIONS.md
#
# axiom A2 (Curry-Howard): SKILL.md is the projection of the spec into
# agent-readable form. axiom A5 (Accounting): every generated block carries
# its source SHA as a witness.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

# Registered agents. Add new agents here.
# MUST be kept in sync with core/install/install-skill.sh AGENT_TARGETS.
AGENTS="opencode claude cursor"

usage() {
    cat <<'EOF' >&2
usage: meta/build-skill.sh [<agent>] [--check|--list]

Default:        build all registered agents.
<agent>:        build one agent (e.g. opencode).
--check:        verify SKILL.md is up-to-date; exit 1 if stale.
--list:         list registered agents.

Examples:
    sh meta/build-skill.sh
    sh meta/build-skill.sh opencode --check
    sh meta/build-skill.sh --list
EOF
    exit 2
}

# Parse args.
mode="write"
target=""
if [ $# -gt 0 ]; then
    case "$1" in
        --list) echo "$AGENTS"; exit 0 ;;
        --check) mode="check" ;;
        -h|--help) usage ;;
        *)
            if echo " $AGENTS " | grep -q " $1 "; then
                target="$1"
            else
                echo "error: unknown agent '$1'" >&2
                echo "  registered: $AGENTS" >&2
                exit 2
            fi
            ;;
    esac
    shift || true
    if [ $# -gt 0 ]; then
        case "$1" in
            --check) mode="check" ;;
            *) usage ;;
        esac
    fi
fi

# Helper: ensure file ends with a single newline.
# Reads last byte via tail, checks hex value via od.
ensure_trailing_newline() {
    file="$1"
    [ -s "$file" ] || return 0
    lastbyte=$(tail -c 1 "$file" | od -An -tx1 | tr -d ' ')
    [ "$lastbyte" = "0a" ] || printf '\n' >> "$file"
}

CANON_BODY="$REPO_ROOT/extensions/agents/canon/SKILL.body.template.md"
CANON_AGENT_BODY="$REPO_ROOT/extensions/agents/canon/math-agent.body.md"

# Sources.
AXIOMS="$REPO_ROOT/core/spec/axioms.md"
FSM="$REPO_ROOT/core/spec/fsm.md"
THEORIES_DIR="$REPO_ROOT/core/theories"
LIMITATIONS="$REPO_ROOT/KNOWN_LIMITATIONS.md"

[ -f "$CANON_BODY" ] || { echo "error: $CANON_BODY not found" >&2; exit 2; }
[ -f "$CANON_AGENT_BODY" ] || { echo "error: $CANON_AGENT_BODY not found" >&2; exit 2; }

# Sanity check: build AGENTS must be a subset of install AGENT_TARGETS.
# Detects drift between the two registries.
INSTALL_TARGETS="$(awk -F: '/^[a-z]+:~\// {print $1}' "$REPO_ROOT/core/install/install-skill.sh" | sort -u | tr '\n' ' ')"
for a in $AGENTS; do
    if ! echo " $INSTALL_TARGETS " | grep -q " $a "; then
        echo "warning: agent '$a' registered in build-skill.sh but missing in install-skill.sh AGENT_TARGETS" >&2
    fi
done

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
    /^## A[0-9]+\./ {
        if (in_axiom && stmt != "") {
            print "  " heading
            print "  > " stmt
        }
        heading=$0
        in_axiom=1
        stmt=""
        next
    }
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
        idx=index($0, ".")
        if (idx > 0) {
            stmt = stmt " " substr($0, 1, idx - 1)
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
        if (in_axiom && stmt != "") {
            idx=index(stmt, ".")
            first = (idx > 0) ? substr(stmt, 1, idx - 1) : stmt
            print "  " heading
            print "  > " first
        }
    }
    ' "$AXIOMS"
}

# FSM transitions.
emit_fsm_card() {
    sed -n '/^S = .*draft/,/^I(s) = invariant/p' "$FSM" | head -n 8
}

# Theory list.
emit_theory_list() {
    for t in $theories_list; do
        name=$(basename "$t" .md)
        head -n 1 "$t" | sed 's/^# //'
        echo "  - $name.md"
    done
}

# Limitations digest.
emit_limitations() {
    sed -n 's/^## \([0-9][0-9]*\.\)/\1/p' "$LIMITATIONS" | head -n 13
}

# Compose generated block. Writes to a temp file (avoids shell-quoting in awk).
gen_block_to_file() {
    out="$1"
    {
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
        cat <<'SUBSECTION'

<!-- END GENERATED — source SHAs above are witnesses (axiom A5) -->
SUBSECTION
    } > "$out"
}

# Process body template: replace BEGIN/END GENERATED region with gen_block output.
process_body() {
    block_file=$(mktemp) || return 1
    gen_block_to_file "$block_file"
    awk -v block_file="$block_file" '
        /<!-- BEGIN GENERATED -->/ {
            while ((getline line < block_file) > 0) print line
            close(block_file)
            in_block=1
            next
        }
        /<!-- END GENERATED -->/ {
            in_block=0
            next
        }
        !in_block { print }
    ' "$CANON_BODY"
    rm -f "$block_file"
}

# Generate SKILL.md for an agent.
build_skill_for() {
    agent="$1"

    PREAMBLE="$REPO_ROOT/extensions/agents/$agent/SKILL.preamble.md"
    OUTPUT="$REPO_ROOT/extensions/agents/$agent/SKILL.md"

    if [ ! -f "$PREAMBLE" ]; then
        echo "skip: $PREAMBLE not found (agent '$agent' has no preamble)" >&2
        return 1
    fi

    if [ "$mode" = "check" ]; then
        expected=$(mktemp) || return 1
        {
            cat "$PREAMBLE"
            process_body
        } > "$expected"
        if cmp -s "$expected" "$OUTPUT" 2>/dev/null; then
            rm -f "$expected"
            echo "ok: $OUTPUT up-to-date"
            return 0
        fi
        rm -f "$expected"
        echo "stale: $OUTPUT differs from preamble + canon body" >&2
        echo "  run: sh meta/build-skill.sh $agent" >&2
        return 1
    fi

    {
        cat "$PREAMBLE"
        process_body
    } > "$OUTPUT.new"
    ensure_trailing_newline "$OUTPUT.new"
    mv "$OUTPUT.new" "$OUTPUT"
    echo "wrote: $OUTPUT"
}

# Generate math-agent.md for an agent.
build_agent_for() {
    agent="$1"

    AGENT_PREAMBLE="$REPO_ROOT/extensions/agents/$agent/math-agent.preamble.yaml"
    AGENT_OUTPUT="$REPO_ROOT/extensions/agents/$agent/math-agent.md"

    if [ ! -f "$AGENT_PREAMBLE" ]; then
        # Optional: not all agents have a math-agent.md
        return 0
    fi
    if [ ! -f "$CANON_AGENT_BODY" ]; then
        echo "warning: $CANON_AGENT_BODY not found, skipping math-agent" >&2
        return 1
    fi

    if [ "$mode" = "check" ]; then
        expected=$(mktemp) || return 1
        {
            cat "$AGENT_PREAMBLE"
            cat "$CANON_AGENT_BODY"
        } > "$expected"
        if cmp -s "$expected" "$AGENT_OUTPUT" 2>/dev/null; then
            rm -f "$expected"
            echo "ok: $AGENT_OUTPUT up-to-date"
            return 0
        fi
        rm -f "$expected"
        echo "stale: $AGENT_OUTPUT differs from preamble + canon body" >&2
        echo "  run: sh meta/build-skill.sh $agent" >&2
        return 1
    fi

    {
        cat "$AGENT_PREAMBLE"
        cat "$CANON_AGENT_BODY"
    } > "$AGENT_OUTPUT.new"
    ensure_trailing_newline "$AGENT_OUTPUT.new"
    mv "$AGENT_OUTPUT.new" "$AGENT_OUTPUT"
    echo "wrote: $AGENT_OUTPUT"
}

# Main: iterate over agents.
if [ -n "$target" ]; then
    build_skill_for "$target" || true
    build_agent_for "$target" || true
    if [ "$mode" = "check" ]; then
        exit_status=0
    fi
    exit "${exit_status:-0}"
else
    # Build all agents.
    rc=0
    for a in $AGENTS; do
        build_skill_for "$a" || rc=1
        build_agent_for "$a" || rc=1
    done
    if [ "$mode" = "check" ]; then
        exit $rc
    fi
    exit 0
fi
