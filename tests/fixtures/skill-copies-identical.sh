#!/usr/bin/env bash
# tests/fixtures/skill-copies-identical.sh
#
# The OpenCode skill is shipped twice: as the per-user skill under
# ~/.config/opencode/skills/, installed from the in-repo copy, and as
# the adoption document an adopter reads. They are the same document,
# so they must be the same bytes - and nothing but
# scripts/sync-version.sh keeps them so.
#
# sync-version.sh rewrites the derived version points in BOTH files.
# If it ever rewrote only one, the two would diverge and a user
# would be reading a skill that says one version while the installed
# one says another. That is the failure this fixture catches.
set -uo pipefail
cd "$(dirname "$0")/../.."

a=".opencode/skills/math-coding/SKILL.md"
b="adoption/SKILL.md"

for f in "$a" "$b"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: $f is missing"
    echo "skill-copies-identical: FAIL"
    exit 1
  fi
done

if cmp -s "$a" "$b"; then
  echo "ok: the two copies of the skill are byte-identical"
else
  echo "FAIL: the two copies of the skill differ"
  diff "$a" "$b" | head -6
  echo "skill-copies-identical: FAIL"
  exit 1
fi

# And the version they carry must be the version the repo claims.
ver="$(cat VERSION 2>/dev/null || echo '')"
if [ -n "$ver" ] && ! grep -q "MC_VERSION=$ver" "$a"; then
  echo "FAIL: the skill does not carry MC_VERSION=$ver"
  echo "skill-copies-identical: FAIL"
  exit 1
fi
echo "ok: the skill carries MC_VERSION=$ver"

echo
echo "skill-copies-identical: PASS"
exit 0
