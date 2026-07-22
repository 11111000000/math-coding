#!/bin/sh
# core/install/install.sh — math-coding v0.992 brownfield installer.
#
# Usage: sh core/install/install.sh <target-dir> [--gitignore]
#
# Installs the convention into a target project.
#
# By default, .math-coding/ is COMMITTED to the project's git
# repository. This means new clones have the convention without
# running install.sh manually, and CI works out-of-the-box.
# Use --gitignore to opt-in to the historical behavior of
# adding .math-coding/ to .gitignore.
#
# Four things happen:
#
#   1. .math-coding/ is created with the install payload
#      (core/, theories/, docs/, dispatcher). axiom packets
#      under math/ are NOT copied — they live only in the
#      source-repo where they prove axiom Self-Application.
#
#   2. <target>/math/ is created as the empty workspace
#      for the target's own packets. A README stub points
#      the user to the full workflow.
#
#   3. <target>/.mathrc is created with mode/role/math_dir
#      defaults.
#
#   4. If --gitignore is passed, .math-coding/ is added to
#      .gitignore. Otherwise the convention is committed.

set -u

. "$(dirname "$0")/../lib/common.sh"

usage() {
    cat <<EOF >&2
usage: install.sh <target-dir> [--gitignore]

Installs math-coding into <target-dir>.

Options:
    --gitignore    add .math-coding/ to .gitignore (opt-in)
    --help -h      this message

By default .math-coding/ is committed (CI works without
manual install). Use --gitignore to opt out.
EOF
    exit 2
}

TARGET=""
GITIGNORE_OPT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --gitignore) GITIGNORE_OPT=1; shift ;;
        --help|-h) usage ;;
        -*) echo "unknown flag: $1" >&2; usage ;;
        *) TARGET="$1"; shift ;;
    esac
done

[ -z "$TARGET" ] && usage

TARGET="$(cd "$TARGET" && pwd)"

if [ ! -d "$TARGET" ]; then
    echo "error: target $TARGET is not a directory" >&2
    exit 2
fi

DEST="$TARGET/.math-coding"

if [ -d "$DEST" ]; then
    echo "error: $DEST already exists" >&2
    exit 1
fi

mkdir -p "$DEST"

# Copy install payload: core/, theories/, docs/.
# math/ is intentionally NOT copied. axiom packets are
# source-repo only (they prove the convention against itself;
# they are not the convention's content for downstream
# projects).
for d in core theories docs; do
    if [ -d "$REPO_ROOT/$d" ]; then
        cp -R "$REPO_ROOT/$d" "$DEST/$d"
    fi
done

# Copy dispatcher.
cp "$REPO_ROOT/math-coding" "$DEST/math-coding"
chmod +x "$DEST/math-coding"

# Create <target>/math/ as the workspace for user packets.
TARGET_MATH="$TARGET/math"
if [ ! -d "$TARGET_MATH" ]; then
    mkdir -p "$TARGET_MATH"
    cat > "$TARGET_MATH/README.md" <<'EOF'
# math/

This directory holds the project's packets. Each packet has
three mandatory files: `packet.yaml`, `decision.md`,
`refinement.md`. Two optional files (`task.md`,
`assumptions.yaml`) are auto-generated.

## Workflow

### 1. Create a packet

Write a spec with seven fields (proposition, outcome,
invariant, test, antithesis, synthesis, operation):

    cat > /tmp/spec.yaml <<YAML
    proposition: |
      <one sentence — the claim>
    outcome: |
      <one sentence — what becomes true>
    invariant: |
      <one sentence — what stays true>
    test: |
      <how to verify, in 1-3 sentences>
    antithesis: |
      <the strongest objection>
    synthesis: |
      <how thesis + antithesis resolve>
    operation: |
      <what the code does>
    YAML

    sh ./.math-coding/math-coding create my-feature --from /tmp/spec.yaml

### 2. Implement and commit

