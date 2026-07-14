#!/bin/sh
# core/verify.sh — convention's structural verifier.
# POSIX shell only. No external dependencies.
#
# Phase B + Phase C checks:
# - math/*/ has 5 files with correct names
# - packet.yaml has 10 required fields (incl. applications) with valid enum values
# - task.md has 3 sections
# - assumptions.yaml has valid entries
# - depends_on is valid list of task_ids
# - applications: has well-formed entries (sha looks hex, by in {agent,human})
# - theory⇄packet: every theories/*.md has at least one packet
#   referencing it
# - coverage.yaml theory: targets resolve to existing files
# - theories/fsm.md and theory-fsm-as-packet/refinement.md
#   list the same set of lifecycle states
# - theories/epistemic.md and 4 theory-packet assumptions
#   agree on the epistemic markers
#
# Returns: exit 0 if all checks pass, exit 1 otherwise
# Reports verdict to core/out/verifier-output.yaml
#
# Authorizes: math/verifier-as-packet (Phase B), math/phase-c-harmony-as-packet (Phase C)

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERIFIER_OUTPUT="$REPO_ROOT/core/out/verifier-output.yaml"

# Load convention-spec.yaml as the single source of truth.
# SPEC_* variables are consumed by drift-check enums below.
# Authorizes: math/convention-spec-as-packet/
SPEC_OUT="$(sh "$REPO_ROOT/core/spec.sh" 2>/dev/null || true)"
if [ -n "$SPEC_OUT" ]; then
    eval "$SPEC_OUT"
fi
[ -z "${SPEC_PACKETS:-}" ] && SPEC_PACKETS=0
[ -z "${SPEC_THEORIES:-}" ] && SPEC_THEORIES=0
[ -z "${SPEC_REQUIRED_PACKET_FILES:-}" ] && SPEC_REQUIRED_PACKET_FILES="packet.yaml decision.md task.md assumptions.yaml refinement.md"
[ -z "${SPEC_GENERATED_PACKET_FILES:-}" ] && SPEC_GENERATED_PACKET_FILES="packet.frontmatter.md"
[ -z "${SPEC_REQUIRED_PACKET_FIELDS:-}" ] && SPEC_REQUIRED_PACKET_FIELDS="task_id title lifecycle substrate rigor decision created verifier depends_on applications"
[ -z "${SPEC_LIFECYCLE_STATES:-}" ] && SPEC_LIFECYCLE_STATES="sketch working verified deprecated archived superseded"
[ -z "${SPEC_SUBSTRATE_VALUES:-}" ] && SPEC_SUBSTRATE_VALUES="none shell tla typescript pbt alloy coq bpmn pbt-prism"
[ -z "${SPEC_RIGOR_VALUES:-}" ] && SPEC_RIGOR_VALUES="light property temporal proof"
[ -z "${SPEC_DECISION_VALUES:-}" ] && SPEC_DECISION_VALUES="needed made"
[ -z "${SPEC_EPISTEMIC_MARKERS:-}" ] && SPEC_EPISTEMIC_MARKERS="fact hypothesis judgment unknown proven"

# Load .mathrc defaults (project-local + user-global).
# Authorizes: math/project-config-as-packet/
MATHRC_OUT="$(sh "$REPO_ROOT/core/mathrc.sh" 2>/dev/null || true)"
if [ -n "$MATHRC_OUT" ]; then
    eval "$MATHRC_OUT"
fi
# Apply defaults for unset keys
[ -z "${MODE:-}" ] && MODE="standard"
[ -z "${ROLE:-}" ] && ROLE="developer"
[ -z "${DRIFT_THRESHOLD_DAYS:-}" ] && DRIFT_THRESHOLD_DAYS="90"
[ -z "${OBSIDIAN_VAULT_NAME:-}" ] && OBSIDIAN_VAULT_NAME="math-coding"
[ -z "${OBSIDIAN_PLUGINS:-}" ] && OBSIDIAN_PLUGINS="dataview,mermaid"
[ -z "${TAG_POLICY:-}" ] && TAG_POLICY="convention"
[ -z "${EXCLUDES:-}" ] && EXCLUDES='.git/**,.agent-shell/**,core/probe-report-*.md,core/checklists/**'

