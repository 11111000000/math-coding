#!/bin/sh
# core/install/install-skill.sh — math-coding v0.991 skill/agent/hook installer.
#
# Usage:
#   sh core/install/install-skill.sh [options]
#
# Options:
#   --name=<skill>      skill name (default: math-coding)
#   --from=<path>       source directory containing SKILL.md
#                       (default: extensions/agents/<agent>/<skill>)
#   --agent=<name>      target agent (default: opencode)
#                       supported: opencode, claude, cursor
#   --to=<path>         explicit target directory
#                       (overrides --agent)
#   --with-agent        also install math-agent.md as agent
#   --with-hooks        also install hooks
#   --dry-run           show what would be copied, don't copy
#   -h | --help         this message
#
# Examples:
#   # Install math-coding skill to default opencode location
#   sh core/install/install-skill.sh
#
#   # Install skill + Math agent + hooks
#   sh core/install/install-skill.sh --with-agent --with-hooks
#
#   # Install to a different agent
#   sh core/install/install-skill.sh --agent=claude
#
#   # Install a different skill
#   sh core/install/install-skill.sh --name=other-skill --from=path/to/skill

set -u

PROG_NAME="${0##*/}"

usage() {
    cat <<EOF
usage: $PROG_NAME [options]

Install a skill directory to an agent's skills location.

Options:
    --name=<skill>       skill name (default: math-coding)
    --from=<path>        source dir with SKILL.md
                         (default: extensions/agents/<agent>/<name>)
    --agent=<name>       target agent: opencode | claude | cursor
                         (default: opencode)
    --to=<path>          explicit target dir (overrides --agent)
    --with-agent         also install math-agent.md as agent
    --with-hooks         also install hooks
    --dry-run            show what would happen, don't copy
    -h, --help           this message

Examples:
    $PROG_NAME
    $PROG_NAME --with-agent --with-hooks
    $PROG_NAME --agent=claude
    $PROG_NAME --name=foo --from=path/to/foo --to=~/.config/custom/skills
EOF
}

# Default agent target paths. Add new agents here.
# Format: <agent>:<path> (path may use ~ for HOME)
AGENT_TARGETS="
opencode:~/.config/opencode/skills
claude:~/.claude/skills
cursor:~/.cursor/skills
"

# Defaults
SKILL_NAME="math-coding"
AGENT="opencode"
SRC_PATH=""
TARGET_PATH=""
WITH_AGENT=0
WITH_HOOKS=0
DRY_RUN=0

# Parse args
while [ $# -gt 0 ]; do
    case "$1" in
        --name=*)      SKILL_NAME="${1#--name=}" ;;
        --from=*)      SRC_PATH="${1#--from=}" ;;
        --agent=*)     AGENT="${1#--agent=}" ;;
        --to=*)        TARGET_PATH="${1#--to=}" ;;
        --with-agent)  WITH_AGENT=1 ;;
        --with-hooks)  WITH_HOOKS=1 ;;
        --dry-run)     DRY_RUN=1 ;;
        -h|--help)     usage; exit 0 ;;
        *) echo "error: unknown option: $1" >&2; usage; exit 2 ;;
    esac
    shift
done

# Resolve REPO_ROOT
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Determine source path
if [ -z "$SRC_PATH" ]; then
    if [ -f "$REPO_ROOT/extensions/agents/$AGENT/SKILL.md" ]; then
        SRC_PATH="$REPO_ROOT/extensions/agents/$AGENT"
    else
        SRC_PATH="$REPO_ROOT/extensions/agents/$AGENT/$SKILL_NAME"
    fi
fi

# Verify source has SKILL.md
if [ ! -f "$SRC_PATH/SKILL.md" ]; then
    echo "error: SKILL.md not found at $SRC_PATH" >&2
    echo "  (use --from=<path> to specify a different source)" >&2
    exit 1
fi

