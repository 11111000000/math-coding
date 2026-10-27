#!/usr/bin/env bash
# scripts/ceiling-monotonic.sh — a debt ceiling may only fall.
#
# WHAT THIS IS. The repository pins a number for each kind of debt it
# is paying down, and calls the number a CEILING:
#
#   tests/fixtures/executed-evidence-census.sh   CEILING_UNANCHORED, ...
#   tests/fixtures/legacy-attestation-debt.sh    CEILING_LEGACY, ...
#   tests/fixtures/failing-subject-backlog.sh    CEILING
#   ... thirteen ceilings in six fixture files, at the time of writing.
#
# The convention says a ceiling may fall and may never rise. Until
# this script existed, the convention was enforced by the READER: a
# reviewer was expected to notice a raised number in a diff. The
# corpus says in five places that a raise must be "recorded here so
# it is visible rather than silent", and the measurement says that
# between 2026-10-23 and 2026-10-26 seven ceilings were raised and
# only some of the raises carried a reason next to the number.
#
# This script makes the convention MECHANICAL. It reads every
# CEILING_* in the fixture files, reads the same ceiling at a base
# commit, and fails when the ceiling grew.
#
# THE TWO CHECKS.
#
#   1. MONOTONICITY. A ceiling that is larger at HEAD than at the
#      base commit has grown. Growth is a FAILURE, unless the growth
#      is RECORDED: the comment block above the ceiling must carry a
#      marker naming this exact transition,
#
#          # ceiling-raise: 22 -> 30, <the reason it had to grow>
#
#      The marker must name the old value AND the new value, so a
#      reason recorded for an earlier raise cannot silently authorise
#      the next one. The reason must be non-empty: a marker with
#      nothing after the comma is not a reason. The reason is read up
#      to the next '#', so it is one line and it carries no '#' of its
#      own. A comment block may carry SEVERAL markers - a ceiling
#      that was raised twice has two - and any one of them may be the
#      transition in question.
#
#      A recorded raise is not an authorisation. It is a
#      VISIBILITY mechanism: it puts the raise next to the number, in
#      the diff, where the reviewer and the decision record will see
#      it. The raise still has to be justified in the commit and, if
#      it is a meaningful change, in a decision file.
#
#   2. THE BOUND IS BOUND. A ceiling that is declared and never
#      compared is not a bound. The corpus has this defect: on
#      2026-10-23 the two comparisons of CEILING_LEGACY and
#      CEILING_UNATTESTED were deleted while the two numbers were
#      kept, so the fixture passed because the debt was BELOW the
#      ceiling and not because the ceiling was checked. A ceiling
#      counts as bound when at least one line outside the
#      negative-control section mentions it: the negative control
#      compares a SYNTHETIC corpus against the ceiling, which proves
#      the comparison can fire, and proves nothing about the real
#      measurement.
#
#      The negative-control section is the one the corpus marks with
#      a "# --- N. NEGATIVE CONTROL" header.
#
# WHAT IT DOES NOT DO, STATED PLAINLY.
#
#   - It does not judge the quality of a recorded reason. It checks
#     that one exists.
#   - It does not know whether a debt below its ceiling is being paid.
#     It knows only that the number did not go up.
#   - It does not check the debts that have no ceiling. There are
#     fixtures that report a number and bound nothing; this script
#     cannot see them, because there is nothing to compare.
#   - A ceiling that disappears is reported as a warning, not as a
#     failure: deleting a fixture that carried a bound is a
#     legitimate refactor, and this script has no way to tell it from
#     a bound quietly dropped. A corpus in which EVERY ceiling has
#     disappeared has nothing left to compare, and that is exit 3.
#
# EXIT CODES (constitution.md Invariant 14b: exit 0 means the check
# ran and the corpus passed; it never means "nothing to look at").
#
#   0  every ceiling held, fell, or grew with a recorded reason, and
#      every ceiling is bound.
#   1  a ceiling grew without a recorded reason, or a ceiling is
#      declared and never compared.
#   3  the comparison could not be made: no base commit, or no
#      ceiling was found at all. This is `unknown`, not `pass`.
#
# USAGE.
#
#   scripts/ceiling-monotonic.sh [--base REF] [--repo DIR]
#                                [--fixtures DIR]
#
#   --base REF     the commit to compare against. Default: the merge
#                  base with $GITHUB_BASE_REF when it is set and
#                  resolvable, otherwise HEAD~1.
#   --repo DIR     the repository to inspect. Default: the repository
#                  this script lives in.
#   --fixtures DIR the directory of ceiling fixtures, relative to the
#                  repository root. Default: tests/fixtures.
#
# The comparison is between the WORKING TREE and the base commit, so
# a local run answers the question the author is about to commit.
# In CI the working tree is the checked-out commit, which is the same
# question.
#
# The script needs bash, git, grep, sed and awk. Nothing else.

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_default="$(cd "$script_dir/.." && pwd)"

repo="$repo_default"
base_override=""
fixtures_dir="tests/fixtures"

