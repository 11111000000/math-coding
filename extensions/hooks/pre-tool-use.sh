#!/bin/sh
# extensions/hooks/pre-tool-use.sh — math-coding v0.992 soft hook.
#
# Called by opencode before any tool use. Reads tool input from
# stdin (JSON), detects if the action is decision-class, and
# outputs a reminder to stdout if so. Never blocks.
#
# Detection logic (simple, file-based):
# - Reads tool_name from $1 (or stdin)
# - Reads tool input (JSON) from stdin
# - If tool is edit/write and target file matches patterns:
#   - src/, lib/, api/, schema, config
# - Output: "this looks like a decision. Consider a packet."
#
# This is a SOFT hook. It never blocks actions. It just adds
# a reminder that the user/agent can ignore.
#
# Opencode integration:
#   In opencode.json:
#     "hooks": {
#       "pre_tool_use": {
#         "edit": "/path/to/pre-tool-use.sh",
#         "bash": "/path/to/pre-tool-use.sh"
#       }
#     }
#
# Exit codes:
#   0 - allow action (no reminder or trivial action)
#   0 - allow action with reminder printed to stdout
#   2 - block action (NOT USED here — convention never blocks)

set -u

# Read tool name from $1 (opencode convention) or stdin
TOOL_NAME="${1:-}"

# Read tool input from stdin
TOOL_INPUT=$(cat)

# Determine if this is a decision-class action.
# Simple heuristic: edit/write to source files.
is_decision_class() {
    # Check tool name
    case "$TOOL_NAME" in
        edit|write|create) ;;
        *) return 1 ;;
    esac

    # Check file path in input (JSON has "filePath" or similar)
    file_path=$(printf '%s' "$TOOL_INPUT" | grep -oE '"filePath"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    [ -z "$file_path" ] && return 1

    # Pattern match: src/, lib/, api/, schema, config
    # Match both absolute paths (/.../src/foo) and relative (src/foo).
    case "$file_path" in
        */src/*|*/lib/*|*/api/*|*/schema/*|*/config/*|*/migrations/*|\
        src/*|lib/*|api/*|schema/*|config/*|migrations/*)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

is_decision_class || exit 0

# Output reminder. Convention never blocks.
cat <<'REMINDER'

[math-coding] This looks like a decision. Consider documenting:
  - Is this a new feature, schema change, or breaking change?
  - Run: sh math-coding create <name> --from -
  - Or: sh math-coding config (to customize .mathrc)

Convention is opt-in. Ignore this reminder if not relevant.
REMINDER

exit 0