# Verify SKILL.md has `name:` in frontmatter
skill_name_in_yaml=$(awk '
    /^---/ { in_fm = !in_fm; next }
    in_fm && /^name:/ { sub(/^name:[[:space:]]*/, ""); print; exit }
' "$SRC_PATH/SKILL.md")
if [ -z "$skill_name_in_yaml" ]; then
    echo "error: SKILL.md has no 'name:' in frontmatter" >&2
    echo "  opencode and similar agents require 'name:' field" >&2
    exit 1
fi

# Determine target path
if [ -z "$TARGET_PATH" ]; then
    TARGET_PATH=$(printf '%s\n' "$AGENT_TARGETS" | awk -v agent="$AGENT" -F: '
        $1 == agent { sub(/^[^:]+:/, ""); print; exit }
    ')
    if [ -z "$TARGET_PATH" ]; then
        echo "error: unknown agent '$AGENT'" >&2
        echo "  supported: $(printf '%s\n' "$AGENT_TARGETS" | awk -F: '{print $1}' | tr '\n' ' ')" >&2
        echo "  (use --to=<path> for custom target)" >&2
        exit 1
    fi
    TARGET_PATH=$(printf '%s' "$TARGET_PATH" | sed "s|^~|$HOME|")
fi

TARGET_DIR="$TARGET_PATH/$SKILL_NAME"

# Dry-run or actual copy
if [ "$DRY_RUN" = "1" ]; then
    echo "DRY RUN"
    echo "  from: $SRC_PATH"
    echo "  to:   $TARGET_DIR"
    echo "  files:"
    echo "    SKILL.md (required)"
    [ -d "$SRC_PATH/references" ] && echo "    references/ (optional)"
    [ -d "$SRC_PATH/examples" ] && echo "    examples/ (optional)"
    if [ "$WITH_AGENT" = "1" ]; then
        agent_src="$REPO_ROOT/extensions/agents/opencode/math-agent.md"
        if [ -f "$agent_src" ]; then
            agent_name=$(awk '/^---/{fm=!fm; next} fm && /^name:/{sub(/^name:[[:space:]]*/, ""); print; exit}' "$agent_src")
            echo "    agent: $agent_name ($agent_src)"
        fi
    fi
    if [ "$WITH_HOOKS" = "1" ]; then
        hook_src="$REPO_ROOT/extensions/hooks/pre-tool-use.sh"
        if [ -f "$hook_src" ]; then
            echo "    hook: $hook_src"
        fi
    fi
    exit 0
fi

# Create target directory
mkdir -p "$TARGET_DIR"

# Copy SKILL.md
cp "$SRC_PATH/SKILL.md" "$TARGET_DIR/SKILL.md"

# Copy references/ if exists
if [ -d "$SRC_PATH/references" ]; then
    mkdir -p "$TARGET_DIR/references"
    cp -R "$SRC_PATH/references/." "$TARGET_DIR/references/"
fi

# Copy examples/ if exists
if [ -d "$SRC_PATH/examples" ]; then
    mkdir -p "$TARGET_DIR/examples"
    cp -R "$SRC_PATH/examples/." "$TARGET_DIR/examples/"
fi

# Install Math agent if requested
agent_installed=0
if [ "$WITH_AGENT" = "1" ]; then
    agent_src="$REPO_ROOT/extensions/agents/opencode/math-agent.md"
    if [ -f "$agent_src" ]; then
        agent_name=$(awk '/^---/{fm=!fm; next} fm && /^name:/{sub(/^name:[[:space:]]*/, ""); print; exit}' "$agent_src")
        if [ -z "$agent_name" ]; then
            echo "warning: math-agent.md has no 'name:' field, skipping" >&2
        else
            # Agent install location: $HOME/.config/opencode/agents/$agent_name/
            agents_root="$HOME/.config/opencode/agents"
            mkdir -p "$agents_root/$agent_name"
            cp "$agent_src" "$agents_root/$agent_name/agent.md"
            agent_installed=1
        fi
    else
        echo "warning: $agent_src not found, skipping agent install" >&2
    fi
fi

# Install hooks if requested
hook_installed=0
if [ "$WITH_HOOKS" = "1" ]; then
    hook_src="$REPO_ROOT/extensions/hooks/pre-tool-use.sh"
    if [ -f "$hook_src" ]; then
        hooks_root="$HOME/.config/opencode/hooks"
        mkdir -p "$hooks_root"
        cp "$hook_src" "$hooks_root/pre-tool-use.sh"
        chmod +x "$hooks_root/pre-tool-use.sh"
        hook_installed=1
        # Note: hook registration in opencode.json is manual
        echo ""
        echo "NOTE: To activate the hook, add this to opencode.json:"
        echo "  \"hooks\": {"
        echo "    \"pre_tool_use\": {"
        echo "      \"edit\": \"$hooks_root/pre-tool-use.sh\","
        echo "      \"bash\": \"$hooks_root/pre-tool-use.sh\""
        echo "    }"
        echo "  }"
    else
        echo "warning: $hook_src not found, skipping hook install" >&2
    fi
fi

# Report
echo "Installed $SKILL_NAME skill to $TARGET_DIR"
[ "$agent_installed" = "1" ] && echo "Installed Math agent to $HOME/.config/opencode/agents/"
[ "$hook_installed" = "1" ] && echo "Installed hook to $HOME/.config/opencode/hooks/pre-tool-use.sh"
echo ""
echo "Reload your agent (opencode, claude, cursor, etc.) to pick up the skill."