usage() {
  sed -n '2,/^set -uo/p' "${BASH_SOURCE[0]}" | sed -e 's/^# \{0,1\}//' -e '/^set -uo/d'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --base)    base_override="${2:-}"; shift 2 ;;
    --base=*)  base_override="${1#--base=}"; shift ;;
    --repo)    repo="${2:-}"; shift 2 ;;
    --repo=*)  repo="${1#--repo=}"; shift ;;
    --fixtures) fixtures_dir="${2:-}"; shift 2 ;;
    --fixtures=*) fixtures_dir="${1#--fixtures=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'ceiling-monotonic: unknown argument: %s\n' "$1" >&2; usage >&2; exit 3 ;;
  esac
done

if ! cd "$repo" 2>/dev/null; then
  printf 'ceiling-monotonic: not a directory: %s\n' "$repo" >&2
  exit 3
fi
repo="$(pwd)"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  printf 'ceiling-monotonic: not a git repository: %s\n' "$repo" >&2
  exit 3
fi

fail=0
warn=0
checked=0
grew=0
recorded=0
unbound=0
removed=0
files_seen=0

ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }
note() { printf 'note: %s\n' "$1"; }
warn_line() { printf 'warning: %s\n' "$1"; warn=$((warn + 1)); }

# --- the base commit -------------------------------------------------------
head_sha="$(git rev-parse HEAD 2>/dev/null || true)"
if [ -z "$head_sha" ]; then
  printf 'ceiling-monotonic: HEAD does not resolve; nothing can be compared\n' >&2
  exit 3
fi

resolve_base() {
  if [ -n "$base_override" ]; then
    git rev-parse --verify --quiet "${base_override}^{commit}" 2>/dev/null && return 0
    return 1
  fi
  if [ -n "${GITHUB_BASE_REF:-}" ]; then
    local cand b
    for cand in "origin/${GITHUB_BASE_REF}" "${GITHUB_BASE_REF}" \
                "refs/remotes/origin/${GITHUB_BASE_REF}"; do
      if git rev-parse --verify --quiet "${cand}^{commit}" >/dev/null 2>&1; then
        b="$(git merge-base "$cand" HEAD 2>/dev/null || true)"
        # A merge base equal to HEAD compares HEAD with itself: the
        # check would pass by comparing nothing.
        if [ -n "$b" ] && [ "$b" != "$head_sha" ]; then
          printf '%s\n' "$b"
          return 0
        fi
      fi
    done
  fi
  git rev-parse --verify --quiet 'HEAD~1^{commit}' 2>/dev/null && return 0
  return 1
}

base="$(resolve_base)" || base=""
if [ -z "$base" ]; then
  printf 'ceiling-monotonic: no base commit to compare against '
  printf '(the repository has a single commit, or the base does not resolve)\n' >&2
  printf 'ceiling-monotonic: the comparison did not run; this is unknown, not pass\n' >&2
  exit 3
fi

base_short="$(git rev-parse --short "$base" 2>/dev/null || echo "$base")"
head_short="$(git rev-parse --short HEAD 2>/dev/null || echo "$head_sha")"
base_subject="$(git log -1 --format=%s "$base" 2>/dev/null || echo '?')"

printf 'ceiling-monotonic: repository %s\n' "$repo"
printf 'ceiling-monotonic: base %s (%s) %s\n' "$base_short" "$base_subject" "$head_short"

# --- the ceilings ----------------------------------------------------------
# A ceiling is a line of the form
#
#     CEILING_NAME=123
#
# at the start of a line. The comment block directly above it is
# carried along, because that is where a recorded raise lives.
extract_ceilings() {
  awk '
    /^[[:space:]]*#/ { blk = blk " " $0; next }
    /^CEILING[A-Z_]*=[0-9]+/ {
      name = $0; sub(/=.*/, "", name)
      val  = $0; sub(/^CEILING[A-Z_]*=/, "", val); sub(/[^0-9].*$/, "", val)
      printf "%s\001%s\001%d\001%s\n", name, val, NR, blk
      blk = ""
      next
    }
    { blk = "" }
  '
}

# The recorded-raise marker, if the comment block above the ceiling
# carries one for THIS transition.
#
# A block may carry SEVERAL markers - a ceiling that was raised twice
# has two - and any one of them may be the transition in question.
# The marker has to name the old value AND the new value, so a reason
# recorded for an earlier raise cannot authorise a later one.
recorded_raise_reason() {
  # $1 = comment block, $2 = the base value, $3 = the current value
  local blk="$1" old="$2" new="$3" marker m_old m_new reason
  while IFS= read -r marker; do
    [ -n "$marker" ] || continue
    m_old="$(printf '%s' "$marker" | sed -E 's/.*ceiling-raise:[[:space:]]*([0-9]+)[[:space:]]*->.*/\1/')"
    m_new="$(printf '%s' "$marker" | sed -E 's/.*->[[:space:]]*([0-9]+).*/\1/')"
    [ "$m_old" = "$old" ] || continue
    [ "$m_new" = "$new" ] || continue
    reason="$(printf '%s' "$marker" | sed -E 's/.*->[[:space:]]*[0-9]+[[:space:]]*,[[:space:]]*//' \
               | cut -d'#' -f1 | sed -E 's/[[:space:]]+$//')"
    [ "${#reason}" -ge 20 ] || continue
    printf '%s\n' "$reason"
    return 0
  done < <(printf '%s\n' "$blk" | grep -oE 'ceiling-raise:.*')
  return 1
}

