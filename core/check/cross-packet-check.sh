#!/bin/sh
# core/check/cross-packet-check.sh — math-coding v0.992 cross-packet consistency.
#
# Usage:
#   sh math-coding verify --cross-packet-consistency
#
# Checks cross-packet invariants beyond per-packet structural checks:
#   1. depends_on targets exist (or warn if retired).
#   2. supersession source exists and is retired.
#   3. depends_on graph is acyclic.
#   4. amendment propagation: if upstream was amended after
#      downstream's last amendment, warn downstream may be unaware.

set -u

. "$(dirname "$0")/../lib/common.sh"

errors=0
warnings=0
checks=0

pass() { checks=$((checks + 1)); }
fail() { echo "  FAIL: $1" >&2; errors=$((errors + 1)); checks=$((checks + 1)); }
warn() { echo "  WARN: $1" >&2; warnings=$((warnings + 1)); checks=$((checks + 1)); }

[ -d "$MATH_DIR" ] || { echo "  note: $MATH_DIR does not exist" >&2; exit 0; }

# Build name list.
packet_names=""
for pkt_dir in "$MATH_DIR"/*/; do
    [ -d "$pkt_dir" ] || continue
    pkt_name=$(basename "$pkt_dir")
    [ "$pkt_name" = "archived" ] && continue
    packet_names="$packet_names $pkt_name"
done

# Helper: read depends_on for a packet (prints each dep on its own line).
get_deps() {
    awk '
        /^depends_on:/ { in_block = 1; next }
        in_block && /^[^ ]/ { in_block = 0 }
        in_block && /^  - / { sub(/^  - /, ""); print }
    ' "$1"
}

# Helper: read latest amendment date for a packet (empty if none).
latest_amend_date() {
    awk '
        /^amendments:/ { in_block = 1; next }
        in_block && /^[^ ]/ { in_block = 0 }
        in_block && /date:/ {
            line = $0; sub(/^[[:space:]]*date:[[:space:]]*/, "", line)
            gsub(/["'"'"']/, "", line)
            if (line > max) max = line
        }
        END { if (max != "") print max }
    ' "$1"
}

# Helper: get lifecycle.
get_lc() {
    get_lifecycle "$1"
}

# Build alias map: axiom label (e.g. A4) → packet name (e.g. 04-process).
# depends_on entries may use either packet task_id or "axiom-<label>" form.
axiom_alias=""
for pkt_dir in "$MATH_DIR"/*/; do
    [ -d "$pkt_dir" ] || continue
    pkt_name=$(basename "$pkt_dir")
    [ "$pkt_name" = "archived" ] && continue
    [ -f "$pkt_dir/packet.yaml" ] || continue
    ax=$(grep '^axiom:' "$pkt_dir/packet.yaml" | sed 's/^axiom:[[:space:]]*//' | tr -d '"' | tr -d "'" | awk '{print $1}')
    if [ -n "$ax" ]; then
        # strip leading "A" → e.g. A4 → axiom-process map
        ax_num=$(printf '%s' "$ax" | sed 's/^A//')
        # name from packet (e.g. 04-process → process)
        short=$(printf '%s' "$pkt_name" | sed 's/^[0-9]*-//')
        axiom_alias="$axiom_alias axiom-$short:$pkt_name"
    fi
done

# Resolve a depends_on target to a real packet name (or empty).
resolve_target() {
    target="$1"
    case " $packet_names " in
        *" $target "*) printf '%s' "$target"; return ;;
    esac
    case " $axiom_alias " in
        *" $target:"*)
            printf '%s' "$axiom_alias" | tr ' ' '\n' | grep "^$target:" | head -1 | cut -d: -f2
            return ;;
    esac
    printf ''
}

# Check 1+2+3: per-packet structural cross-refs.
for pkt_dir in "$MATH_DIR"/*/; do
    [ -d "$pkt_dir" ] || continue
    pkt_name=$(basename "$pkt_dir")
    [ "$pkt_name" = "archived" ] && continue
    [ -f "$pkt_dir/packet.yaml" ] || continue

    pkt_yaml="$pkt_dir/packet.yaml"

    # depends_on targets exist
    deps=$(get_deps "$pkt_yaml")
    for dep in $deps; do
        resolved=$(resolve_target "$dep")
        if [ -n "$resolved" ] && [ "$resolved" != "$dep" ]; then
            pass  # alias resolved
        elif [ -n "$resolved" ]; then
            dep_lc=$(get_lc "$MATH_DIR/$resolved/packet.yaml")
            if [ "$dep_lc" = "retired" ] || [ "$dep_lc" = "abandoned" ]; then
                warn "$pkt_name: depends_on $dep (lifecycle=$dep_lc)"
            else
                pass
            fi
        else
            fail "$pkt_name: depends_on $dep (does not exist)"
        fi
    done

    # supersession source exists and is retired
    sup=$(grep '^supersession:' "$pkt_yaml" | sed 's/^supersession:[[:space:]]*//' | tr -d '"' | tr -d "'" | awk '{print $1}')
    if [ -n "$sup" ]; then
        case " $packet_names " in
            *" $sup "*)
                sup_lc=$(get_lc "$MATH_DIR/$sup/packet.yaml")
                if [ "$sup_lc" != "retired" ]; then
                    fail "$pkt_name: supersession source $sup is not retired (lifecycle=$sup_lc)"
                else
                    pass
                fi
                ;;
            *)
                fail "$pkt_name: supersession source $sup (does not exist)"
                ;;
        esac
    fi
