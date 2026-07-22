#!/bin/sh
# core/check/verify.sh — math-coding v0.991 verifier.
#
# Usage: sh core/check/verify.sh [--cross-packet-consistency]
#
# Checks every packet under $MATH_DIR (top-level only, not archived/)
# against the packet contract, the seven axioms, and the eight theories.
#
# v0.991: 3 mandatory files. Optional files are bonus. Lifecycle:
# draft/applied/retired/abandoned (4 states). Old states are invalid.
# .mathrc unknown fields generate warnings.
# v0.992: --cross-packet-consistency runs cross-packet-check.sh after
# per-packet checks.

set -u

. "$(dirname "$0")/../lib/common.sh"

cross_packet=0
for arg in "$@"; do
    case "$arg" in
        --cross-packet-consistency) cross_packet=1 ;;
    esac
done

AXIOMS_DOC="$REPO_ROOT/docs/axioms.md"
THEORIES_DIR="$REPO_ROOT/theories"

errors=0
warnings=0
checks=0

pass() { checks=$((checks + 1)); }
fail() { echo "  FAIL: $1" >&2; errors=$((errors + 1)); checks=$((checks + 1)); }
warn() { echo "  WARN: $1" >&2; warnings=$((warnings + 1)); checks=$((checks + 1)); }

# Mandatory and optional files per packet.
MANDATORY="packet.yaml decision.md refinement.md"
OPTIONAL="task.md assumptions.yaml"

# Known fields in .mathrc (others generate warnings).
KNOWN_MATHRC_FIELDS="mode role math_dir lookahead_ok committed required_approvals self_approve_allowed placeholder_detection abandoned_threshold_days self_critique_echo lifecycle_abandoned_enabled evidence_strict"

# Placeholder marker regexes per detection level.
# format: "decision|markdown|evidence"
case "$PLACEHOLDER_DETECTION" in
    off)
        PLACEHOLDER_MARKERS='___NONE___'
        EVIDENCE_PLACEHOLDERS='___NONE___'
        ;;
    strict)
        PLACEHOLDER_MARKERS='<placeholder>|<your proposition>|<your thesis>|<your antithesis>|<your synthesis>|<your operation>|<your outcome>|<your invariant>|<your test>|TBD|TODO|FIXME|XXX|none|<none>'
        EVIDENCE_PLACEHOLDERS='^TBD$|^TODO$|^FIXME$|^XXX$|^none$|^<none>$|^--$|^\.\.\.$'
        ;;
    standard|*)
        PLACEHOLDER_MARKERS='<placeholder>|<your proposition>|<your thesis>|TBD|TODO|FIXME'
        EVIDENCE_PLACEHOLDERS='^TBD$|^TODO$|^FIXME$|^<none>$|^none$'
        ;;
esac

# .mathrc schema validation: warn on unknown fields.
if [ -f "$PROJECT_ROOT/.mathrc" ]; then
    while IFS= read -r line; do
        case "$line" in
            ""|\#*) continue ;;
        esac
        key=$(printf '%s' "$line" | awk -F: '{print $1}' | sed 's/[[:space:]]*$//')
        case " $KNOWN_MATHRC_FIELDS " in
            *" $key "*) ;;
            *) warn ".mathrc: unknown field '$key'" ;;
        esac
    done < "$PROJECT_ROOT/.mathrc"
fi