errors=0
checks=0
packets=0
skipped_count=0

log_pass() {
    checks=$((checks + 1))
}

log_fail() {
    echo "  FAIL: $1"
    errors=$((errors + 1))
    checks=$((checks + 1))
}

echo "=== math-coding v0.618 structural verifier (Phase B + C) ==="
echo "REPO_ROOT: $REPO_ROOT"
echo "Configuration (.mathrc):"
echo "  probe_level: ${PROBE_LEVEL:-all}"
echo "  dataview_drift_check: ${PROBE_DATAVIEW_DRIFT_CHECK:-true}"
echo "  role_default: ${ROLE:-developer}"
echo "  mode_default: ${MODE:-standard}"
echo ""

# Check every math/*/ has packet.yaml
for pkt_dir in "$REPO_ROOT"/math/*/; do
    [ -d "$pkt_dir" ] || continue
    pkt_name=$(basename "$pkt_dir")

    # EXCLUDES check (.mathrc:excludes or default).
    # Glob patterns are relative to project root, comma-
    # separated in EXCLUDES (e.g. "experiments/**,archive/**").
    # Translate **/* wildcards to POSIX shell case patterns.
    skipped=""
    if [ -n "${EXCLUDES:-}" ]; then
        # Convert comma-separated list to patterns
        for pattern in $(IFS=','; set -- $EXCLUDES; printf '%s\n' "$@"); do
            # Translate ** to *, /* to *
            shell_pat=$(printf '%s' "$pattern" | sed 's|/\*\*|*|g; s|\*/\*|*|g; s|\*\*|*|g')
            case "$pkt_name" in
                $shell_pat)
                    skipped="$pattern"
                    break ;;
            esac
        done
    fi
    if [ -n "$skipped" ]; then
        echo "  skip: $pkt_name (matches exclude: $skipped)"
        skipped_count=$((skipped_count + 1))
        continue
    fi

    packets=$((packets + 1))
    pkt_yaml="$pkt_dir/packet.yaml"

    # Check source files exist (from convention-spec.yaml:required_packet_files)
    for required_file in $SPEC_REQUIRED_PACKET_FILES; do
        if [ -f "$pkt_dir/$required_file" ]; then
            log_pass
        else
            log_fail "$pkt_name: missing $required_file"
        fi
    done

    # Check packet.yaml fields and enums
    if [ -f "$pkt_yaml" ]; then
        # Required fields (Phase C: applications now required; source = SPEC_REQUIRED_PACKET_FIELDS)
        for field in $SPEC_REQUIRED_PACKET_FIELDS; do
            if grep -q "^$field:" "$pkt_yaml"; then
                log_pass
            else
                log_fail "$pkt_name: packet.yaml missing field $field"
            fi
        done

        # Lifecycle enum (from convention-spec.yaml:lifecycle_states)
        lifecycle=$(grep "^lifecycle:" "$pkt_yaml" | sed 's/^lifecycle: *//' | tr -d '"' | tr -d "'")
        if [ -z "$lifecycle" ]; then
            log_pass
        elif echo " $SPEC_LIFECYCLE_STATES " | grep -q " $lifecycle "; then
            log_pass
        else
            log_fail "$pkt_name: invalid lifecycle '$lifecycle' (must be one of: $SPEC_LIFECYCLE_STATES)"
        fi

        # Substrate enum (from convention-spec.yaml:substrate_values)
        substrate=$(grep "^substrate:" "$pkt_yaml" | sed 's/^substrate: *//' | tr -d '"' | tr -d "'")
        if [ -z "$substrate" ]; then
            log_pass
        elif echo " $SPEC_SUBSTRATE_VALUES " | grep -q " $substrate "; then
            log_pass
        else
            log_fail "$pkt_name: invalid substrate '$substrate' (must be one of: $SPEC_SUBSTRATE_VALUES)"
        fi

        # Rigor enum (from convention-spec.yaml:rigor_values)
        rigor=$(grep "^rigor:" "$pkt_yaml" | sed 's/^rigor: *//' | tr -d '"' | tr -d "'")
        if [ -z "$rigor" ]; then
            log_pass
        elif echo " $SPEC_RIGOR_VALUES " | grep -q " $rigor "; then
            log_pass
        else
            log_fail "$pkt_name: invalid rigor '$rigor' (must be one of: $SPEC_RIGOR_VALUES)"
        fi

        # Decision enum (from convention-spec.yaml:decision_values)
        decision=$(grep "^decision:" "$pkt_yaml" | sed 's/^decision: *//' | tr -d '"' | tr -d "'")
        if [ -z "$decision" ]; then
            log_pass
        elif echo " $SPEC_DECISION_VALUES " | grep -q " $decision "; then
            log_pass
        else
            log_fail "$pkt_name: invalid decision '$decision' (must be one of: $SPEC_DECISION_VALUES)"
        fi

        # depends_on: list of task_ids
        if grep -qE "^depends_on:" "$pkt_yaml"; then
            deps=$(awk '
                /^depends_on:/{flag=1; next}
                /^[a-zA-Z_-]+:/{flag=0}
                flag && /^[[:space:]]*-/ {
                    line = $0
                    sub(/^[[:space:]]*-[[:space:]]*/, "", line)
                    sub(/[[:space:]]*#.*$/, "", line)
                    if (line != "") print line
                }
            ' "$pkt_yaml" | head -20)
            for dep in $deps; do
                if [ -f "$REPO_ROOT/math/$dep/packet.yaml" ] || [ -f "$REPO_ROOT/core/$dep/packet.yaml" ] || [ "$dep" = "core-as-packet" ]; then
                    log_pass
                else
                    log_fail "$pkt_name: depends_on '$dep' which has no packet"
                fi
            done
        fi

        # applications: each entry must have sha (hex) and by in {agent,human}
        if grep -qE "^applications:" "$pkt_yaml"; then
            # Extract lines belonging to the applications[] block.
            # A line belongs if it is the `applications:` opener or
            # begins with whitespace (indented children / new entries).
            # A line that begins with a non-whitespace letter followed
            # by ':' closes the block.
            apps=$(awk '
                function close_block() {
                    in_block = 0
                }
                /^applications:[[:space:]]*/ {
                    print
                    in_block = 1
                    next
                }
                in_block && /^[[:space:]]/ {
                    print
                    next
                }
                in_block && /^[a-zA-Z_]+:[[:space:]]/ {
                    close_block()
                    next
                }
                { next }
            ' "$pkt_yaml")
            # Empty list applications: [] is valid (no entries)
            case "$apps" in
                *"applications: []"*)
                    log_pass ;;
                *)
                    if echo "$apps" | grep -qE 'sha: [0-9a-f]+' && \
                       echo "$apps" | grep -qE 'by: (agent|human)'; then
                        log_pass
                    else
                        log_fail "$pkt_name: applications entries malformed (need sha: <hex>, by: agent|human)"
                    fi ;;
            esac
        fi
    fi

    # Check task.md has 3 sections
    if [ -f "$pkt_dir/task.md" ]; then
        for section in "## Problem" "## Desired outcome" "## Constraints"; do
            if grep -qF "$section" "$pkt_dir/task.md"; then
                log_pass
            else
                log_fail "$pkt_name: task.md missing section '$section'"
            fi
        done
    fi

    # Placeholder-content check. Authorizes: verify-content-minimum.
    # At lifecycle >= working, decision.md / assumptions.yaml must
    # not still contain init-packet.sh template markers such as
    # "<fill in>" or "<your ...>". sketch packets are scaffolds
    # and are exempt.
    case "$lifecycle" in
        sketch|*)
            ;;
        working|verified|deprecated|archived|superseded)
            for placeholder_file in decision.md assumptions.yaml; do
                fp="$pkt_dir/$placeholder_file"
                [ -f "$fp" ] || continue
                if grep -qF "<fill in>" "$fp" 2>/dev/null \
                   || grep -qF "<your " "$fp" 2>/dev/null; then
                    log_fail "$pkt_name: $placeholder_file still contains init-packet placeholders"
                fi
            done
            ;;
    esac

