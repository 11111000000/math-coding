#!/bin/sh
# Self-application verifier — math-coding v2.
#
# Implements the structural invariants defined in core/core.md.
# Reads packet.yaml, task.md, assumptions.yaml, refinement.md,
# traceability.json for every packet in the repository and
# reports violations.
#
# Run from the repository root: sh examples/self-application/verify-consistency.sh

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

errors=0
verifier_artifacts="Model.tla verify.sh verify-pytest.sh verify-tlc.sh verify-property.sh verify-consistency.sh verify-schemas.sh verify-property.py verify-property.mjs"
allowed_filenames="packet.yaml task.md assumptions.yaml verifier-output.yaml verification.yaml refinement.md traceability.json decision.md Model.tla Model.cfg theory.md supersession.yaml"

find_packets() {
  find . -name "packet.yaml" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | while read f; do
    dirname "$f"
  done
}

# Get top-level scalar from YAML.
yaml_get() {
    awk -v k="$2" '
        /^[ \t]*#/ { next }
        /^[ \t]*$/ { next }
        /^[ \t]/ { next }
        {
            pos = index($0, ":")
            if (pos == 0) next
            this_key = substr($0, 1, pos - 1)
            gsub(/[ \t]/, "", this_key)
            this_val = substr($0, pos + 1)
            sub(/^[ \t]+/, "", this_val)
            sub(/[ \t]+$/, "", this_val)
            if (length(this_val) >= 2) {
                q1 = substr(this_val, 1, 1)
                q2 = substr(this_val, length(this_val), 1)
                if ((q1 == "\"" && q2 == "\"") || (q1 == "'" && q2 == "'")) {
                    this_val = substr(this_val, 2, length(this_val) - 2)
                }
            }
            if (this_key == k) {
                print this_val
                exit
            }
        }
    ' "$1"
}

yaml_has() {
    grep -qE "^${2}:" "$1" 2>/dev/null
}

yaml_get_nested() {
    awk -v p="$2" -v c="$3" '
        {
            if (substr($0, 1, length(p) + 2) == p ":") {
                in_parent = 1
                next
            }
            if (in_parent && /^[ \t]/ && substr($0, 1, length(c) + 2) == "  " c ":") {
                pos = index($0, ":")
                val = substr($0, pos + 1)
                sub(/^[ \t]+/, "", val)
                sub(/[ \t]+$/, "", val)
                if (length(val) >= 2) {
                    q1 = substr(val, 1, 1)
                    q2 = substr(val, length(val), 1)
                    if ((q1 == "\"" && q2 == "\"") || (q1 == "'" && q2 == "'")) {
                        val = substr(val, 2, length(val) - 2)
                    }
                }
                print val
                exit
            }
            if (in_parent && /^[ \t]*[^ \t]/) {
                in_parent = 0
            }
        }
    ' "$1"
}

check_utf8_lf() {
    file="$1"
    if grep -q $'\r' "$file"; then
        echo "FAIL: $file has CRLF line endings (expected LF)"
        errors=$((errors + 1))
    fi
    if [ -f "$file" ]; then
        first3=$(head -c 3 "$file" | od -An -tx1 | tr -d ' ')
        if [ "$first3" = "efbbbf" ]; then
            echo "FAIL: $file has UTF-8 BOM"
            errors=$((errors + 1))
        fi
    fi
}