done

# Check 3: acyclicity in depends_on graph (Tarjan-lite via repeated DFS).
# Build adjacency as flat lines: "<from>|<to>".
adj_file=$(mktemp) || { echo "error: mktemp failed" >&2; exit 1; }
for pkt_dir in "$MATH_DIR"/*/; do
    [ -d "$pkt_dir" ] || continue
    pkt_name=$(basename "$pkt_dir")
    [ "$pkt_name" = "archived" ] && continue
    [ -f "$pkt_dir/packet.yaml" ] || continue
    deps=$(get_deps "$pkt_dir/packet.yaml")
    for dep in $deps; do
        printf '%s|%s\n' "$pkt_name" "$dep" >> "$adj_file"
    done
done

# DFS cycle detection: per-node color (0=white, 1=gray, 2=black) in tmp files.
state_dir=$(mktemp -d) || { echo "error: mktemp -d failed" >&2; rm -f "$adj_file"; exit 1; }

# Initialize all to white.
for n in $packet_names; do
    printf '0' > "$state_dir/$n"
done

has_cycle=0
visit() {
    node="$1"
    color=$(cat "$state_dir/$node" 2>/dev/null || echo 0)
    if [ "$color" = "1" ]; then
        has_cycle=1
        return
    fi
    if [ "$color" = "2" ]; then
        return
    fi
    echo 1 > "$state_dir/$node"
    # neighbors
    grep "^${node}|" "$adj_file" 2>/dev/null | cut -d'|' -f2 | while read -r nbr; do
        [ -z "$nbr" ] && continue
        visit "$nbr"
    done
    echo 2 > "$state_dir/$node"
}

for n in $packet_names; do
    color=$(cat "$state_dir/$n" 2>/dev/null || echo 0)
    if [ "$color" = "0" ]; then
        visit "$n"
    fi
done

# Note: shell subshells break the cycle detection (visit runs in subshell).
# Simpler approach: explicit iterative cycle detection using Floyd-like path tracking.
# Re-run with explicit stack.

has_cycle=0
state_dir2=$(mktemp -d) || { rm -rf "$state_dir" "$adj_file"; exit 1; }
for n in $packet_names; do
    printf '0' > "$state_dir2/$n"
done

for start in $packet_names; do
    # iterative DFS using stack file
    stack="$start"
    on_path=""
    # Mark start as gray
    echo 1 > "$state_dir2/$start"
    on_path="$start"
    while [ -n "$stack" ]; do
        top=$(printf '%s' "$stack" | awk '{print $NF}')
        rest=$(printf '%s' "$stack" | awk '{$NF=""; print}' | sed 's/[[:space:]]*$//')
        nbrs=$(grep "^${top}|" "$adj_file" 2>/dev/null | cut -d'|' -f2)
        pushed=0
        for nbr in $nbrs; do
            [ -z "$nbr" ] && continue
            color=$(cat "$state_dir2/$nbr" 2>/dev/null || echo 0)
            if [ "$color" = "1" ]; then
                has_cycle=1
                fail "depends_on cycle: $top → $nbr"
                break 2
            fi
            if [ "$color" = "0" ]; then
                echo 1 > "$state_dir2/$nbr"
                rest="$rest $top"
                stack="$rest $nbr"
                pushed=1
                break
            fi
        done
        if [ "$pushed" = "0" ]; then
            echo 2 > "$state_dir2/$top"
            stack="$rest"
        fi
    done
done

if [ "$has_cycle" = "0" ]; then
    pass
fi

rm -rf "$state_dir" "$state_dir2" "$adj_file"

# Check 4: amendment propagation.
# For each upstream packet with amendments, find downstream (dependents)
# and warn if downstream's latest amendment/created predates upstream's.
for pkt_dir in "$MATH_DIR"/*/; do
    [ -d "$pkt_dir" ] || continue
    pkt_name=$(basename "$pkt_dir")
    [ "$pkt_name" = "archived" ] && continue
    [ -f "$pkt_dir/packet.yaml" ] || continue

    upstream_amend=$(latest_amend_date "$pkt_dir/packet.yaml")
    [ -n "$upstream_amend" ] || continue

    # Find dependents (packets that have this in depends_on).
    for downstream_dir in "$MATH_DIR"/*/; do
        [ -d "$downstream_dir" ] || continue
        downstream_name=$(basename "$downstream_dir")
        [ "$downstream_name" = "archived" ] && continue
        [ "$downstream_name" = "$pkt_name" ] && continue
        [ -f "$downstream_dir/packet.yaml" ] || continue

        deps=$(get_deps "$downstream_dir/packet.yaml")
        case " $deps " in
            *" $pkt_name "*) ;;
            *) continue ;;
        esac

        downstream_amend=$(latest_amend_date "$downstream_dir/packet.yaml")
        if [ -z "$downstream_amend" ]; then
            downstream_amend=$(grep '^created:' "$downstream_dir/packet.yaml" \
                | sed 's/^created:[[:space:]]*["'"'"']//' | sed 's/["'"'"']$//')
        fi

        if [ -n "$downstream_amend" ] && [ "$downstream_amend" \< "$upstream_amend" ]; then
            warn "$downstream_name: depends_on $pkt_name (amended $upstream_amend, last touched $downstream_amend)"
        fi
    done
done

echo ""
echo "cross-packet: $checks checks, $errors errors, $warnings warnings"
exit "$errors"