# Per-packet checks.
if [ -d "$MATH_DIR" ]; then
    for pkt_dir in "$MATH_DIR"/*/; do
        [ -d "$pkt_dir" ] || continue
        pkt_name=$(basename "$pkt_dir")
        # Skip archived/ subdirectory
        [ "$pkt_name" = "archived" ] && continue

        # Mandatory files
        for f in $MANDATORY; do
            [ -f "$pkt_dir/$f" ] && pass || fail "$pkt_name: missing mandatory $f"
        done
        # Optional files (bonus, not required)
        for f in $OPTIONAL; do
            [ -f "$pkt_dir/$f" ] && pass
        done

        [ -f "$pkt_dir/packet.yaml" ] || continue
        lc=$(get_lifecycle "$pkt_dir/packet.yaml")

        # Lifecycle enum check
        case "$lc" in
            draft|applied|retired|abandoned) pass ;;
            "") fail "$pkt_name: missing lifecycle" ;;
            *) fail "$pkt_name: invalid lifecycle '$lc'" ;;
        esac

        # substrate enum
        sub=$(grep '^substrate:' "$pkt_dir/packet.yaml" | sed 's/^substrate:[[:space:]]*//' | tr -d '"' | tr -d "'")
        case "$sub" in
            none|shell|tla|coq|alloy|pbt|bpmn|pbt-prism|"") pass ;;
            *) fail "$pkt_name: invalid substrate '$sub'" ;;
        esac

        # rigor enum
        rig=$(grep '^rigor:' "$pkt_dir/packet.yaml" | sed 's/^rigor:[[:space:]]*//' | tr -d '"' | tr -d "'")
        case "$rig" in
            light|property|temporal|proof) pass ;;
            *) fail "$pkt_name: invalid rigor '$rig'" ;;
        esac

        # v0.992: graduated ceremony per lifecycle state.
        # draft    — minimal: mandatory files only. No SHA, no review, no
        #            verified_by required. Idea-stage is cheap.
        # applied  — full: SHA-witness + implementation=complete + ≥1 review
        #            + verified_by. axiom packets exempt (reference material).
        # retired/abandoned — closed; no further checks.
        case "$lc" in
            draft)
                # no extra checks beyond mandatory files
                pass
                ;;
            applied)
                # SHA in applications[]
                if grep -q '^applications:' "$pkt_dir/packet.yaml"; then
                    if grep -qE 'sha: [0-9a-f]+' "$pkt_dir/packet.yaml"; then
                        pass
                    else
                        fail "$pkt_name: lifecycle=applied but no SHA in applications[]"
                    fi
                else
                    fail "$pkt_name: lifecycle=applied but no applications[] block"
                fi

                # implementation=complete (axiom exempt)
                is_axiom=$(grep -q '^axiom:[[:space:]]*[Aa][0-9]' "$pkt_dir/packet.yaml" 2>/dev/null && echo 1 || echo 0)
                impl=$(grep '^implementation:' "$pkt_dir/packet.yaml" | sed 's/^implementation:[[:space:]]*//' | tr -d '"' | tr -d "'" | awk '{print $1}')
                if [ "$is_axiom" = "0" ] && [ "$impl" != "complete" ]; then
                    fail "$pkt_name: lifecycle=applied but implementation=$impl (must be complete, see fix-implementation-field)"
                fi

                # verified_by (axiom exempt) + single_author declaration
                if [ "$is_axiom" = "0" ]; then
                    verified_by_count=$(grep '^verified_by:[[:space:]]*\[' "$pkt_dir/packet.yaml" | grep -c '[[:alnum:]]')
                    if [ "${verified_by_count:-0}" -lt 1 ]; then
                        warn "$pkt_name: lifecycle=applied but no verified_by (see fix-verified-by-field)"
                    fi
                    single_author=$(grep '^single_author:' "$pkt_dir/packet.yaml" | sed 's/^single_author:[[:space:]]*//' | tr -d '"' | tr -d "'" | awk '{print $1}')
                    if [ "${verified_by_count:-0}" -eq 1 ] && [ "$single_author" != "true" ]; then
                        warn "$pkt_name: single-actor review without single_author: true declaration"
                    fi
                fi

                # at least one approve review
                if grep -q '^reviews:' "$pkt_dir/packet.yaml" 2>/dev/null; then
                    approves=$(awk '
                        BEGIN { in_block = 0; count = 0 }
                        /^reviews:/ { in_block = 1; next }
                        in_block && /^[^ ]/ { in_block = 0 }
                        in_block && /verdict:[[:space:]]*approve/ { count++ }
                        END { print count+0 }
                    ' "$pkt_dir/packet.yaml")
                    if [ "${approves:-0}" -lt 1 ] 2>/dev/null; then
                        fail "$pkt_name: lifecycle=applied but no approve review"
                    else
                        pass
                    fi
                else
                    fail "$pkt_name: lifecycle=applied but no reviews[] block"
                fi
                ;;
            retired|abandoned)
                # closed; no enforcement
                pass
                ;;
        esac

        # assumptions.yaml: epistemic markers + evidence content checks.
        [ -f "$pkt_dir/assumptions.yaml" ] || continue

        # Check 1: all epistemology values are valid enum.
        awk -v pkt="$pkt_name" '
            /epistemology:/ {
                line = $0; sub(/^[[:space:]]*epistemology:[[:space:]]*/, "", line)
                if (line != "fact" && line != "hypothesis" && line != "judgment" &&
                    line != "unknown" && line != "proven") {
                    print pkt ": invalid epistemology " line
                    found = 1
                }
            }
            END { exit found }
        ' "$pkt_dir/assumptions.yaml" && pass || fail "$pkt_name: invalid epistemology marker"

        # Check 2: fact markers must have evidence with content.
        # State machine tracks current assumption, whether it's a fact,
        # and whether evidence was seen (and whether block-scalar was
        # non-empty). Prints warnings for fact-without-evidence.
        awk -v pkt="$pkt_name" '
            BEGIN { issue = 0; in_assumption = 0
                    current_id = ""; fact_pending = 0
                    evidence_seen = 0
                    evidence_block = 0; evidence_empty = 0 }
            # New assumption starts: check previous if pending
            /^[ ]*- id:/ {
                if (in_assumption && fact_pending &&
                    (evidence_seen == 0 || evidence_empty == 1)) {
                    print pkt ":" current_id " fact without evidence content"
                    issue = 1
                }
                current_id = $0
                sub(/^[[:space:]]*- id:[[:space:]]*/, "", current_id)
                sub(/[[:space:]]*\|.*$/, "", current_id)
                in_assumption = 1
                fact_pending = 0; evidence_seen = 0
                evidence_block = 0; evidence_empty = 0
                next
            }
            # Mark fact on this assumption
            in_assumption && /epistemology:[[:space:]]+fact$/ {
                fact_pending = 1
                next
            }
            # Other epistemology resets fact_pending
            in_assumption && /epistemology:/ && !/fact$/ {
                fact_pending = 0
                next
            }
            # Block scalar evidence: | (content on next lines)
            in_assumption && /evidence:[[:space:]]*\|/ {
                if (fact_pending) { evidence_seen = 1; evidence_block = 1 }
                next
            }
            # Inline evidence: <value>
            in_assumption && /evidence:/ && !/\|/ {
                if (fact_pending) evidence_seen = 1
                next
            }
            # Inside block scalar: indented non-blank = content
            evidence_block && /^[[:space:]]+[^[:space:]]/ {
                if (fact_pending) evidence_empty = 0
                evidence_block = 0
            }
            # Inside block scalar: blank line = still in block
            evidence_block && /^[[:space:]]*$/ { next }
            # Block ends on unindented line
            evidence_block && /^[^[:space:]]/ {
                evidence_empty = 1
                evidence_block = 0
            }
            END {
                # If block still open at EOF, mark as empty.
                if (evidence_block && fact_pending) evidence_empty = 1
                if (in_assumption && fact_pending &&
                    (evidence_seen == 0 || evidence_empty == 1)) {
                    print pkt ":" current_id " fact without evidence content"
                    issue = 1
                }
                exit issue
            }
        ' "$pkt_dir/assumptions.yaml"
        if [ "$?" != "0" ]; then
            if [ "$EVIDENCE_STRICT" = "yes" ]; then
                fail "$pkt_name: fact marker(s) without evidence content"
            else
                warn "$pkt_name: fact marker(s) without evidence content"
            fi
        fi

        # Check 3: evidence content placeholder detection (if enabled).
        if [ "$PLACEHOLDER_DETECTION" != "off" ]; then
            placeholder_count=$(awk -v markers="$EVIDENCE_PLACEHOLDERS" '
                BEGIN { count = 0; evidence_value = "" }
                # New assumption: check previous evidence
                /^[ ]*- id:/ {
                    if (evidence_value != "" && match(evidence_value, markers)) count++
                    evidence_value = ""
                    next
                }
                # Capture evidence value (single line)
                /^    evidence:/ {
                    line = $0
                    sub(/^[[:space:]]*evidence:[[:space:]]*/, "", line)
                    gsub(/^["'"'"']|["'"'"']$/, "", line)
                    if (line != "" && line != "|") evidence_value = line
                    next
                }
                END {
                    if (evidence_value != "" && match(evidence_value, markers)) count++
                    print count+0
                }
            ' "$pkt_dir/assumptions.yaml")
            if [ "${placeholder_count:-0}" -gt 0 ] 2>/dev/null; then
                msg="$pkt_name: $placeholder_count assumption(s) with placeholder evidence"
                if [ "$EVIDENCE_STRICT" = "yes" ]; then
                    fail "$msg"
                else
                    warn "$msg"
                fi
            fi
        fi

        # applied requires at least one approve review (inside case applied above).

        # draft placeholder text in decision.md or refinement.md.
        if [ "$lc" = "draft" ] || [ "$lc" = "applied" ]; then
            for f in decision.md refinement.md; do
                if [ -f "$pkt_dir/$f" ] && grep -qE "$PLACEHOLDER_MARKERS" "$pkt_dir/$f" 2>/dev/null; then
                    warn "$pkt_name: $f may contain placeholder text"
                fi
            done
        fi

        # draft older than abandoned_threshold_days: warn to consider abandon.
        if [ "$lc" = "draft" ]; then
            created_date=$(grep '^created:' "$pkt_dir/packet.yaml" \
                | sed 's/^created:[[:space:]]*["'"'"']//' | sed 's/["'"'"']$//')
            if [ -n "$created_date" ]; then
                threshold_epoch=$(date -u -d "$ABANDONED_THRESHOLD_DAYS days ago" +%s 2>/dev/null)
                created_epoch=$(date -u -d "$created_date" +%s 2>/dev/null)
                if [ -n "$threshold_epoch" ] && [ -n "$created_epoch" ] && \
                   [ "$created_epoch" -lt "$threshold_epoch" ] 2>/dev/null; then
                    warn "$pkt_name: draft older than $ABANDONED_THRESHOLD_DAYS days (consider abandon)"
                fi
            fi
        fi

        # v0.992: amendments[] entries must have date, by, reason, sha.
        if grep -q '^amendments:' "$pkt_dir/packet.yaml" 2>/dev/null; then
            awk -v pkt="$pkt_name" '
                BEGIN { in_block = 0; in_entry = 0; ok = 0
                        has_date = 0; has_by = 0; has_reason = 0; has_sha = 0 }
                /^amendments:/ { in_block = 1; next }
                in_block && /^[^ ]/ { in_block = 0 }
                in_block && /^  - / {
                    if (in_entry) check_entry()
                    in_entry = 1
                    has_date = 0; has_by = 0; has_reason = 0; has_sha = 0
                    next
                }
                in_block && in_entry {
                    if (/date:/) has_date = 1
                    if (/by:/) has_by = 1
                    if (/reason:/) has_reason = 1
                    if (/sha:/) has_sha = 1
                }
                END { if (in_entry) check_entry(); exit ok }
                function check_entry() {
                    if (!has_date || !has_by || !has_reason || !has_sha) {
                        print pkt ": amendment missing date/by/reason/sha"
                        ok = 1
                    }
                }
            ' "$pkt_dir/packet.yaml" && pass || warn "$pkt_name: amendment missing date/by/reason/sha"
        fi

        # self_approve_allowed=no: reviews must not contain self-approve.
        if [ "$SELF_APPROVE_ALLOWED" = "no" ] && [ "$lc" = "applied" ]; then
            packet_creator=$(grep '^creator:' "$pkt_dir/packet.yaml" \
                | sed 's/^creator:[[:space:]]*//')
            if [ -n "$packet_creator" ]; then
                # Look for reviews[] entries with `by: <creator>`.
                bad=$(awk -v creator="$packet_creator" '
                    BEGIN { in_block = 0 }
                    /^reviews:/ { in_block = 1; next }
                    in_block && /^[^ ]/ { in_block = 0 }
                    in_block && /^  - by:/ {
                        by_line = $0
                        sub(/^  - by:[[:space:]]*/, "", by_line)
                        if (by_line == creator) print "yes"
                    }
                ' "$pkt_dir/packet.yaml")
                if [ "$bad" = "yes" ]; then
                    fail "$pkt_name: self_approve_allowed=no, but reviews[] contains self-approve"
                fi
            fi
        fi
    done
else
    echo "  note: $MATH_DIR does not exist (empty workspace)" >&2
fi

# Document-level checks
if [ -f "$AXIOMS_DOC" ]; then
    axiom_count=$(grep -cE '^## A[0-9]\. ' "$AXIOMS_DOC" || true)
    [ "$axiom_count" = "7" ] && pass || fail "docs/axioms.md: expected 7 axioms, found $axiom_count"
else
    fail "docs/axioms.md: missing"
fi

if [ -d "$THEORIES_DIR" ]; then
    theory_count=$(find "$THEORIES_DIR" -maxdepth 1 -name '*.md' ! -name 'README.md' | wc -l)
    [ "$theory_count" = "8" ] && pass || fail "theories/: expected 8 theories, found $theory_count"
else
    fail "theories/: missing"
fi

echo ""
echo "verify: $checks checks, $errors errors, $warnings warnings"

if [ "$cross_packet" = "1" ]; then
    echo ""
    echo "=== cross-packet-consistency ==="
    sh "$REPO_ROOT/core/check/cross-packet-check.sh"
    cp_exit=$?
    errors=$((errors + cp_exit))
fi

exit "$errors"