#!/usr/bin/env bash
# tests/fixtures/no-new-python-in-the-tree.sh — the repository admits
# the Python it admits, and nothing arrives by accident.
#
# WHAT IT MEASURES. Two questions, both about the same thing:
#
#   1. Does the tree carry a Python file that nobody decided to have?
#      The answer is the list in scripts/python-allowlist.txt - the ONE
#      answer, the way scripts/protected-paths.txt is the one answer
#      to "which paths are protected?". A file that is not on the
#      list is Python that arrived without a decision; a path on the
#      list that does not exist is a list that has gone stale, and
#      that is a failure too - a list nobody reads rots silently.
#
#   2. Does the KERNEL need a Python interpreter? The kernel is
#      OCaml: lib/ and bin/ are OCaml, and the corpus says so in
#      decisions/mathc-counters-subcommand-2026-10.yaml ("no kernel
#      call path requires a Python interpreter"). That sentence was
#      true when it was written because a counter was moved from a
#      Python script into a subcommand, and nothing kept it true.
#      This fixture keeps it true: no file under lib/ or bin/ may
#      name a Python interpreter.
#
# WHY A LINT AND NOT A DECISION. The house's answer to "the corpus
# cannot grow back" is a pair of lints from tranche T0.3
# (verifier-scheme-allowlist.sh, relation-targets-resolve.sh): each
# one measures a thing the corpus could grow into, and each one has
# a synthetic corpus it must catch. This is the same shape, applied
# to the language the project is written in.
#
# WHY AN ALLOWLIST AND NOT A CEILING. A ceiling is a number that may
# only fall. This is a SET, not a number: the question is not "how
# many Python files are there" but "is this one of them". A file can
# be added only by editing the list, and that edit is visible in the
# diff next to the file that motivated it - which is the property a
# number does not have.
#
# WHY A NEGATIVE CONTROL. A bound that has never been observed to
# bind is not known to bind. Section 4 builds a synthetic tree with a
# Python file that is not on the list and requires this fixture to
# catch it, and a synthetic tree whose list names a file that is not
# there and requires the stale-entry check to catch that too. A lint
# that cannot fail is a comment.
#
# WHY AN UNKNOWN CONTROL. Nothing measured is UNKNOWN, not a zero. If
# the list cannot be read, this fixture must say so and exit 3 - never
# report "no offenders" and pass. A check that cannot read its own
# bound would otherwise be green forever.
#
# Usage: tests/fixtures/no-new-python-in-the-tree.sh
# Exit: 0 pass, 1 fail, 3 unknown.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

ALLOWLIST="scripts/python-allowlist.txt"