Write the code that realizes `operation`. Commit:

    git add .
    git commit -m "my-feature: implementation"

### 3. Apply (record SHA witness)

    sh ./.math-coding/math-coding apply my-feature

Optional flags:
  --tests="<command>"          record test command
  --tests-result=PASS|FAIL     record result
  --files=<glob>               explicit file list

### 4. Review (peer approval — required for applied)

    sh ./.math-coding/math-coding review my-feature \
        --approve --note="tests pass"

v0.991+: applied packets require at least one approve review
in `packet.yaml:reviews[]`. Self-approve is allowed (marked
`by: ai-agent-...`) but a different reviewer is stronger.

### 5. Retire (when proposition changes or no longer applies)

    # Two-step supersession:
    sh ./.math-coding/math-coding retire my-feature --reason=supersession
    sh ./.math-coding/math-coding create my-feature-v2 --from spec.yaml
    # then add to v2's packet.yaml: supersession: math/my-feature/

    # Or one-step:
    sh ./.math-coding/math-coding retire my-feature \
        --reason=supersession \
        --supersede-with=my-feature-v2 \
        --from=v2-spec.yaml

    # Deprecation (no successor):
    sh ./.math-coding/math-coding retire my-feature --reason=deprecation

### 6. Archive (when retired packets accumulate)

    sh ./.math-coding/math-coding archive my-feature --confirm

The packet is moved to `math/archived/my-feature/`. It is
preserved in git history but excluded from `verify` and
`probe`. To permanently remove, `rm -rf math/archived/<name>/`.

### 7. Abandon (when draft will not be implemented)

    sh ./.math-coding/math-coding abandon my-feature

Use this when a draft packet will not be implemented
(proposition proved wrong, requirement cancelled, etc.).
Draft → abandoned is terminal. If you later need a similar
packet, create a new one (optionally with
`supersession: math/my-feature/`).
EOF
fi

# Create .mathrc at the project root.
if [ ! -f "$TARGET/.mathrc" ]; then
    cat > "$TARGET/.mathrc" <<'EOF'
# math-coding configuration
mode: standard
role: developer
math_dir: math
lookahead_ok: 0
committed: 0

# v0.991+ epistemic honesty settings
# Defaults shown; remove any line to use the default.
required_approvals: 1
self_approve_allowed: yes
placeholder_detection: standard
abandoned_threshold_days: 90
self_critique_echo: yes
lifecycle_abandoned_enabled: yes
evidence_strict: no
EOF
fi

# Opt-in: add .math-coding/ to .gitignore.
if [ "$GITIGNORE_OPT" = "1" ]; then
    GITIGNORE="$TARGET/.gitignore"
    if [ -f "$GITIGNORE" ]; then
        if ! grep -q "^.math-coding/$" "$GITIGNORE"; then
            echo ".math-coding/" >> "$GITIGNORE"
        fi
    else
        echo ".math-coding/" > "$GITIGNORE"
    fi
fi

echo "installed math-coding to $DEST"
echo "  core/      $(find "$DEST/core" -type f 2>/dev/null | wc -l | tr -d ' ') files"
echo "  theories/  $(find "$DEST/theories" -type f 2>/dev/null | wc -l | tr -d ' ') files"
echo "  docs/      $(find "$DEST/docs" -type f 2>/dev/null | wc -l | tr -d ' ') files"
echo "  math-coding (dispatcher)"
echo ""
echo "  $TARGET_MATH/  (workspace for your packets)"
echo "  $TARGET/.mathrc  (mode: standard, math_dir: math)"
if [ "$GITIGNORE_OPT" = "1" ]; then
    echo ""
    echo "  note: .math-coding/ is in .gitignore (opt-in)."
else
    echo ""
    echo "  note: .math-coding/ is committed to git (default)."
    echo "        pass --gitignore to opt out."
fi
echo ""
echo "verify:  sh $DEST/math-coding probe"