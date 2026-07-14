#!/bin/sh
# core/check/verify.sh — math-coding v0.854 verifier.
#
# Usage: sh core/check/verify.sh [packet-dir]
#
# Checks every math/<pkt>/ against the five-file packet
# contract, the seven axioms, and the eight theories.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MATH_DIR="$REPO_ROOT/math"
AXIOMS_DOC="$REPO_ROOT/docs/axioms.md"
THEORIES_DIR="$REPO_ROOT/theories"

errors=0
checks=0

pass() { checks=$((checks + 1)); }
fail() { echo "  FAIL: $1" >&2; errors=$((errors + 1)); checks=$((checks + 1)); }

# Five-file contract per packet
if [ -d "$MATH_DIR" ]; then
    for pkt_dir in "$MATH_DIR"/*/; do
        [ -d "$pkt_dir" ] || continue
        pkt_name=$(basename "$pkt_dir")

        for f in packet.yaml decision.md task.md assumptions.yaml refinement.md; do
            if [ -f "$pkt_dir/$f" ]; then
                pass
            else
                fail "$pkt_name: missing $f"
            fi
        done

        # packet.yaml: lifecycle in valid enum
        if [ -f "$pkt_dir/packet.yaml" ]; then
            lc=$(grep '^lifecycle:' "$pkt_dir/packet.yaml" | sed 's/^lifecycle: *//' | tr -d '"' | tr -d "'")
            case "$lc" in
                sketch|working|verified|deprecated|archived|superseded) pass ;;
                "") pass ;;
                *) fail "$pkt_name: invalid lifecycle '$lc'" ;;
            esac

            # packet.yaml: substrate in valid enum
            sub=$(grep '^substrate:' "$pkt_dir/packet.yaml" | sed 's/^substrate: *//' | tr -d '"' | tr -d "'")
            case "$sub" in
                none|shell|tla|coq|alloy|pbt|bpmn|pbt-prism|"") pass ;;
                *) fail "$pkt_name: invalid substrate '$sub'" ;;
            esac

            # packet.yaml: rigor in valid enum
            rig=$(grep '^rigor:' "$pkt_dir/packet.yaml" | sed 's/^rigor: *//' | tr -d '"' | tr -d "'")
            case "$rig" in
                light|property|temporal|proof) pass ;;
                *) fail "$pkt_name: invalid rigor '$rig'" ;;
            esac

            # applications[] when lifecycle=verified must be non-empty
            if [ "$lc" = "verified" ]; then
                if grep -q '^applications:' "$pkt_dir/packet.yaml"; then
                    if grep -qE 'sha: [0-9a-f]+' "$pkt_dir/packet.yaml"; then
                        pass
                    else
                        fail "$pkt_name: lifecycle=verified but no SHA in applications[]"
                    fi
                else
                    fail "$pkt_name: lifecycle=verified but no applications[] block"
                fi
            fi
        fi

        # assumptions.yaml: epistemic markers
        if [ -f "$pkt_dir/assumptions.yaml" ]; then
            awk -v pkt="$pkt_name" '
                /epistemology:/ {
                    line = $0
                    sub(/^[[:space:]]*epistemology:[[:space:]]*/, "", line)
                    if (line != "fact" && line != "hypothesis" && line != "judgment" &&
                        line != "unknown" && line != "proven") {
                        print pkt ": invalid epistemology '"'"'" line "'"'"'"
                        found = 1
                    }
                }
                END { exit found }
            ' "$pkt_dir/assumptions.yaml" && pass || fail "$pkt_name: invalid epistemology marker"
        fi
    done
fi

# Seven axioms in docs/axioms.md
if [ -f "$AXIOMS_DOC" ]; then
    axiom_count=$(grep -cE '^## A[0-9]\. ' "$AXIOMS_DOC" || true)
    if [ "$axiom_count" = "7" ]; then
        pass
    else
        fail "docs/axioms.md: expected 7 axioms, found $axiom_count"
    fi
else
    fail "docs/axioms.md: missing"
fi

# Eight theories in theories/
if [ -d "$THEORIES_DIR" ]; then
    theory_count=$(find "$THEORIES_DIR" -maxdepth 1 -name '*.md' ! -name 'README.md' | wc -l)
    if [ "$theory_count" = "8" ]; then
        pass
    else
        fail "theories/: expected 8 theories, found $theory_count"
    fi
else
    fail "theories/: missing"
fi

echo ""
echo "verify: $checks checks, $errors errors"
exit "$errors"