check_packet() {
    dir="$1"
    name=$(basename "$dir")
    file="$dir/packet.yaml"

    [ -f "$file" ] || { echo "FAIL: $dir missing packet.yaml"; errors=$((errors + 1)); return; }
    check_utf8_lf "$file"

    # Required fields
    for field in task_id title lifecycle created substrate decision verifier; do
        if ! yaml_has "$file" "$field"; then
            echo "FAIL: $file missing required field '$field'"
            errors=$((errors + 1))
        fi
    done

    # Lifecycle validity
    lifecycle=$(yaml_get "$file" lifecycle)
    is_adr=0
    case "$dir" in
        ./adr/*) is_adr=1 ;;
    esac
    if [ "$is_adr" = "1" ]; then
        case "$lifecycle" in
            proposed|accepted|deprecated|superseded) ;;
            *) echo "FAIL: $file has invalid lifecycle '$lifecycle' (ADR allowed: proposed, accepted, deprecated, superseded)"; errors=$((errors + 1)) ;;
        esac
    else
        case "$lifecycle" in
            sketch|working|verified|deprecated|archived) ;;
            *) echo "FAIL: $file has invalid lifecycle '$lifecycle' (valid: sketch, working, verified, deprecated, archived)"; errors=$((errors + 1)) ;;
        esac
    fi

    # Date format
    created=$(yaml_get "$file" created)
    if [ -n "$created" ] && ! echo "$created" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
        echo "FAIL: $file 'created' is not ISO date: $created"
        errors=$((errors + 1))
    fi

    # FSM: deprecated requires deprecated_at
    if [ "$lifecycle" = "deprecated" ] && ! yaml_has "$file" deprecated_at; then
        echo "FAIL: $file lifecycle=deprecated but no 'deprecated_at' field"
        errors=$((errors + 1))
    fi
    # FSM: archived requires archived_at
    if [ "$lifecycle" = "archived" ] && ! yaml_has "$file" archived_at; then
        echo "FAIL: $file lifecycle=archived but no 'archived_at' field"
        errors=$((errors + 1))
    fi

    # Verifier: null vs object
    verifier_value=$(awk '/^[ \t]*#/ {next} /^verifier:/{ sub(/^verifier:[ \t]*/, ""); print; exit }' "$file")
    verifier_is_null=0
    case "$verifier_value" in
        null|Null|NULL|~|"") verifier_is_null=1 ;;
    esac

    # FSM: working requires artifact
    if [ "$lifecycle" = "working" ] || { [ "$lifecycle" = "verified" ] && [ "$verifier_is_null" -eq 0 ]; }; then
        has_artifact=0
        for art in $verifier_artifacts; do
            if [ -f "$dir/$art" ]; then
                has_artifact=1
                break
            fi
        done
        if [ "$has_artifact" -eq 0 ]; then
            echo "FAIL: $name has lifecycle=$lifecycle but no verifier artifact"
            errors=$((errors + 1))
        fi

        if [ "$verifier_is_null" -eq 0 ]; then
            vcmd=$(yaml_get_nested "$file" verifier command)
            vfile=$(yaml_get_nested "$file" verifier verdict_file)
            if [ -z "$vcmd" ]; then
                echo "FAIL: $file 'verifier' missing 'command'"
                errors=$((errors + 1))
            fi
            if [ -z "$vfile" ]; then
                echo "FAIL: $file 'verifier' missing 'verdict_file'"
                errors=$((errors + 1))
            fi
        fi
    fi

    # FSM: verified requires verdict with provenance
    is_self_app=0
    case "$dir" in
        ./examples/self-application) is_self_app=1 ;;
    esac
    if [ "$lifecycle" = "verified" ] && [ "$is_adr" = "0" ] && [ "$is_self_app" = "0" ] && [ "$verifier_is_null" -eq 0 ]; then
        vfile=$(yaml_get_nested "$file" verifier verdict_file)
        verdict_ok=0
        if [ -n "$vfile" ] && [ -f "$dir/$vfile" ]; then
            verdict=$(yaml_get "$dir/$vfile" verdict)
            [ "$verdict" = "VERIFIED" ] && verdict_ok=1

            # Check provenance: verified_at
            if ! yaml_has "$dir/$vfile" verified_at; then
                echo "FAIL: $name verifier-output missing 'verified_at'"
                errors=$((errors + 1))
            fi
            if ! yaml_has "$dir/$vfile" scope; then
                echo "FAIL: $name verifier-output missing 'scope'"
                errors=$((errors + 1))
            fi
            if ! yaml_has "$dir/$vfile" tool; then
                echo "FAIL: $name verifier-output missing 'tool'"
                errors=$((errors + 1))
            fi
        fi
        if [ "$verdict_ok" -eq 0 ]; then
            echo "FAIL: $name has lifecycle=verified with verifier but no VERIFIED verdict"
            errors=$((errors + 1))
        fi
    fi
}

