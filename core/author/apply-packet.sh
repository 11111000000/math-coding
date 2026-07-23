#!/bin/sh
# core/author/apply-packet.sh — math-coding v0.992 packet applier.
#
# Usage:
#   sh math-coding apply <name> [options]
#
# Options:
#   --sha=<commit>           explicit SHA
#   --files=<glob>           explicit file list (comma-separated)
#   --tests=<command>        record test command (informational)
#   --tests-result=<status>  record result (PASS|FAIL|SKIP|ERROR)
#   --help -h                this message
#
# Records the SHA witness in a sibling `witness` file
# (NOT in packet.yaml — see axiom A5 recursion rule) and
# transitions the packet to applied.
#
# SHA selection (in order):
#   1. --sha=<commit> if given
#   2. Last commit that modified math/<name>/
#   3. Last commit whose message mentions <name>
#   4. Last commit at all
#
# Files selection (informational; not stored in witness):
#   1. --files=<glob> if given (comma-separated)
#   2. git diff --name-only <prev_witness_sha>..<sha> for files in commit
#   3. Empty list
#
# After recording:
#   draft -> applied
#   applied stays applied (warning that new SHA is added)
#   retired stays retired (error)
#
# v0.992: witness file is one line, space-separated git SHAs.
# First SHA is canonical. Append-only across applies.

set -u

. "$(dirname "$0")/../lib/common.sh"

usage() {
    cat <<'EOF' >&2
usage: apply-packet.sh <name> [options]

Records the SHA witness and transitions the packet to applied.

Options:
    --sha=<commit>           explicit SHA
    --files=<glob>           explicit files (comma-separated)
    --tests=<command>        record test command
    --tests-result=<status>  PASS | FAIL | SKIP | ERROR
    --help -h                this message
EOF
    exit 2
}

name=""
sha=""
files=""
tests=""
tests_result=""

while [ $# -gt 0 ]; do
    case "$1" in
        --sha=*) sha="${1#--sha=}"; shift ;;
        --files=*) files="${1#--files=}"; shift ;;
        --tests=*) tests="${1#--tests=}"; shift ;;
        --tests-result=*) tests_result="${1#--tests-result=}"; shift ;;
        --help|-h) usage ;;
        -*) echo "unknown flag: $1" >&2; usage ;;
        *) name="$1"; shift ;;
    esac
done

[ -z "$name" ] && usage

DEST="$MATH_DIR/$name"
[ -d "$DEST" ] || { echo "error: $DEST not found" >&2; exit 2; }
[ -f "$DEST/packet.yaml" ] || { echo "error: $DEST/packet.yaml not found" >&2; exit 2; }

# v0.992+: pre-apply self-critique echo (configurable)
if [ "$SELF_CRITIQUE_ECHO" = "yes" ]; then
    cat <<'CRITIQUE'

Pre-apply self-critique:
  1. Have you implemented the operation in code?
  2. Have you written and run the test?
  3. Does the test pass?
  4. Have you self-reviewed against field checklists?

If any answer is NO, run test first or revise.

CRITIQUE
fi

# Determine SHA
if [ -z "$sha" ]; then
    RELATIVE_DEST="$MATH_DIR/$name"
    case "$RELATIVE_DEST" in
        "$REPO_ROOT"/*)
            RELATIVE_DEST="${RELATIVE_DEST#$REPO_ROOT/}"
            ;;
    esac

    # Try 1: last commit on math/<name>/
    sha=$(git -C "$REPO_ROOT" log --oneline -1 -- "$RELATIVE_DEST" 2>/dev/null | awk '{print $1}')

    # Try 2: last commit mentioning <name> in message
    if [ -z "$sha" ]; then
        sha=$(git -C "$REPO_ROOT" log --oneline --grep="$name" -1 2>/dev/null | awk '{print $1}')
        if [ -n "$sha" ]; then
            echo "info: SHA found via commit message match" >&2
        fi
    fi

    # Try 3: last commit at all
    if [ -z "$sha" ]; then
        sha=$(git -C "$REPO_ROOT" log -1 --format=%H 2>/dev/null)
        if [ -n "$sha" ]; then
            echo "info: SHA is last commit at all (no specific match)" >&2
        fi
    fi

    if [ -z "$sha" ]; then
        echo "error: no git history; commit the packet first, then apply" >&2
        exit 1
    fi
fi

# Validate SHA
if ! git -C "$REPO_ROOT" cat-file -e "$sha" 2>/dev/null; then
    echo "error: SHA $sha unknown to local git history" >&2
    exit 1
fi

# Determine files
if [ -z "$files" ]; then
    # Get all files in commit, excluding the packet itself
    prev_sha=$(grep -oE 'sha: [0-9a-f]+' "$DEST/packet.yaml" | tail -1 | awk '{print $2}')
    if [ -n "$prev_sha" ] && git -C "$REPO_ROOT" cat-file -e "$prev_sha" 2>/dev/null; then
        files=$(git -C "$REPO_ROOT" diff --name-only "$prev_sha".."$sha" 2>/dev/null \
            | grep -v "^$MATH_DIR/$name/" \
            | grep -v "^.math-coding/")
    else
        # No prev SHA: list files in commit, excluding the packet
        files=$(git -C "$REPO_ROOT" show --name-only --format= "$sha" 2>/dev/null \
            | grep -v "^$MATH_DIR/$name/" \
            | grep -v "^.math-coding/" \
            | grep -v "^$")
    fi
fi

# Read current lifecycle
lifecycle=$(get_lifecycle "$DEST/packet.yaml")

case "$lifecycle" in
    draft)
        new_lifecycle="applied"
        ;;
    applied)
        new_lifecycle="applied"
        echo "warning: packet is already applied; adding new SHA witness" >&2
        ;;
    retired)
        echo "error: cannot apply a retired packet; archive it first" >&2
        exit 1
        ;;
    *)
        echo "error: invalid lifecycle '$lifecycle'" >&2
        exit 1
        ;;
esac

date=$(date -u +%Y-%m-%d)

# Update packet.yaml: change lifecycle only. Applications[]
# is NOT in packet.yaml anymore (axiom A5 recursion fix).
tmp_yaml=$(mktemp) || { echo "error: mktemp failed" >&2; exit 1; }
sed "s/^lifecycle: .*/lifecycle: $new_lifecycle/" "$DEST/packet.yaml" > "$tmp_yaml"
mv "$tmp_yaml" "$DEST/packet.yaml"
rm -f "$tmp_yaml"

# Append SHA to witness file (one line, space-separated SHAs).
witness_file="$DEST/witness"
if [ -f "$witness_file" ]; then
    # Append: existing SHAs + new SHA, space-separated, one line.
    existing=$(cat "$witness_file")
    printf '%s %s\n' "$existing" "$sha" > "$witness_file"
else
    printf '%s\n' "$sha" > "$witness_file"
fi

echo "Applied: $name"
echo "  lifecycle: $new_lifecycle"
echo "  sha: $sha"
echo "  witness: $witness_file"
if [ -n "$files" ]; then
    file_count=$(echo "$files" | tr ',' '\n' | grep -c .)
    echo "  files: $file_count (informational)"
fi
[ -n "$tests" ] && echo "  tests: $tests"
[ -n "$tests_result" ] && echo "  tests_result: $tests_result"

# v0.992: review is a separate command. Apply does not call
# verify — that is a separate concern. Run `sh math-coding verify`
# after apply to check structural correctness, and `sh math-coding
# review <name> --approve` to provide peer approval.
echo ""
echo "Next: run 'sh math-coding review <name> --approve' to record review."
echo "      (v0.992 requires >=1 approve for applied packets)"