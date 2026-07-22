#!/bin/sh
# core/author/config.sh — math-coding v0.992 interactive .mathrc editor.
#
# Usage:
#   sh math-coding config
#
# Reads current values from .mathrc, asks for each field (Enter
# to keep), writes new .mathrc. TTY-aware: interactive if TTY,
# reads all from stdin if not.
#
# Fields (in order):
#   mode, role, math_dir, lookahead_ok, committed
#   required_approvals, self_approve_allowed, placeholder_detection
#   abandoned_threshold_days, self_critique_echo
#   lifecycle_abandoned_enabled, evidence_strict

set -u

. "$(dirname "$0")/../lib/common.sh"

# Read current value from .mathrc
get_value() {
    key="$1"
    if [ -f "$PROJECT_ROOT/.mathrc" ]; then
        awk -F: -v k="$key" '
            $1 == k { sub(/^[^:]+:[[:space:]]*/, ""); gsub(/^["'"'"']|["'"'"']$/, ""); print; exit }
        ' "$PROJECT_ROOT/.mathrc"
    fi
}

# Ask for a value, with current as default.
# Writes prompt to stderr (so it shows in TTY but doesn't
# pollute the captured stdout), writes the value to stdout.
ask() {
    field="$1"
    current="$2"
    allowed="$3"  # optional, e.g. "light/standard/strict"
    if [ -n "$allowed" ]; then
        printf "  %s [%s] (%s): " "$field" "$current" "$allowed" >&2
    else
        printf "  %s [%s]: " "$field" "$current" >&2
    fi
    read -r ans
    if [ -z "$ans" ]; then
        printf '%s' "$current"
    else
        printf '%s' "$ans"
    fi
}

# Write .mathrc preserving comments
write_mathrc() {
    # Read existing .mathrc, preserve comments and unknown fields
    tmp=$(mktemp) || { echo "error: mktemp failed" >&2; exit 1; }
    if [ -f "$PROJECT_ROOT/.mathrc" ]; then
        # Copy existing file to tmp, then update fields
        cp "$PROJECT_ROOT/.mathrc" "$tmp"
    fi
    # Update each field
    update_field() {
        key="$1"
        value="$2"
        # If key exists in file, update; else append
        if grep -q "^${key}:" "$tmp" 2>/dev/null; then
            awk -F: -v k="$key" -v v="$value" '
                $1 == k { print k ": " v; next }
                { print }
            ' "$tmp" > "$tmp.new" && mv "$tmp.new" "$tmp"
        else
            printf '%s: %s\n' "$key" "$value" >> "$tmp"
        fi
    }
    update_field mode "$1"
    update_field role "$2"
    update_field math_dir "$3"
    update_field lookahead_ok "$4"
    update_field committed "$5"
    update_field required_approvals "$6"
    update_field self_approve_allowed "$7"
    update_field placeholder_detection "$8"
    update_field abandoned_threshold_days "$9"
    update_field self_critique_echo "${10}"
    update_field lifecycle_abandoned_enabled "${11}"
    update_field evidence_strict "${12}"
    # Write final .mathrc
    cp "$tmp" "$PROJECT_ROOT/.mathrc"
    rm -f "$tmp"
}

# Main
echo "math-coding configuration wizard"
echo ""
echo "Current .mathrc:"
if [ -f "$PROJECT_ROOT/.mathrc" ]; then
    sed 's/^/  /' "$PROJECT_ROOT/.mathrc"
else
    echo "  (no .mathrc found)"
fi
echo ""
echo "Edit fields (Enter to keep current value):"
echo ""

# Ask for each field
new_mode=$(ask "mode" "$(get_value mode)" "light/standard/strict")
new_role=$(ask "role" "$(get_value role)" "developer/designer/product-manager/researcher/tech-writer")
new_math_dir=$(ask "math_dir" "$(get_value math_dir)" "")
new_lookahead_ok=$(ask "lookahead_ok" "$(get_value lookahead_ok)" "0/1")
new_committed=$(ask "committed" "$(get_value committed)" "0/1")
new_required_approvals=$(ask "required_approvals" "$(get_value required_approvals)" "")
new_self_approve=$(ask "self_approve_allowed" "$(get_value self_approve_allowed)" "yes/no")
new_placeholder=$(ask "placeholder_detection" "$(get_value placeholder_detection)" "off/standard/strict")
new_abandoned=$(ask "abandoned_threshold_days" "$(get_value abandoned_threshold_days)" "")
new_self_critique=$(ask "self_critique_echo" "$(get_value self_critique_echo)" "yes/no")
new_abandoned_enabled=$(ask "lifecycle_abandoned_enabled" "$(get_value lifecycle_abandoned_enabled)" "yes/no")
new_evidence_strict=$(ask "evidence_strict" "$(get_value evidence_strict)" "yes/no")

# Write
write_mathrc "$new_mode" "$new_role" "$new_math_dir" "$new_lookahead_ok" \
    "$new_committed" "$new_required_approvals" "$new_self_approve" \
    "$new_placeholder" "$new_abandoned" "$new_self_critique" \
    "$new_abandoned_enabled" "$new_evidence_strict"

echo ""
echo "Updated .mathrc:"
sed 's/^/  /' "$PROJECT_ROOT/.mathrc"
echo ""
echo "Run 'sh math-coding verify' to confirm changes."