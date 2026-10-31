#!/usr/bin/env bash
# tests/fixtures/sync-version-mc-version-drift-fails.sh
#
# THE NEGATIVE CONTROL FOR `scripts/sync-version.sh --check`.
#
# WHY THIS FIXTURE EXISTS. The MC_VERSION check of the version
# sync script was switched off on 2026-10-14 (commit 6a05a3ab8) and
# stayed off until 2026-10-31. The comment that switched it off
# named a literal that had moved: T6 (ux-3-adoption-doc-freshen-2026-10@2)
# replaced the `wget | chmod` install block in the BODY of
# adoption/SKILL.md -- the block that pinned a release tag -- with the
# canonical `curl | sh --user-skill` pattern. What the check actually
# looked for, `MC_VERSION=<VERSION>`, is in the FRONTMATTER of the
# same document, where it names the release the skill was cut for.
# The literal the comment was about and the literal the check was
# about were never the same line.
#
# A check that has never been observed to go red is not known to be
# able to go red. This fixture is the observation. It builds a
# THROWAWAY COPY of the tree that the script reads (the script
# resolves its own root from its own location, so a copy is the only
# way to make it look at something else), breaks the MC_VERSION line
# in that copy, and requires `--check` to refuse.
#
# WHAT IS MEASURED. Four things, in this order:
#
#   1. a clean copy passes `--check` (exit 0). Without this the
#      fixture could be green because the script refuses everything.
#   2. a copy whose MC_VERSION line was corrupted REFUSES: non-zero
#      exit, and the message names the line it expected. This is the
#      negative control: the check is known to bind.
#   3. the same refusal happens when only the SECOND copy of the
#      skill (the byte-identical `.opencode/skills/math-coding/SKILL.md`)
#      is corrupted. The two copies are separate files; a check that
#      only reads the first one cannot see the second one drift.
#   4. `--write` REPAIRS the corruption, and the repaired tree passes
#      `--check` again. A drift detector that cannot be repaired is
#      only a way to fail a release.
#
# WHY A COPY AND NOT THE REAL TREE. The real tree is the maintainer's
# working copy, and this fixture runs in CI where the tree belongs to
# the build. The copy is made under a temporary directory and removed
# on every exit path (trap), so the fixture leaves nothing behind.
#
# EXIT CODES. 0 = every assertion held. 1 = an assertion did not
# hold. 2 = the fixture could not set itself up (nothing measured).

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

if [ ! -x scripts/sync-version.sh ]; then
  echo "FAIL: scripts/sync-version.sh missing or not executable"
  exit 1
fi

# --- the throwaway tree ---------------------------------------------------
#
# The script reads, relative to its own location:
#   ./VERSION
#   ./adoption/SKILL.md
#   ./.opencode/skills/math-coding/SKILL.md
#   ./scripts/install-tooling/install.sh   (optional; absent is fine)
#
# Only those four are copied. The rest of the repository is not part
# of what this fixture measures, and copying it would make the
# fixture slow for no reason.
work="$(mktemp -d)" || { echo "FAIL: mktemp" >&2; exit 2; }
# shellcheck disable=SC2329   # invoked indirectly (as a trap handler)
cleanup() { rm -rf "$work"; }
trap cleanup EXIT INT TERM

mkdir -p "$work/scripts" "$work/adoption" "$work/.opencode/skills/math-coding" \
  || { echo "FAIL: cannot lay out the throwaway tree" >&2; exit 2; }
cp scripts/sync-version.sh "$work/scripts/" || { echo "FAIL: cannot copy the script" >&2; exit 2; }
cp VERSION "$work/VERSION" || { echo "FAIL: cannot copy VERSION" >&2; exit 2; }
cp adoption/SKILL.md "$work/adoption/" || { echo "FAIL: cannot copy the skill" >&2; exit 2; }
cp .opencode/skills/math-coding/SKILL.md "$work/.opencode/skills/math-coding/" \
  || { echo "FAIL: cannot copy the agent skill" >&2; exit 2; }
chmod +x "$work/scripts/sync-version.sh"

canonical="$work/adoption/SKILL.md"
agent_copy="$work/.opencode/skills/math-coding/SKILL.md"

