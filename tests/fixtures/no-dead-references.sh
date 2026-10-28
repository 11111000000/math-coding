#!/usr/bin/env bash
# tests/fixtures/no-dead-references.sh
#
# Verifier for decisions/dead-code-removal-2026-10.yaml
# (`no-reader-remains`).
#
# THE CLAIM. Every name the removal took with it has no reader left
# in the repository. A removal that leaves a reader behind is not a
# removal: the next person finds a symbol that resolves and trusts
# it, and the code carries two answers to one question again.
#
# WHAT IS CHECKED. The removed names, searched across every tracked
# text file, with three exclusions that are stated rather than
# hidden:
#
#   - the decision that records the removal names them on purpose;
#   - this fixture names them on purpose;
#   - `scripts/dev-fast-test` is a DIFFERENT file from the removed
#     `scripts/dev-fast`, and `team_member_full` is a different
#     function from the removed `team_member`; the patterns are
#     anchored so neither is a false positive.
#
# WHY A FIXTURE AND NOT A COMMENT. The removal is the kind of change
# that decays: a later branch merges a file that calls one of these,
# and the build breaks with a name nobody remembers. The fixture is
# the name list.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# The exclusions are separate pathspecs, not one alternation: git's
# pathspec syntax does not read `|` as "or".
skip=(
  ':(exclude)decisions/dead-code-removal-2026-10.yaml'
  ':(exclude)tests/fixtures/no-dead-references.sh'
  ':(exclude)tests/cli/embedded-schemas.t'
  ':(exclude)CHANGELOG.md'
)

# name -> pattern (ERE). The pattern is anchored so that
# `dev-fast` does not match `dev-fast-test` and `team_member` does
# not match `team_member_full`.
check_absent () {
  local label="$1" pattern="$2"
  local hits
  hits="$(git grep -nE "$pattern" -- . "${skip[@]}" 2>/dev/null | grep -v '^\(decisions\|archive\)/' || true)"
  if [ -n "$hits" ]; then
    bad "$label still has a reader:"
    printf '%s\n' "$hits" | sed 's/^/    /'
  else
    ok "$label has no reader"
  fi
}

check_absent "lib/schema_embedded.ml" "schema_embedded"
check_absent "Schema_embedded" "Schema_embedded"
check_absent "Schema.empty" "Schema\.empty\b"
check_absent "Schema.string_opt" "Schema\.string_opt\b"
check_absent "Schema.array_opt" "Schema\.array_opt\b"
check_absent "Schema.object_pairs" "Schema\.object_pairs\b"
check_absent "Schema.take_diag" "Schema\.take_diag\b"
check_absent "Digest.sha256_text" "Digest\.sha256_text\b"
check_absent "Forge.team_member" "Forge\.team_member\b"
check_absent "Forge.clear_cache" "Forge\.clear_cache\b"
check_absent "Capsule.priority_name" "Capsule\.priority_name\b"
check_absent "Memory.empty" "Memory\.empty\b"
check_absent "Templates_embedded.readme_md" "Templates_embedded\.readme_md\b"
check_absent "scripts/fix-attr.sh" "fix-attr\.sh"
check_absent "scripts/dev-fast" "scripts/dev-fast([^_a-zA-Z-]|$)"

# The file itself must be gone: a removed file that is still on disk
# is a file nobody decided to remove.
for f in lib/schema_embedded.ml scripts/fix-attr.sh scripts/dev-fast .work/report.json; do
  if [ -e "$f" ]; then
    bad "$f is still on disk"
  else
    ok "$f is gone"
  fi
done

echo
if [ "$fail" -eq 0 ]; then
  echo "no-dead-references: PASS"
  exit 0
fi
echo "no-dead-references: FAIL"
exit 1
