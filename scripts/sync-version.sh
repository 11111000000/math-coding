#!/bin/sh
# scripts/sync-version.sh
#
# Keep `adoption/SKILL.md` derived version strings in sync with
# the single source of truth: the `VERSION` file at the repo root.
#
# Two modes:
#   --check    exit 0 if derived points match VERSION,
#              exit 1 with a diff on stdout if they drift.
#              Used by CI on every push.
#   --write    rewrite derived points so they match VERSION.
#              Used by the maintainer before each release commit.
#              Idempotent: re-running on a clean tree produces
#              no diff.
#
# Two derived points in the frontmatter of `adoption/SKILL.md`:
#   line 9  : `compatible_with: mathc@>=<X.Y.Z>`
#             (semver MAJOR.MINOR.PATCH, dropping any prerelease
#             suffix. Per the existing convention.)
#   line 10 : `MC_VERSION=<full-string>`
#             (full contents of VERSION; the release the skill was
#             cut for. The `curl | sh` install block in the body
#             resolves the GitHub release asset from it.)
#
# THE SAME DOCUMENT IS SHIPPED TWICE. `adoption/SKILL.md` is the
# canonical copy an adopter reads; `.opencode/skills/math-coding/
# SKILL.md` is the byte-identical copy the per-user agent skill is
# installed from (tests/cli/init-agent.t and
# scripts/check-opencode-skill.sh both assert the byte-equality).
# `--write` rewrites BOTH; `--check` reads BOTH. A version bump
# that touches one copy and not the other leaves two documents
# that disagree about which release they are for, and the second
# one is the one an agent actually loads.
#
# Optional third derived point (only present after Phase-1 W2):
#   scripts/install-tooling/install.sh:
#   `MC_VERSION_DEFAULT=<full-string>` and URL_PREFIX lines.
#   When this file is absent, sync-version.sh prints a warning
#   and continues with exit 0 (--write) or exit 1 (--check).
#
# POSIX-sh, no bashisms (no `[[ ]]`, no arrays). Compatible
# with dash, ash, and bash-as-sh.
#
# Exit codes:
#   0 — derived points match VERSION (--check); or write succeeded (--write).
#   1 — derived points drift (--check); or diff after --write is non-empty.
#   2 — input error (VERSION missing, file missing, bad mode flag).

set -eu

# Resolve repo root from the script's location so the script works
# when invoked from any CWD. Mirrors the pattern in scripts/dist-adoption.sh.
cd "$(cd "$(dirname "$0")" && pwd)/.."

mode="${1:-}"
case "$mode" in
  --check)  mode="check"  ;;
  --write)  mode="write"  ;;
  -h|--help|help|"")
    cat <<USAGE
Usage: scripts/sync-version.sh --check | --write

  --check   exit 0 if derived points match VERSION, else exit 1.
  --write   rewrite derived points so they match VERSION.
            Idempotent: re-running on a clean tree produces no diff.

Reads: ./VERSION
Writes (--write only): ./adoption/SKILL.md,
                        ./scripts/install-tooling/install.sh (if present)
USAGE
    exit 0
    ;;
  *)
    echo "sync-version: unknown mode: $mode (use --check or --write)" >&2
    exit 2
    ;;
esac

# --- Read VERSION -------------------------------------------------------
if [ ! -s VERSION ]; then
  echo "sync-version: VERSION file is missing or empty" >&2
  echo "diagnostic: MC-VERSION-MISSING" >&2
  exit 2
fi

# Trim trailing whitespace/newlines from VERSION.
VERSION_FULL=$(awk 'NR==1 { sub(/[[:space:]]+$/, ""); print }' VERSION)

