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
# Kernel/protected files:
#   lib/**/*.ml
#   bin/Mathc.ml
#   spec/**/*.md
#   schemas/**/*.json
#
# The check is intentionally permissive (does not require that
# the decision explicitly references the touched file). The
# co-commit signal is the human-level invariant: a kernel change
# without an adjacent decision is the deficit we are catching.

set -uo pipefail

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
  case "$path" in
    lib/*.ml|bin/Mathc.ml|spec/*.md|schemas/*.json)
      kernel_touched=1
      kernel_files+=("$path")
      ;;
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
echo "  A commit that touches lib/*.ml, bin/Mathc.ml, spec/*.md, or" >&2
echo "  schemas/*.json MUST also touch at least one of:" >&2
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