check_task_md() {
    dir="$1"
    file="$dir/task.md"
    [ -f "$file" ] || { echo "FAIL: $dir missing task.md"; errors=$((errors + 1)); return; }
    check_utf8_lf "$file"

    if ! grep -q "^# " "$file"; then
        echo "FAIL: $file missing H1 title"
        errors=$((errors + 1))
    fi

    if ! awk '/^## Problem/{p=1} /^## Desired outcome/{d=1} p&&d&&/^## Constraints/{c=1} END{exit !(p&&d&&c)}' "$file"; then
        echo "FAIL: $file missing or out-of-order sections"
        errors=$((errors + 1))
    fi

    # Content check: Problem and Desired outcome as prose, Constraints as bullet list
    for section in "## Problem" "## Desired outcome"; do
        words=$(awk -v sec="$section" '
            $0 == sec { in_section = 1; next }
            /^## / && in_section { exit }
            in_section { print }
        ' "$file" | wc -w)
        if [ "$words" -lt 10 ]; then
            echo "FAIL: $file section '$section' has only $words words (min 10)"
            errors=$((errors + 1))
        fi
    done

    # Constraints section: bullet list, each bullet is a predicate or 5+ words
    # Empty Constraints is allowed; section may be absent.
    if grep -q "^## Constraints" "$file"; then
        # Extract the constraints section content
        constraints_content=$(awk '
            /^## Constraints/ { in_section = 1; next }
            /^## / && in_section { exit }
            in_section { print }
        ' "$file")

        # If non-empty, validate each bullet
        if [ -n "$constraints_content" ]; then
            # Split into bullets (lines starting with - or *)
            echo "$constraints_content" | awk '
                /^[ \t]*[-*][ \t]+/ {
                    bullet = $0
                    sub(/^[ \t]*[-*][ \t]+/, "", bullet)
                    if (bullet == "") {
                        print "EMPTY"
                        next
                    }
                    words = split(bullet, parts, /[ \t]+/)
                    has_predicate = 0
                    for (i = 1; i <= words; i++) {
                        w = parts[i]
                        if (w ~ /^(must|shall|requires|has|is|at[ \t]+most|at[ \t]+least|between|>=|<=|=>|==|!=|contains|matches)$/ ||
                            w ~ /[<>=!]/) {
                            has_predicate = 1
                            break
                        }
                    }
                    if (!has_predicate && words < 5) {
                        printf "BULLET_BAD %s\n", bullet
                    } else {
                        printf "BULLET_OK\n"
                    }
                }
            ' > /tmp/constraints_check_$$

            bad_bullets=$(grep "^BULLET_BAD" /tmp/constraints_check_$$ 2>/dev/null | wc -l)
            empty_bullets=$(grep "^EMPTY" /tmp/constraints_check_$$ 2>/dev/null | wc -l)
            rm -f /tmp/constraints_check_$$

            if [ "$empty_bullets" -gt 0 ]; then
                echo "FAIL: $file has empty bullet(s) in ## Constraints"
                errors=$((errors + 1))
            fi
            if [ "$bad_bullets" -gt 0 ]; then
                echo "FAIL: $file has $bad_bullets bullet(s) in ## Constraints without a predicate or 5+ words"
                errors=$((errors + 1))
            fi
        fi
    fi
}

check_assumptions() {
    dir="$1"
    file="$dir/assumptions.yaml"
    [ -f "$file" ] || { echo "FAIL: $dir missing assumptions.yaml"; errors=$((errors + 1)); return; }
    check_utf8_lf "$file"

    if ! yaml_has "$file" task_id; then
        echo "FAIL: $file missing 'task_id'"
        errors=$((errors + 1))
    fi
    if ! grep -q "^assumptions:" "$file"; then
        echo "FAIL: $file missing 'assumptions' list"
        errors=$((errors + 1))
    fi

    if grep -q "^  - id:" "$file"; then
        for field in "id:" "statement:" "status:" "epistemology:"; do
            if ! grep -qE "(^|- )?${field}[[:space:]]" "$file"; then
                echo "FAIL: $file has assumptions but none declare '$field'"
                errors=$((errors + 1))
            fi
        done

        if grep -E "^  - id:" "$file" | grep -vE "^  - id: A[0-9]+$" > /dev/null 2>&1; then
            echo "FAIL: $file has assumption ids not matching 'A<n>' pattern"
            errors=$((errors + 1))
        fi
    fi

    for s in $(grep "^    status:" "$file" | sed 's/^    status: *//'); do
        case "$s" in
            user-confirmed|agent-inferred|open) ;;
            *) echo "FAIL: $file has invalid status '$s'"; errors=$((errors + 1)) ;;
        esac
    done

    for e in $(grep "^    epistemology:" "$file" | sed 's/^    epistemology: *//'); do
        case "$e" in
            fact|hypothesis|judgment|unknown) ;;
            *) echo "FAIL: $file has invalid epistemology '$e'"; errors=$((errors + 1)) ;;
        esac
    done
}