# Derive semver MAJOR.MINOR.PATCH from the first token before any `-`.
# Examples:
#   3.1.0-alpha-final      -> 3.1.0
#   3.0.0.20              -> 3.0.0
#   3.2.0                 -> 3.2.0
# Strategy: read the first dot-separated sequence, then drop any
# `-suffix`. We keep this script AWK-only (no bash regex) so it
# works under dash.
VERSION_SEMVER=$(printf '%s\n' "$VERSION_FULL" | awk '
  {
    # Split on "-" first; the first field is the version core.
    n = split($0, parts, "-")
    core = parts[1]
    # From the core, take only the first three dot-separated numbers
    # (drop any .20 trailing patch-equivalent identifier).
    split(core, dots, ".")
    out = dots[1]
    if (dots[2] != "") out = out "." dots[2]
    if (dots[3] != "") out = out "." dots[3]
    print out
  }
')

# --- Targets ------------------------------------------------------------

skill=adoption/SKILL.md
# The per-user agent skill is a SECOND copy of the same document.
# tests/cli/init-agent.t asserts that the installed copy matches
# `adoption/SKILL.md` byte for byte, so the version sync has to
# maintain BOTH: a version bump that rewrites only one of them
# leaves the two divergent, and the next `mathc init --agent
# opencode` installs a skill that disagrees with the canonical one.
agent_skill=.opencode/skills/math-coding/SKILL.md
install_sh=scripts/install-tooling/install.sh

# Expected derived strings:
expected_compatible="compatible_with: mathc@>=${VERSION_SEMVER}"
expected_mc_version="MC_VERSION=${VERSION_FULL}"

# --- Diff/check machinery ----------------------------------------------
# Each check_* function reads a file and compares the current value
# against an expected value. The function name is the path-in-target
# we are checking.

check_skill_compatible() {
  if [ ! -f "$skill" ]; then
    echo "sync-version: $skill is missing" >&2
    return 2
  fi
  if ! grep -qF "$expected_compatible" "$skill"; then
    echo "drift: $skill contains:"
    grep -nF "compatible_with:" "$skill" | head -3 >&2
    echo "expected:" >&2
    echo "  $expected_compatible" >&2
    return 1
  fi
  return 0
}

check_skill_mc_version() {
  # $1 = the file to check. The MC_VERSION line is a derived point
  # in BOTH copies of the skill, so the check is per-file.
  target="$1"
  if [ ! -f "$target" ]; then
    echo "sync-version: $target is missing" >&2
    return 2
  fi
  # WHOLE-LINE match, not a substring match. `grep -qF
  # "MC_VERSION=3.7.4"` also matches the line `MC_VERSION=3.7.45`,
  # so a version that merely STARTS with the wanted one passed a
  # check that was supposed to catch drift. `-x` anchors the pattern
  # to the whole line and `-F` keeps the dots literal.
  if ! grep -qxF "$expected_mc_version" "$target"; then
    echo "drift: $target contains:" >&2
    grep -nF "MC_VERSION=" "$target" | head -3 >&2
    echo "expected:" >&2
    echo "  $expected_mc_version" >&2
    return 1
  fi
  return 0
}

check_install_sh() {
  if [ ! -f "$install_sh" ]; then
    # install.sh is Phase-1 W2 work. Absence is not a drift
    # condition; --check prints a warning and continues.
    echo "(info) $install_sh absent; Phase-1 W2 not yet landed (skipping)" >&2
    return 0
  fi
  # Tolerant of optional quoting: accept both
  #   MC_VERSION_DEFAULT=3.1.0-alpha-final
  #   MC_VERSION_DEFAULT="3.1.0-alpha-final"
  if ! grep -qE "^MC_VERSION_DEFAULT=[\"]?(${VERSION_FULL}|edge)[\"]?\$" "$install_sh"; then
    echo "drift: $install_sh does not contain:" >&2
    echo "  MC_VERSION_DEFAULT=${VERSION_FULL}" >&2
    echo "  (or MC_VERSION_DEFAULT=\"${VERSION_FULL}\")" >&2
    return 1
  fi
  return 0
}

# --- Write machinery ---------------------------------------------------
# In --write mode, we rewrite the derived lines in-place. We use
# `awk` to read the file and substitute the expected strings for the
# existing ones. This is portable across POSIX-sh awk variants.

write_skill() {
  # $1 = the target file. The derived lines are rewritten in place.
  target="$1"
  if [ ! -f "$target" ]; then
    echo "sync-version: $target is missing" >&2
    return 1
  fi
  tmp="$(mktemp)" || { echo "sync-version: mktemp failed" >&2; exit 2; }
  # Two substitution passes: compatible_with, then MC_VERSION.
  # The patterns are anchored on the existing field name and the
  # rest of the line is replaced. If the line is absent, we append
  # a clearly-marked block at the end of the frontmatter (between
  # the second `---` and the body). For now, the simplest correct
  # behaviour is: replace the line if present, and fail if absent
  # (the maintainer is expected to have authored the skill already).
  awk -v compat="$expected_compatible" -v mcver="$expected_mc_version" '
    BEGIN { compat_done = 0; mcver_done = 0 }
    {
      line = $0
      if (compat_done == 0 && line ~ /^compatible_with:[[:space:]]*mathc@>=/) {
        print compat
        compat_done = 1
        next
      }
      if (mcver_done == 0 && line ~ /^MC_VERSION=/) {
        print mcver
        mcver_done = 1
        next
      }
      print line
    }
    END {
      if (compat_done == 0) {
        print "sync-version: warning: compatible_with line not found in " FILENAME " (no insert)" > "/dev/stderr"
      }
      if (mcver_done == 0) {
        print "sync-version: warning: MC_VERSION= line not found in " FILENAME " (no insert)" > "/dev/stderr"
      }
    }
  ' "$target" > "$tmp"

  # Reject if the warning fired (one or both lines were missing).
  #
  # The MC_VERSION post-condition is a WHOLE-LINE match, for the same
  # reason the check is: `--write` and `--check` have to agree on what
  # "in sync" means, or a `--write` that leaves the tree in a state
  # `--check` rejects is a release step that breaks its own gate.
  if ! grep -qF "$expected_compatible" "$tmp"; then
    echo "sync-version: write failed: $target lacks $expected_compatible after rewrite" >&2
    rm -f "$tmp"
    return 1
  fi
  if ! grep -qxF "$expected_mc_version" "$tmp"; then
    echo "sync-version: write failed: $target lacks $expected_mc_version after rewrite" >&2
    rm -f "$tmp"
    return 1
  fi

  mv "$tmp" "$target"
  return 0
}

write_install_sh() {
  if [ ! -f "$install_sh" ]; then
    echo "(info) $install_sh absent; Phase-1 W2 will sync at write time" >&2
    return 0
  fi
  tmp=$(mktemp) || { echo "sync-version: mktemp failed" >&2; exit 2; }
  trap 'rm -f "$tmp"' EXIT INT TERM

  # Match either quoting style (with or without quotes) and rewrite
  # to the canonical `MC_VERSION_DEFAULT="<X>"` form.
  awk -v ver="$VERSION_FULL" '
    BEGIN { done = 0 }
    {
      line = $0
      if (done == 0 && line ~ /^MC_VERSION_DEFAULT=/) {
        printf "MC_VERSION_DEFAULT=\"%s\"\n", ver
        done = 1
        next
      }
      print line
    }
    END {
      if (done == 0) {
        print "sync-version: warning: MC_VERSION_DEFAULT= line not found in install.sh (no insert)" > "/dev/stderr"
      }
    }
  ' "$install_sh" > "$tmp"

  if ! grep -qF "MC_VERSION_DEFAULT=\"${VERSION_FULL}\"" "$tmp"; then
    echo "sync-version: write failed: $install_sh lacks MC_VERSION_DEFAULT after rewrite" >&2
    return 1
  fi

  mv "$tmp" "$install_sh"
  trap - EXIT INT TERM
  return 0
}

# --- Driver --------------------------------------------------------------

case "$mode" in
  check)
    rc=0
    check_skill_compatible  || rc=1
    # The MC_VERSION line is checked in BOTH copies of the skill.
    #
    # It was unchecked from 2026-10-14 to 2026-10-31, and the
    # reason was recorded here: "T6 ux-3-adoption-doc-freshen-2026-10@2
    # replaced the wget|chmod MC_VERSION= literal with the curl | sh
    # --user-skill pattern". That was true of the BODY of the skill,
    # where the install snippet used to pin a release tag; it was never
    # true of the FRONTMATTER, where `MC_VERSION=<VERSION>` has been
    # the release the skill was cut for since v3.7.0.
    #
    # The check was therefore switched off for a literal that had
    # moved, and it stayed off after the literal came BACK -- so
    # `--write` (which REQUIRES the line: see write_skill's
    # post-condition) and `--check` (which did not) disagreed about
    # what a synced skill looks like. A check that is off cannot
    # catch the drift it was written for, and `--check` is the mode
    # CI runs.
    check_skill_mc_version "$skill"       || rc=1
    check_skill_mc_version "$agent_skill"  || rc=1
    check_install_sh        || rc=1
    if [ "$rc" = 0 ]; then
      echo "sync-version: ok (VERSION=$VERSION_FULL, semver=$VERSION_SEMVER)"
    else
      echo "sync-version: drift detected" >&2
    fi
    exit "$rc"
    ;;
  write)
    write_skill "$skill" || exit 1
    # The SECOND copy of the same document. The per-user agent skill
    # and `adoption/SKILL.md` are the same text; tests/cli/init-agent.t
    # asserts the installed copy matches adoption/SKILL.md byte for
    # byte. A version bump that rewrites only one of them leaves the
    # two divergent, and the next `mathc init --agent opencode`
    # installs a skill that disagrees with the canonical one.
    [ -f "$agent_skill" ] && { write_skill "$agent_skill" || exit 1; }
    write_install_sh || exit 1
    echo "sync-version: rewrote derived points (VERSION=$VERSION_FULL, semver=$VERSION_SEMVER)"
    exit 0
    ;;
esac