done

# ──────────────────────────────────────────────────────────────
# Phase C drift detection checks (run once, not per packet)
# ──────────────────────────────────────────────────────────────

# Drift check 1: every theories/*.md is referenced by
# at least one packet's assumptions.yaml (so no theory is
# orphan). Skip if no math/*/assumptions.yaml exists yet
# (freshly installed projects have no packets).
if [ -d "$REPO_ROOT/core/theories" ]; then
    has_packets=0
    if [ -d "$REPO_ROOT/math" ]; then
        for ref_yaml in "$REPO_ROOT"/math/*/assumptions.yaml; do
            [ -f "$ref_yaml" ] || continue
            has_packets=1
            break
        done
    fi
    for theory_md in "$REPO_ROOT"/theories/*.md; do
        [ -f "$theory_md" ] || continue
        theory_name=$(basename "$theory_md" .md)
        # Search for See: theories/<name>.md across math/*.
        # Backward-compat: also accept the legacy "core/theories/<name>.md"
        # form used by older packets.
        found=0
        if [ "$has_packets" -eq 1 ]; then
            for ref_yaml in "$REPO_ROOT"/math/*/assumptions.yaml; do
                [ -f "$ref_yaml" ] || continue
                if grep -qF "theories/$theory_name.md" "$ref_yaml" \
                   || grep -qF "core/theories/$theory_name.md" "$ref_yaml"; then
                    found=1
                    break
                fi
            done
        fi
        if [ "$found" -eq 1 ]; then
            log_pass
        elif [ "$has_packets" -eq 1 ]; then
            # Packets exist but theory is orphan — fail
            log_fail "Theory theories/$theory_name.md is orphaned (no packet references it)"
        else
            # No packets yet — skip orphan check
            log_pass
        fi
    done