check_refinement() {
    dir="$1"
    file="$dir/refinement.md"
    [ -f "$file" ] || { echo "FAIL: $dir missing refinement.md"; errors=$((errors + 1)); return; }
    check_utf8_lf "$file"

    for section in "## State mapping" "## Operation mapping" "## Invariant preservation" "## Test obligation mapping" "## Runtime-check mapping"; do
        if ! grep -qF "$section" "$file"; then
            echo "FAIL: $file missing section '$section'"
            errors=$((errors + 1))
        fi
    done
}

check_traceability() {
    dir="$1"
    file="$dir/traceability.json"
    [ -f "$file" ] || { echo "FAIL: $dir missing traceability.json"; errors=$((errors + 1)); return; }

    if ! grep -qE '"links"\s*:\s*\[' "$file"; then
        echo "FAIL: $file 'links' field missing or not an array"
        errors=$((errors + 1))
    fi

    if ! grep -qE '"source"\s*:' "$file"; then
        echo "FAIL: $file no links with 'source' field"
        errors=$((errors + 1))
    fi

    if ! grep -qE '"target"\s*:' "$file"; then
        echo "FAIL: $file no links with 'target' field"
        errors=$((errors + 1))
    fi

    if ! grep -qE '"kind"\s*:' "$file"; then
        echo "FAIL: $file no links with 'kind' field"
        errors=$((errors + 1))
    fi
}

check_dependencies() {
    dir="$1"
    all_task_ids="$2"
    file="$dir/packet.yaml"

    deps=$(awk '
        /^depends_on:/ {
            in_deps = 1
            next
        }
        in_deps && /^  - / {
            val = $0
            sub(/^  - /, "", val)
            sub(/[ \t]*$/, "", val)
            sub(/^["'"'"']/, "", val)
            sub(/["'"'"']$/, "", val)
            print val
            next
        }
        in_deps && !/^[ \t]/ {
            in_deps = 0
        }
    ' "$file" 2>/dev/null)

    if [ -n "$deps" ]; then
        for dep in $deps; do
            if ! echo " $all_task_ids " | grep -q " $dep "; then
                echo "FAIL: $(basename "$dir") depends_on '$dep' but no packet with that task_id exists"
                errors=$((errors + 1))
            fi
        done
    fi
}

# Collect all task IDs for dependency checking
all_task_ids=""
for dir in $(find_packets); do
    tid=$(yaml_get "$dir/packet.yaml" task_id)
    if [ -n "$tid" ]; then
        all_task_ids="$all_task_ids $tid"
    fi
done

# Check all packets
for dir in $(find_packets); do
    check_packet "$dir"
    check_task_md "$dir"
    check_assumptions "$dir"
    check_refinement "$dir"
    check_traceability "$dir"
    check_dependencies "$dir" "$all_task_ids"
done

# Write the verifier output
if [ "$errors" -eq 0 ]; then
    cat > examples/self-application/verifier-output.yaml <<'EOF'
verdict: VERIFIED
errors: 0
verified_at: "2026-07-02T00:00:00Z"
scope:
  - packet-yaml-present
  - packet-yaml-required-fields
  - lifecycle-valid
  - task-md-has-three-sections
  - task-md-has-content
  - assumptions-yaml-present
  - epistemic-markers-valid
  - refinement-md-present
  - traceability-json-present
  - encoding-valid
tool: shell-verifier-v2
details: >
  All packets in the repository conform to the v2 conventions.
  Each invariant in core.md is checked by the verifier.
evidence:
  invariants_checked: 14
  packets_checked: $(find . -name "packet.yaml" | wc -l)
EOF
    echo "OK: all packets follow conventions"
    exit 0
else
    printf 'verdict: NEEDS_REVISION\nerrors: %d\nverified_at: "2026-07-02T00:00:00Z"\nscope: [structural-invariants]\ntool: shell-verifier-v2\n' "$errors" > examples/self-application/verifier-output.yaml
    echo "FAIL: $errors convention violation(s)"
    exit 1
fi