# The expected line, read out of the copy itself so the fixture does
# not hard-code a version that a release will move.
want_mc_version="$(grep -m1 '^MC_VERSION=' "$canonical" || true)"
if [ -z "$want_mc_version" ]; then
  echo "FAIL: $canonical has no MC_VERSION= line to perturb"
  exit 1
fi
ok "the copy carries '$want_mc_version'"

# --- 1. a clean copy passes ----------------------------------------------
clean_log="$work/clean.log"
if "$work/scripts/sync-version.sh" --check >"$clean_log" 2>&1; then
  ok "a clean copy passes --check (exit 0)"
else
  bad "a clean copy FAILED --check -- the fixture cannot measure anything"
  cat "$clean_log" >&2
  exit 1
fi

# --- 2. a corrupted MC_VERSION line refuses ------------------------------
#
# The corruption is a whole-line replacement, not a substring edit:
# the point is that the CHECK notices a line that is not the line it
# wants. `MC_VERSION=0.0.0-drift` differs from the wanted value in
# its first character and in its length.
sed -i.bak 's/^MC_VERSION=.*/MC_VERSION=0.0.0-drift/' "$canonical"
drift_log="$work/drift.log"
if "$work/scripts/sync-version.sh" --check >"$drift_log" 2>&1; then
  bad "--check exited 0 on a drifted skill -- the check cannot catch its own lie"
  cat "$drift_log" >&2
else
  ok "--check refuses a drifted MC_VERSION line (exit non-zero)"
  if grep -q 'MC_VERSION=' "$drift_log"; then
    ok "the refusal names the line it expected"
  else
    bad "the refusal does not name the MC_VERSION line -- the operator cannot act on it"
    cat "$drift_log" >&2
  fi
fi
mv "$canonical.bak" "$canonical"

# --- 3. the SECOND copy is checked too ------------------------------------
#
# The two copies are separate files with the same content. A check
# that reads only `adoption/SKILL.md` cannot see the agent copy
# drift -- and the agent copy is the one an agent actually loads.
sed -i.bak 's/^MC_VERSION=.*/MC_VERSION=0.0.0-drift/' "$agent_copy"
agent_log="$work/agent.log"
if "$work/scripts/sync-version.sh" --check >"$agent_log" 2>&1; then
  bad "--check exited 0 when only the AGENT copy drifted"
  cat "$agent_log" >&2
else
  ok "--check refuses a drift in the agent copy too (exit non-zero)"
fi
mv "$agent_copy.bak" "$agent_copy"

# --- 4. --write repairs the drift ----------------------------------------
#
# A detector that can only say "no" is not a tool; the release step
# has to be able to fix what it found. The repair is asserted on the
# same copy, so the write path and the check path are exercised
# against the same tree.
sed -i.bak 's/^MC_VERSION=.*/MC_VERSION=0.0.0-drift/' "$canonical"
if "$work/scripts/sync-version.sh" --write >"$work/write.log" 2>&1; then
  if grep -qxF "$want_mc_version" "$canonical"; then
    ok "--write restored the canonical copy"
  else
    bad "--write exited 0 but the canonical copy still carries the drift"
    grep -n '^MC_VERSION=' "$canonical" >&2
  fi
  if grep -qxF "$want_mc_version" "$agent_copy"; then
    ok "--write restored the agent copy"
  else
    bad "--write exited 0 but the agent copy still carries the drift"
    grep -n '^MC_VERSION=' "$agent_copy" >&2
  fi
else
  bad "--write failed on a drifted tree"
  cat "$work/write.log" >&2
fi
mv "$canonical.bak" "$canonical" 2>/dev/null || true

# --- 5. the repaired tree passes again -----------------------------------
if "$work/scripts/sync-version.sh" --check >"$work/final.log" 2>&1; then
  ok "the repaired copy passes --check again"
else
  bad "the repaired copy still fails --check"
  cat "$work/final.log" >&2
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "sync-version-mc-version-drift-fails: PASS"
  exit 0
fi
echo "sync-version-mc-version-drift-fails: FAIL"
exit 1
