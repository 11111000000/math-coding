#!/usr/bin/env bash
# pre-commit: decision-fixture co-commit rule
#
# Invoked by pre-commit-hooks.nix (flake.nix checks.fmt hook).
# Returns 0 (pass) or 1 (fail) depending on whether the staged
# files violate the rule.
#
# Rule (per ROADMAP.md §P1 + §P2):
#   Any commit that touches a "kernel/protected" file MUST also
#   touch at least one of:
#     - decisions/*.yaml    (a decision recorded)
#     - decisions/*.md      (a decision recorded, markdown form)
#     - tests/fixtures/*.sh  (a shell fixture)
#   unless the commit is a pure deferral (see is_pure_deferral).
#
# WHICH FILES ARE PROTECTED:
#   scripts/protected-paths.txt — ONE list, read here through
#   scripts/protected-paths.sh. The same file is read by the gate
#   (lib/gate.ml, via lib/protected_paths.ml) and by the
#   release-pending workflow, so the three gates cannot protect three
#   different sets of files.
#
#   The list used to be written out here, and it disagreed with the
#   gate's list and with the workflow's: one question, three answers.
#   All three old lists are written out in scripts/protected-paths.txt,
#   where the history is recorded.
#
# The check is intentionally permissive (does not require that
# the decision explicitly references the touched file). The
# co-commit signal is the human-level invariant: a kernel change
# without an adjacent decision is the deficit we are catching.

set -uo pipefail

# The shared matcher, and the list it reads. The matcher lives next
# to the list, so the default location needs no configuration; the
# override exists for the same reason it exists everywhere else in
# this repository (the operator owns the path).
HOOK_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
PROTECTED_MATCHER="${MATH_CODING_PROTECTED_PATHS_MATCHER:-$HOOK_DIR/../protected-paths.sh}"

if [ ! -f "$PROTECTED_MATCHER" ]; then
  echo "pre-commit(decision-fixture-co-commit): the protected-path matcher is missing:" >&2
  echo "  ${PROTECTED_MATCHER}" >&2
  echo "" >&2
  echo "The hook cannot know which paths are protected, so it cannot apply" >&2
  echo "the rule. It fails closed: a rule that cannot be evaluated has not" >&2
  echo "been satisfied." >&2
  exit 1
fi

# Is this path protected? Exit 0 = yes, 1 = no, 2 = the list could
# not be read (which is NOT "nothing is protected").
is_protected () {
  local path="$1" rc=0
  bash "$PROTECTED_MATCHER" match "$path" || rc=$?
  if [ "$rc" -eq 0 ]; then
    return 0
  elif [ "$rc" -eq 1 ]; then
    return 1
  fi
  echo "pre-commit(decision-fixture-co-commit): the protected-path list could not be read." >&2
  echo "The matcher exited ${rc}; the hook cannot tell which paths are" >&2
  echo "protected, so it fails closed." >&2
  return 2
}

# Identify the files in question. pre-commit-hooks.nix passes them as
# ARGUMENTS (one per argv entry), the way pre-commit itself does.
# The earlier version of this script read them from stdin instead:
# in the nix build stdin is an open pipe that never reaches EOF, so
# the read loop blocked forever and the `nix flake check` step hung
# instead of failing. The stdin path is kept as a fallback, with a
# one-second read timeout so an open stdin cannot block the check.
declare -a staged=()
if [ "$#" -gt 0 ]; then
  staged=("$@")
else
  while IFS= read -r -t 1 path; do
    staged+=("$path")
  done || true
fi

# If the hook is invoked without filenames (e.g., from `nix flake
# check`), bail without error.
if [ ${#staged[@]} -eq 0 ]; then
  exit 0
fi

# Categorise staged files.
kernel_touched=0
decision_touched=0
fixture_touched=0
declare -a kernel_files=()
declare -a decision_files=()
declare -a fixture_files=()

for path in "${staged[@]}"; do
  # Three answers, not two: "protected", "not protected", and "the
  # list could not be read". The third is not "not protected" -- it
  # is the hook's own input missing, and it ends the run.
  prot_rc=0
  is_protected "$path" || prot_rc=$?
  case "$prot_rc" in
    0)
      kernel_touched=1
      kernel_files+=("$path")
      continue
      ;;
    1)
      : # not protected; fall through to the classification below
      ;;
    *)
      exit 1
      ;;
  esac
  case "$path" in
    decisions/*.yaml|decisions/*.md)
      decision_touched=1
      decision_files+=("$path")
      ;;
    tests/fixtures/*.sh)
      fixture_touched=1
      fixture_files+=("$path")
      ;;
    scripts/pre-commit/*|ROADMAP.md)
      # Process and roadmap files do not require a co-decision. The
      # explicit-deferral decision that used to be named here was a
      # work record and the census removed it; naming a file that is
      # not in the tree is a rule that can never fire.
      ;;
    *)
      # Anything else (tests/digest_vectors.ml, docs, scripts/*,
      # .gitignore, .envrc, ...) is treated as non-kernel and does
      # not require a co-decision.
      ;;
  esac
done

# If no kernel/protected file was touched, the rule does not apply.
if [ "$kernel_touched" -eq 0 ]; then
  exit 0
fi

# Otherwise, at least one decision OR one fixture MUST also be
# touched. This is a permissive co-commit check; it does not
# verify that the decision references the kernel change.
if [ "$decision_touched" -eq 1 ] || [ "$fixture_touched" -eq 1 ]; then
  exit 0
fi

# Rule violated. Surface a clear diagnostic listing what was touched.
echo "pre-commit(decision-fixture-co-commit): kernel change without decision or fixture" >&2
echo "" >&2
echo "  Touched kernel/protected files:" >&2
for f in "${kernel_files[@]}"; do
  echo "    - $f" >&2
done
echo "" >&2
echo "  A commit that touches a protected path (see" >&2
echo "  scripts/protected-paths.txt) MUST also touch at least one of:" >&2
echo "    - decisions/*.yaml or decisions/*.md  (decision)" >&2
echo "    - tests/fixtures/*.sh                 (fixture)" >&2
echo "" >&2
echo "  See ROADMAP.md §P1 (Decisions before kernel changes) and §P2" >&2
echo "  (Decisions paired with fixtures) for the rationale." >&2
echo "" >&2
echo "  If this commit IS a deferral (e.g., bumping a decision's" >&2
echo "  revision without implementing), add a decisions/*.md or .yaml" >&2
echo "  that documents the deferral (see decisions/yaml-block-scalars-" >&2
echo "  impl-pending.md for an example)." >&2

exit 1
