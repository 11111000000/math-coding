#!/usr/bin/env bash
# tests/fixtures/ci-green-batch1-fixes.sh
#
# Verifier for decisions/ci-green-batch1-2026-10. Asserts that the
# four CI-blocking defects the decision records are actually fixed
# on the branch HEAD.
#
# (1) flake.nix uses string `entry` for the three pre-commit-hooks
#     the project wires in checks.fmt.
# (2) scripts/dev:281 and scripts/agent-debug:53 reference the new
#     filename OCAML_KERNEL_CONVENTIONS.md, not the old
#     OCAML_BEST_PRACTICES.md.
# (3) PACKAGES.md carries the live attestation count as a literal
#     `**N files**` substring, where N matches
#     `git ls-files attestations/ | wc -l`.
# (4) ROADMAP.md carries the same N as a plain `N files` substring.
# (5) lib/import_adr/import_adr.ml::to_decision_yaml emits a
#     `risk:` body section, so scaffold files satisfy
#     tests/process_principles.ml::test_p1's required_body_sections.
#
# The fixture is intentionally side-effect-free: it only reads the
# repo files and asserts string matches. Failure of any assertion
# surfaces immediately so the merge to main is gated on the fix
# landing, not on `dune test` luck.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# --- (1) flake.nix: string entry for 3 hooks -----------------------
if [ ! -f flake.nix ]; then
  bad "flake.nix missing"
else
  for hook in decision-fixture-co-commit shellcheck ocamlformat; do
    section=$(awk -v h="$hook" '
      $0 ~ "^[[:space:]]*"h"[[:space:]]*=[[:space:]]*{" { p=1; next }
      p && /^[[:space:]]*};/ { p=0 }
      p { print }
    ' flake.nix)
    if printf '%s' "$section" | grep -qE "entry[[:space:]]*=[[:space:]]*\\.[[:space:]]*/"; then
      bad "flake.nix[$hook] still uses a Nix-path entry attribute"
    elif printf '%s' "$section" | grep -qE "entry[[:space:]]*=[[:space:]]*\"[^\"]+\""; then
      ok "flake.nix[$hook] entry is a string"
    else
      bad "flake.nix[$hook] has no entry attribute"
    fi
  done
fi

# --- (2) scripts/dev:281 and scripts/agent-debug:53 ----------------
if [ ! -f scripts/dev ]; then
  bad "scripts/dev missing"
elif grep -E '^[^#]*OCAML_BEST_PRACTICES\.md' scripts/dev | grep -q .; then
  bad "scripts/dev still references OCAML_BEST_PRACTICES.md in code (line 281)"
else
  ok "scripts/dev does not reference OCAML_BEST_PRACTICES.md in code"
fi
if ! grep -q "OCAML_KERNEL_CONVENTIONS.md" scripts/dev; then
  bad "scripts/dev does not reference OCAML_KERNEL_CONVENTIONS.md"
else
  ok "scripts/dev references OCAML_KERNEL_CONVENTIONS.md"
fi

if [ ! -f scripts/agent-debug ]; then
  bad "scripts/agent-debug missing"
elif grep -E "OCAML_BEST_PRACTICES\.md" scripts/agent-debug \
    | grep -vE "^[[:space:]]*#" \
    | grep -q .; then
  bad "scripts/agent-debug still uses OCAML_BEST_PRACTICES.md in code (line 53 awk argv)"
else
  ok "scripts/agent-debug awk uses OCAML_KERNEL_CONVENTIONS.md"
fi

# --- (3) PACKAGES.md live attestation count -------------------------
n_att=$(git ls-files attestations/ | wc -l)
if [ ! -f PACKAGES.md ]; then
  bad "PACKAGES.md missing"
elif ! grep -qE "\\*\\*${n_att} files\\*\\*" PACKAGES.md; then
  bad "PACKAGES.md does not contain '**${n_att} files**'"
else
  ok "PACKAGES.md carries '**${n_att} files**'"
fi

# --- (4) ROADMAP.md live attestation count --------------------------
if [ ! -f ROADMAP.md ]; then
  bad "ROADMAP.md missing"
elif ! grep -qE "${n_att} files" ROADMAP.md; then
  bad "ROADMAP.md does not contain '${n_att} files'"
else
  ok "ROADMAP.md carries '${n_att} files'"
fi

# --- (5) lib/import_adr/import_adr.ml template ships risk: ---------
if [ ! -f lib/import_adr/import_adr.ml ]; then
  bad "lib/import_adr/import_adr.ml missing"
else
  # Look for the `risk:` keyword in the to_decision_yaml Printf
  # format string. A bare mention in a comment is not enough; the
  # actual YAML template must contain it.
  if awk '/let to_decision_yaml/,/^let/' lib/import_adr/import_adr.ml \
       | grep -qE 'risk:[[:space:]]*\\?\||risk:[[:space:]]*\\|'; then
    ok "to_decision_yaml template emits risk: body section"
  else
    bad "to_decision_yaml template does NOT emit risk: body section"
  fi
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "ci-green-batch1-fixes: PASS"
  exit 0
fi
echo "ci-green-batch1-fixes: FAIL"
exit 1