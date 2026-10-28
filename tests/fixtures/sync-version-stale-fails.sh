#!/usr/bin/env bash
# tests/fixtures/sync-version-stale-fails.sh
#
# Verifier for decisions/version-sync-2026-10.yaml obligation
# `sync-version-stale-detected`. The fixture:
#
#   1. records the current `compatible_with` value in adoption/SKILL.md,
#   2. replaces it with a known-stale string,
#   3. asserts that `scripts/sync-version.sh --check` exits non-zero,
#   4. restores the original value,
#   5. re-asserts that `--check` exits 0 (proves the restoration
#      was complete).
#
# This is the canonical negative fixture: a CI run that hits
# this exits 1, surfacing the drift. The fixture restores the
# tree so a subsequent `--check` is green.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
skill=adoption/SKILL.md

if [ ! -x scripts/sync-version.sh ]; then
  echo "FAIL: scripts/sync-version.sh missing or not executable"
  exit 1
fi

# Backup current line so we can restore at the end.
orig=$(grep -E '^compatible_with:' "$skill" || true)
if [ -z "$orig" ]; then
  echo "FAIL: $skill has no 'compatible_with:' line to perturb"
  exit 1
fi
echo "ok: captured original '$orig' for restoration"

# Perturb: replace the version segment with a known-stale sentinel.
stale='compatible_with: mathc@>=0.0.0-stale'
# Use sed in-place. We anchor on the literal line so we don't
# accidentally rewrite the docstring on line 86 ("see \`compatible_with\`").
sed -i.bak "s|^compatible_with: mathc@>=.*|$stale|" "$skill"

# Assert --check exits non-zero. Capture stderr to surface drift info.
check_log=$(mktemp) || { echo "FAIL: mktemp" >&2; exit 1; }
restore() {
  # Restore the file this fixture perturbed, on EVERY exit path. A
  # trap that only DELETED the backup left the tracked file with the
  # stale sentinel in it whenever the fixture was interrupted -- and a
  # tracked file that a test leaves modified is a change the next
  # commit can pick up by accident.
  if [ -f "$skill.bak" ]; then mv "$skill.bak" "$skill"; fi
  rm -f "$check_log"
}
trap restore EXIT INT TERM

if scripts/sync-version.sh --check >"$check_log" 2>&1; then
  echo "FAIL: sync-version --check exited 0 on a stale tree"
  echo "  (script did not detect drift; expected exit 1)"
  cat "$check_log" >&2
  mv "$skill.bak" "$skill"
  trap - EXIT INT TERM
  exit 1
fi
echo "ok: sync-version --check exits 1 on a stale tree (drift detected)"

# Restore: bring back the original line and the line we just stomped.
mv "$skill.bak" "$skill"

# Re-assert: after restoration, --check exits 0 again. This proves
# the restoration was complete; if it isn't, the fixture exits 1.
if ! scripts/sync-version.sh --check >/dev/null 2>&1; then
  echo "FAIL: sync-version --check still fails after restoration"
  fail=1
else
  echo "ok: sync-version --check exits 0 after restoration"
fi

trap - EXIT INT TERM

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "ok: version-sync-stale-fails (negative path closed)"
exit 0