# The line of the "# --- N. NEGATIVE CONTROL" section, if the file has
# one. Uses above that line are uses of the REAL corpus.
negative_control_line() {
  grep -nE '^[[:space:]]*#.*-.*NEGATIVE CONTROL' "$1" 2>/dev/null \
    | head -1 | cut -d: -f1
}

# Is the ceiling BOUND: does at least one line outside the
# negative-control section mention it?
is_bound() {
  # $1 = file, $2 = the ceiling name, $3 = the line of the declaration
  local file="$1" name="$2" decl="$3" marker ln text
  marker="$(negative_control_line "$file")"
  while IFS=: read -r ln text; do
    [ -n "${ln:-}" ] || continue
    case "$text" in \#*) continue ;; esac
    [ "$ln" = "$decl" ] && continue
    if [ -z "$marker" ] || [ "$ln" -lt "$marker" ]; then
      return 0
    fi
  done < <(grep -nw -- "$name" "$file" 2>/dev/null)
  return 1
}

# The fixture files: the tracked ones, and any that are on disk but not
# yet tracked. Only the shell fixtures carry ceilings.
mapfile -t fixture_files < <(
  { git ls-files -- "$fixtures_dir"; ls -1 "$fixtures_dir"/*.sh 2>/dev/null || true; } \
    | sed 's#^\./##' | grep '\.sh$' | sort -u
)

if [ "${#fixture_files[@]}" -eq 0 ]; then
  printf 'ceiling-monotonic: no fixture files under %s\n' "$fixtures_dir" >&2
  printf 'ceiling-monotonic: the check found nothing to compare; this is unknown, not pass\n' >&2
  exit 3
fi

for file in "${fixture_files[@]}"; do
  [ -f "$file" ] || continue
  files_seen=$((files_seen + 1))

  # The ceilings at the base commit. A file that did not exist at the
  # base has no base ceilings: a new file is not a raise.
  base_list="$(git show "$base:$file" 2>/dev/null | extract_ceilings || true)"

  while IFS=$'\001' read -r name val lineno blk; do
    [ -n "${name:-}" ] || continue
    checked=$((checked + 1))

    base_val="$(printf '%s\n' "$base_list" | tr '\001' '\t' \
                 | awk -F'\t' -v n="$name" '$1==n {print $2; exit}')"

    if [ -z "$base_val" ]; then
      ok "$file $name = $val (new: no value at $base_short)"
    elif [ "$val" -gt "$base_val" ]; then
      grew=$((grew + 1))
      if reason="$(recorded_raise_reason "$blk" "$base_val" "$val")"; then
        recorded=$((recorded + 1))
        note "$file $name grew $base_val -> $val (+$((val - base_val))): RECORDED - $reason"
      else
        bad "$file $name grew $base_val -> $val (+$((val - base_val))): no recorded reason"
        bad "  remedy: lower the ceiling, or record the raise in the comment block above it as"
        bad "          '# ceiling-raise: $base_val -> $val, <the reason it had to grow>'"
      fi
    else
      ok "$file $name = $val (base $base_val; fell or held)"
    fi

    if ! is_bound "$file" "$name" "$lineno"; then
      unbound=$((unbound + 1))
      bad "$file $name is declared and never compared: the real measurement never meets it"
      bad "  remedy: compare the measured value against \$$name outside the negative-control section"
    fi
  done < <(extract_ceilings < "$file")

  # The ceilings that were at the base and are not here now.
  current_names="$(extract_ceilings < "$file" | awk -F'\001' '{print $1}')"
  base_pairs="$(printf '%s\n' "$base_list" | awk -F'\001' '$1 != "" {print $1 "=" $2}')"
  while IFS='=' read -r bname bval; do
    [ -n "${bname:-}" ] || continue
    if ! printf '%s\n' "$current_names" | grep -qx -- "$bname"; then
      removed=$((removed + 1))
      warn_line "$file $bname = $bval was at $base_short and is not here now: a bound was removed"
    fi
  done <<< "$base_pairs"
done

printf '\n'
printf 'ceiling-monotonic: %s ceilings in %s fixture files, base %s\n' \
  "$checked" "$files_seen" "$base_short"
printf 'ceiling-monotonic: %s grew (%s recorded), %s declared but never compared, %s removed\n' \
  "$grew" "$recorded" "$unbound" "$removed"

if [ "$checked" -eq 0 ]; then
  printf 'ceiling-monotonic: no ceiling was found; the check would have passed by comparing nothing\n' >&2
  exit 3
fi

if [ "$fail" -ne 0 ]; then
  printf 'ceiling-monotonic: FAIL\n'
  exit 1
fi
printf 'ceiling-monotonic: PASS\n'
exit 0
