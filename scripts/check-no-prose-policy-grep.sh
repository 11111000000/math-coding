#!/usr/bin/env bash
# The applicability rule has one owner.
#
# The corpus verified the applicability rule by the presence of a
# sentence: an obligation whose verifier was
# `grep -q 'Opt-in' adoption/SKILL.md` proved that a phrase was in a
# file, not that the rule the phrase states was the rule the kernel
# enforces. Two such obligations, written on opposite sides of a
# contradiction, are green at the same time — which is how
# decisions/solo-default-on-2026-10.yaml and
# decisions/adopter-path-2026-10.yaml came to attest mutually
# exclusive policies in one CI run.
#
# The needles below are the phrases that state the APPLICABILITY RULE.
# Checking for them in a prose file asserts the rule by phrase, so no
# active decision may do it. The list is explicit and grows by
# decision, not by heuristic: a needle that checks a document's
# content (a notation, a version string, a flag name) is a different
# kind of check and stays legal.
#
# The rule itself is checked for agreement across surfaces by
# scripts/check-applicability-agreement.sh.
#
# Exits 0 on full pass, 1 on any failure.

set -eu

cd "$(git rev-parse --show-toplevel)"

fail=0

needles=(
  "Opt-in"
  "burden of proof sits on the application"
  "Default: apply"
)

for f in decisions/*.yaml; do
  [ -f "$f" ] || continue
  state="$(grep -m1 '^state:' "$f" | awk '{print $2}' || true)"
  [ "$state" = "active" ] || continue
  for needle in "${needles[@]}"; do
    if grep -F -q -- "$needle" "$f" && grep -E "verifier:.*grep" "$f" | grep -F -q -- "$needle"; then
      fail=1
      printf 'FAIL: %s (active) asserts the applicability rule by grepping for the phrase %s\n' \
        "$f" "'$needle'" >&2
      grep -nE "verifier:.*grep.*$(printf '%s' "$needle" | sed 's/[][\.*^$/]/\\&/g')" "$f" >&2 || true
    fi
  done
done

if [ "$fail" = "1" ]; then
  printf '%s\n' \
    "  Supersede the decision that introduced it, and replace the phrase-presence" \
    "  verifier with one that compares two surfaces:" \
    "  scripts/check-applicability-agreement.sh." \
    "  See decisions/skill-single-source-2026-10.yaml." >&2
  exit 1
fi

echo "PASS: no active decision asserts the applicability rule by a phrase in prose"
