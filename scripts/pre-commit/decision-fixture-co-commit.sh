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
#     - bootstrap/*.yaml    (a decision recorded)
#     - bootstrap/*.md      (a decision recorded, markdown form)
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

# Identify staged files. pre-commit-hooks.nix passes the list of
# paths on stdin (one per line) when pass_filenames is true.
declare -a staged
while IFS= read -r path; do
  staged+=("$path")
done

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
    lib/*.ml|lib/**/*.ml|bin/Mathc.ml|spec/*.md|spec/**/*.md|schemas/*.json|schemas/**/*.json)
      kernel_touched=1
      kernel_files+=("$path")
      ;;
    bootstrap/*.yaml|bootstrap/*.md)
      decision_touched=1
      decision_files+=("$path")
      ;;
    tests/fixtures/*.sh)
      fixture_touched=1
      fixture_files+=("$path")
      ;;
    scripts/pre-commit/*|ROADMAP.md|bootstrap/yaml-block-scalars-impl-pending.yaml)
      # Process / roadmap / explicit-deferral files do not require
      # a co-decision.
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
echo "    - bootstrap/*.yaml or bootstrap/*.md  (decision)" >&2
echo "    - tests/fixtures/*.sh                 (fixture)" >&2
echo "" >&2
echo "  See ROADMAP.md §P1 (Decisions before kernel changes) and §P2" >&2
echo "  (Decisions paired with fixtures) for the rationale." >&2
echo "" >&2
echo "  If this commit IS a deferral (e.g., bumping a decision's" >&2
echo "  revision without implementing), add a bootstrap/*.md or .yaml" >&2
echo "  that documents the deferral (see bootstrap/yaml-block-scalars-" >&2
echo "  impl-pending.md for an example)." >&2

exit 1