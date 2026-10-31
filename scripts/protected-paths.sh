#!/usr/bin/env bash
# scripts/protected-paths.sh — the matcher for the protected paths.
#
# ONE list, ONE rule. scripts/protected-paths.txt says WHICH paths are
# protected; this script says whether a path is one of them. The
# kernel has its own implementation of the same rule
# (lib/protected_paths.ml), and the two are compared path by path by
# tests/fixtures/protected-paths-single-source.sh — so the shell rule
# and the kernel rule cannot drift apart without a check going red.
#
# Usage:
#   scripts/protected-paths.sh list          print the patterns, one per line
#   scripts/protected-paths.sh match PATH     exit 0 iff PATH is protected
#   scripts/protected-paths.sh match-stdin    print the protected paths of stdin
#
# WHERE THE LIST IS. $MATH_CODING_PROTECTED_PATHS names the file when
# it is set; otherwise the list next to this script is used. The
# override exists for the same reason it exists everywhere else in
# this repository: the operator owns the path, and a test that needs
# a different list must not have to edit the tree to get one.
#
# FAILING CLOSED. A missing list is an ERROR, not an empty list. "No
# protected paths" and "could not read which paths are protected" are
# different facts, and a gate that cannot read its own inputs must
# not answer "nothing is protected" — that is the green gate this
# repository spent 2026-11 learning to be afraid of. So a missing or
# unreadable list exits 2 with a message, and the callers fail.
#
# THE RULE. A path is protected when it matches one of the patterns,
# with the semantics of a shell `case` pattern (fnmatch without
# FNM_PATHNAME): `*` matches any run of characters INCLUDING `/`, `?`
# matches exactly one character, everything else is literal. The
# pattern is matched against the whole path, so `lib/*` covers
# `lib/gate.ml` and `lib/attestations/evidence.ml` alike.

set -uo pipefail

# The list this matcher reads. Echoed, not read: the caller decides
# what to do with the answer.
protected_paths_file () {
  if [ -n "${MATH_CODING_PROTECTED_PATHS:-}" ]; then
    printf '%s\n' "${MATH_CODING_PROTECTED_PATHS}"
  else
    printf '%s\n' "$(cd "$(dirname "$0")" 2>/dev/null && pwd)/protected-paths.txt"
  fi
}

# The patterns, one per line, comments and blank lines removed.
# Exit 2 when the list cannot be read.
protected_paths_load () {
  local file
  file="$(protected_paths_file)"
  if [ ! -f "$file" ]; then
    echo "protected-paths: the protected-path list is missing: ${file}" >&2
    echo "A gate that cannot read the protected paths cannot ask its question." >&2
    return 2
  fi
  if [ ! -r "$file" ]; then
    echo "protected-paths: the protected-path list is unreadable: ${file}" >&2
    return 2
  fi
  sed -e 's/#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
      -e '/^$/d' "$file"
}

# Is PATH protected? Exit 0 for yes, 1 for no, 2 for "the list could
# not be read".
protected_path_matches () {
  local path="$1" patterns pat rc=1
  patterns="$(protected_paths_load)" || return 2
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    # The pattern is UNQUOTED on purpose: in a `case` pattern an
    # expansion is a pattern, and a quoted one would be a literal.
    # The paths this repository protects contain no spaces, and a
    # pattern with a space would have to be written to survive this
    # line anyway.
    case "$path" in
      $pat)
        rc=0
        break
        ;;
    esac
  done <<< "$patterns"
  return "$rc"
}

usage () {
  echo "usage: protected-paths.sh list|match PATH|match-stdin" >&2
  exit 2
}

cmd="${1:-}"
case "$cmd" in
  list)
    protected_paths_load
    ;;
  match)
    [ "$#" -eq 2 ] || usage
    protected_path_matches "$2"
    ;;
  match-stdin)
    [ "$#" -eq 1 ] || usage
    patterns="$(protected_paths_load)" || exit 2
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      # The patterns are read from a here-string, not from an
      # unquoted expansion: `for pat in $patterns` would let the
      # shell expand `lib/*` against the filesystem before the
      # matcher ever saw it.
      while IFS= read -r pat; do
        [ -n "$pat" ] || continue
        case "$path" in
          $pat)
            printf '%s\n' "$path"
            break
            ;;
        esac
      done <<< "$patterns"
    done
    ;;
  *)
    usage
    ;;
esac