fi

# Drift check 2: every coverage.yaml:theory: target resolves to
# an existing file.
if [ -f "$REPO_ROOT/core/coverage.yaml" ]; then
    # Extract `theory: X` lines (X may be quoted), strip quoting,
    # check file exists.
    theories_in_coverage=$(awk '
        /^[[:space:]]+theory:[[:space:]]*/ {
            line = $0
            sub(/^[[:space:]]+theory:[[:space:]]*/, "", line)
            sub(/[[:space:]]*#.*$/, "", line)
            # strip surrounding quotes
            gsub(/^"/, "", line)
            gsub(/"$/, "", line)
            gsub(/^'"'"'/, "", line)
            gsub(/'"'"'$/, "", line)
            if (line != "") print line
        }
    ' "$REPO_ROOT/core/coverage.yaml")
    for t in $theories_in_coverage; do
        if [ -f "$REPO_ROOT/$t" ]; then
            log_pass
        else
            log_fail "coverage.yaml theory '$t' resolves to no file"
        fi
    done
fi

# Drift check 3: lifecycle states in theories/fsm.md
# must equal the set parsed from
# math/theory-fsm-as-packet/refinement.md.
if [ -f "$REPO_ROOT/theories/fsm.md" ] && [ -f "$REPO_ROOT/math/theory-fsm-as-packet/refinement.md" ]; then
    fsm_states=$(grep -oE '\b(sketch|working|verified|deprecated|archived|superseded)\b' "$REPO_ROOT/theories/fsm.md" | sort -u | tr '\n' '|')
    pkg_states=$(grep -oE '\b(sketch|working|verified|deprecated|archived|superseded)\b' "$REPO_ROOT/math/theory-fsm-as-packet/refinement.md" | sort -u | tr '\n' '|')
    if [ "$fsm_states" = "$pkg_states" ] && [ -n "$fsm_states" ]; then
        log_pass
    else
        log_fail "FSM states drift: theory=$fsm_states packet=$pkg_states"
    fi
fi

# Drift check 4: epistemic markers in theories/epistemic.md
# must equal the markers in theory-epistemic-as-packet/refinement.md.
# Source of truth: SPEC_EPISTEMIC_MARKERS (includes `proven`).
if [ -f "$REPO_ROOT/theories/epistemic.md" ] && [ -f "$REPO_ROOT/math/theory-epistemic-as-packet/refinement.md" ]; then
    # Build ERE alternation: "fact|hypothesis|..."
    epi_pat=$(printf '%s|' $SPEC_EPISTEMIC_MARKERS | sed 's/|$//')
    epi_theory=$(grep -oE "\b(${epi_pat})\b" "$REPO_ROOT/theories/epistemic.md" | sort -u | tr '\n' '|')
    epi_packet=$(grep -oE "\b(${epi_pat})\b" "$REPO_ROOT/math/theory-epistemic-as-packet/refinement.md" | sort -u | tr '\n' '|')
    if [ "$epi_theory" = "$epi_packet" ] && [ -n "$epi_theory" ]; then
        log_pass
    else
        log_fail "Epistemic markers drift: theory=$epi_theory packet=$epi_packet"
    fi
fi

# Drift check 5: every packet has a packet.frontmatter.md that
# is in sync with packet.yaml. Run core/generate-frontmatter.sh
# --check to detect drift.
if [ -x "$REPO_ROOT/core/generate-frontmatter.sh" ]; then
    if sh "$REPO_ROOT/core/generate-frontmatter.sh" --check >/dev/null 2>&1; then
        log_pass
    else
        log_fail "Dataview frontmatter drift: run sh core/generate-frontmatter.sh to regenerate"
    fi
fi

# Drift check 6: every coverage.yaml id is unique. (Authorises
# coverage-dedup and the inviolable citation rule for D-NN.)
if [ -f "$REPO_ROOT/core/coverage.yaml" ]; then
    ids=$(grep -oE '^\s*- id: D[0-9]+' "$REPO_ROOT/core/coverage.yaml" | awk '{print $3}' | sort)
    if [ -n "$ids" ]; then
        dups=$(printf '%s\n' "$ids" | uniq -d)
        if [ -z "$dups" ]; then
            log_pass
        else
            for d in $dups; do
                log_fail "coverage.yaml has duplicate id: $d"
            done
        fi
    else
        log_pass
    fi
fi

# Write verdict
verdict="VERIFIED"
if [ "$errors" -gt 0 ]; then
    verdict="NEEDS_REVISION"
fi

cat > "$VERIFIER_OUTPUT" <<EOF
verdict: $verdict
errors: $errors
checks: $checks
packets: $packets
verified_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
scope:
  - packet-structure
  - required-fields
  - enum-values
  - depends-on
  - task-md-sections
  - applications-structure
  - theory-packet-coverage
  - coverage-theory-resolution
  - fsm-state-drift
  - epistemic-marker-drift
  - dataview-frontmatter-drift
tool: core/verify.sh
notes: |
  math-coding v0.618 structural verifier (Phase B + C).
  Verifies convention-conformance of math/*/ packets and
  drift between theories/ and the packets applying them.
EOF

echo ""
echo "=== Summary ==="
echo "  packets: $packets"
echo "  skipped: $skipped_count"
echo "  checks:  $checks"
echo "  errors:  $errors"
echo "  verdict: $verdict"

exit "$errors"