# --- 1. read the list --------------------------------------------------
# One path per line; a comment is a line whose first non-blank
# character is #; a blank line is ignored.
read_list() {
  local list="$1" line trimmed
  [ -r "$list" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    trimmed="${line#"${line%%[![:space:]]*}"}"
    [ -n "$trimmed" ] || continue
    case "$trimmed" in \#*) continue ;; esac
    printf '%s\n' "$trimmed"
  done < "$list"
}

if [ ! -r "$ALLOWLIST" ]; then
  echo "no-new-python-in-the-tree: the list $ALLOWLIST cannot be read - the measurement is unknown, not a zero"
  exit 3
fi

list_paths="$(read_list "$ALLOWLIST")"
if [ -z "$list_paths" ]; then
  echo "no-new-python-in-the-tree: the list $ALLOWLIST is empty - a list that admits nothing cannot be a list"
  exit 3
fi
list_count="$(printf '%s\n' "$list_paths" | wc -l | tr -d ' ')"
ok "the list $ALLOWLIST names $list_count Python files"

# --- 2. the measurement, over a tree -----------------------------------
# measure <root> <list>: the Python files in <root> that the list
# does not admit, one per line; and the list's entries that the tree
# does not have. Both are failures: an unadmitted file is Python that
# arrived without a decision, and a stale entry is a list nobody
# reads. Nothing measured is UNKNOWN: an unreadable tree answers
# "unknown", and the caller must not read that as "none".
measure() {
  local root="$1" list="$2" found admitted stale path
  if [ ! -d "$root" ]; then printf 'unknown\n'; return 0; fi

  found="$(cd "$root" && find . -type f -name '*.py' \
    -not -path './_build/*' -not -path './.git/*' \
    -not -path './node_modules/*' -not -path '*/node_modules/*' \
    -not -path './dist/*' -not -path './site/*' \
    -printf '%P\n' 2>/dev/null | LC_ALL=C sort)"
  if [ -z "$found" ] && [ ! -d "$root/.git" ] && [ ! -d "$root/lib" ]; then
    # A directory that is not a repository and has no files at all is
    # not a tree with no Python; it is a tree we cannot read.
    printf 'unknown\n'; return 0
  fi

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if ! printf '%s\n' "$list" | grep -Fxq "$path"; then
      printf 'unadmitted %s\n' "$path"
    fi
  done <<EOF
$found
EOF

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if ! printf '%s\n' "$found" | grep -Fxq "$path"; then
      printf 'stale %s\n' "$path"
    fi
  done <<EOF
$list
EOF
}

measured="$(measure "$PWD" "$list_paths")"
if [ "$measured" = "unknown" ]; then
  echo "no-new-python-in-the-tree: the tree cannot be read - the measurement is unknown, not a zero"
  exit 3
fi

unadmitted="$(printf '%s\n' "$measured" | grep -c '^unadmitted ' || true)"
stale="$(printf '%s\n' "$measured" | grep -c '^stale ' || true)"
found_total="$(printf '%s\n' "$measured" | grep -cE '^(unadmitted|stale) ' || true)"
python_total="$(find . -type f -name '*.py' \
  -not -path './_build/*' -not -path './.git/*' \
  -not -path './node_modules/*' -not -path '*/node_modules/*' \
  -not -path './dist/*' -not -path './site/*' 2>/dev/null | wc -l | tr -d ' ')"

if [ "$unadmitted" -eq 0 ]; then
  ok "the tree carries $python_total Python files and the list admits all of them"
else
  bad "$unadmitted Python file(s) are not on the list:"
  printf '%s\n' "$measured" | grep '^unadmitted ' | sed 's/^unadmitted /       /'
fi

if [ "$stale" -eq 0 ]; then
  ok "the list names no file that is gone"
else
  bad "$stale entries of the list name a file that is not there:"
  printf '%s\n' "$measured" | grep '^stale ' | sed 's/^stale /       /'
fi

# --- 3. the kernel needs no interpreter --------------------------------
# The corpus's own sentence: "no kernel call path requires a Python
# interpreter". The kernel is OCaml, so the check is that no file
# under lib/ or bin/ names one.
kernel_hits="$(grep -rn -E '\bpython[0-9.]*\b' lib/ bin/ --include='*.ml' 2>/dev/null | head -5)"
if [ -z "$kernel_hits" ]; then
  ok "the kernel names no Python interpreter: lib/ and bin/ are OCaml"
else
  bad "the kernel names a Python interpreter:"
  printf '%s\n' "$kernel_hits" | sed 's/^/       /'
fi

# --- 4. the negative control -------------------------------------------
# A lint that has never caught anything is a comment. Two synthetic
# trees: one with a Python file the list does not admit, one whose
# list names a file that is not there. Both must be caught.
control="$(mktemp -d)"
trap 'rm -rf "$control"' EXIT
mkdir -p "$control/tree" "$control/listdir"
printf 'x = 1\n' > "$control/tree/stray.py"
printf 'scripts/known.py\n' > "$control/listdir/list.txt"
printf 'x = 1\n' > "$control/tree/known.py" 2>/dev/null || true

control_measured="$(measure "$control/tree" "$(read_list "$control/listdir/list.txt")")"
if printf '%s\n' "$control_measured" | grep -q '^unadmitted stray.py$'; then
  ok "negative control: a synthetic Python file that the list does not admit is caught"
else
  bad "negative control: a synthetic Python file that the list does not admit was NOT caught - the lint cannot bind"
fi

rm -f "$control/tree/known.py"
control_stale="$(measure "$control/tree" "$(read_list "$control/listdir/list.txt")")"
if printf '%s\n' "$control_stale" | grep -q '^stale scripts/known.py$'; then
  ok "negative control: a list entry that names a file that is not there is caught"
else
  bad "negative control: a list entry that names a file that is not there was NOT caught - the stale-entry check cannot bind"
fi

# --- 5. the unknown path -----------------------------------------------
# Nothing measured is UNKNOWN, not a zero. With the list unreadable
# the fixture must say so and exit 3 - never report "no offenders" and
# pass.
unknown_result="$(read_list "$control/no-such-list.txt" 2>/dev/null; echo "rc=$?")"
if printf '%s' "$unknown_result" | grep -q 'rc=1'; then
  ok "unknown control: with the list unreadable the measurement reports unknown rather than a number"
else
  bad "unknown control: with the list unreadable the measurement did not report unknown - a lint that cannot read its bound would be green forever"
fi

# --- 6. verdict ---------------------------------------------------------
if [ "$fail" -ne 0 ]; then
  echo "no-new-python-in-the-tree: FAIL"
  exit 1
fi
echo "no-new-python-in-the-tree: PASS"
exit 0
