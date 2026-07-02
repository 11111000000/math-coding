#!/bin/sh
# install.sh — install math-coding templates into a target project.
# Usage: sh install.sh
# Requires: sh, awk, grep, sed, find, git.
# Idempotent.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$(pwd)"
TARGET_MATH_CODING="$TARGET_DIR/math-coding"

SOURCE_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Installing math-coding..."
echo "  Source: $SOURCE_REPO"
echo "  Target: $TARGET_MATH_CODING"

mkdir -p "$TARGET_MATH_CODING"

# Copy schemas
if [ -d "$SOURCE_REPO/schemas" ]; then
    cp -r "$SOURCE_REPO/schemas" "$TARGET_MATH_CODING/schemas"
fi

# Copy theory documents (for reference, not as templates)
if [ -d "$SOURCE_REPO/core/01-Theory" ]; then
    mkdir -p "$TARGET_MATH_CODING/01-Theory"
    cp -r "$SOURCE_REPO/core/01-Theory"/* "$TARGET_MATH_CODING/01-Theory/" 2>/dev/null || true
fi

# Copy templates — none needed; template is built into .opencode/commands/mathpacket

# Copy verifier
if [ -f "$SOURCE_REPO/examples/self-application/verify-consistency.sh" ]; then
    cp "$SOURCE_REPO/examples/self-application/verify-consistency.sh" "$TARGET_MATH_CODING/"
    chmod +x "$TARGET_MATH_CODING/verify-consistency.sh"
fi

# Copy core.md
if [ -f "$SOURCE_REPO/core/core.md" ]; then
    cp "$SOURCE_REPO/core/core.md" "$TARGET_MATH_CODING/"
fi

# README
cat > "$TARGET_MATH_CODING/README.md" <<'INNER'
# math-coding

A convention for structured artifacts (packets) in this project.
Plain text + git. No external dependencies.

## Quick start

1. Read `core.md` for the convention.
2. Copy templates: `cp templates/* math-coding/tasks/my-task/`
3. Fill in `packet.yaml`, `task.md`, `assumptions.yaml`.
4. Run `sh verify-consistency.sh math-coding/tasks/my-task/`.

## Theory

The convention is grounded in 8 theory documents:

- `01-Theory/01-Predicate-and-Invariant.md`
- `01-Theory/02-State-Machine.md`
- `01-Theory/03-Temporal-Logic.md`
- `01-Theory/04-Refinement.md`
- `01-Theory/05-Assumption-Set.md`
- `01-Theory/06-Verdict.md`
- `01-Theory/07-Epistemic.md`
- `01-Theory/08-Deprecation.md`

Read these alongside `core.md` to understand the formal
foundation of each rule.
INNER

echo ""
echo "Done. To verify the convention:"
echo "  sh $TARGET_MATH_CODING/verify-consistency.sh $TARGET_DIR"