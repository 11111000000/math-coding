#!/bin/sh
# tests/doc-version-consistency.sh — math-coding v0.992 version sync checker.
#
# Extracts v0.NNN version labels from headers across the
# convention and asserts they all match a single expected version.
# Prevents the version-drift that produced the v0.854/v0.978/
# v0.991/v0.992 mixed headers found in the v0.991 era.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

EXPECTED="${EXPECTED_VERSION:-v0.992}"

# Files where the version label appears in header or first-line comment.
FILES="README.md AGENTS.md KNOWN_LIMITATIONS.md
docs/README.md docs/axioms.md docs/api.md docs/extensions.md
docs/spec.md docs/when-not-to-use.md
theories/README.md
extensions/tdd.md extensions/obsidian.md
extensions/agents/opencode/SKILL.md
core/README.md core/spec/think-before-do.md core/spec/decision-modes.md
core/agent/mathrc.sh core/install/install.sh core/install/install-smoke-test.sh
core/check/verify.sh core/check/drift-check.sh core/check/cross-packet-check.sh
core/self/probe.sh
core/author/create-packet.sh core/author/apply-packet.sh
core/author/review-packet.sh core/author/retire-packet.sh
core/author/abandon-packet.sh core/author/archive-packet.sh
core/author/extract-packet.sh core/author/stable.sh
core/author/amend-packet.sh core/author/config.sh
core/lib/common.sh
math-coding
extensions/hooks/pre-tool-use.sh
tests/run.sh tests/helpers.sh tests/doc-broken-refs.sh"

mismatches=""

for f in $FILES; do
    abs="$REPO_ROOT/$f"
    [ -f "$abs" ] || continue
    # Extract first occurrence of "math-coding vX.YYY" or "(vX.YYY)"
    found=$(head -10 "$abs" | grep -oE 'math-coding v[0-9]+\.[0-9]+|\(v[0-9]+\.[0-9]+\)' | head -1)
    [ -z "$found" ] && continue
    # Strip "math-coding " prefix and parens
    ver=$(printf '%s' "$found" | sed 's/math-coding //; s/[()]//g')
    if [ "$ver" != "$EXPECTED" ]; then
        mismatches="$mismatches $f:$ver"
    fi
done

if [ -n "$mismatches" ]; then
    printf 'mismatched versions (expected %s):\n' "$EXPECTED" >&2
    for m in $mismatches; do
        printf '  %s\n' "$m" >&2
    done
    exit 1
fi

echo "ok: all headers at $EXPECTED"
exit 0