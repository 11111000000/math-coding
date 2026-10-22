#!/usr/bin/env bash
# tests/fixtures/verdict-vocabulary-spec-coherence.sh
#
# Verifier for decisions/verdict-vocabulary-and-waiver-expiry-2026-10.yaml
# obligations `spec-enumerates-the-four-verdicts`,
# `spec-states-the-verdict-to-exit-table` and
# `spec-states-the-waiver-validity-interval`.
#
# The defect class: spec/semantics.md is normative, and it used to
# enumerate a three-value verdict vocabulary (`pass | fail |
# unknown`) while the kernel shipped four
# (`Pass | Open_with_waiver | Block | Unknown`,
# lib/gate.ml:41). Nothing forced the two to agree — a stale
# enumeration is just prose. This fixture derives the vocabulary
# from the CODE and asserts the SPEC carries it, so the next
# divergence is a red test rather than an audit finding.
#
# Three directions are checked, all of which have been observed:
#   1. a verdict the kernel can produce but the spec never names
#      (`open-with-waiver`, missing before 2026-10-22);
#   2. an enumeration the spec still carries but the kernel no
#      longer implements (the three-value self-check vocabulary);
#   3. an exit code the spec promises but the CLI does not emit.
#
# It is a text fixture on purpose: it compares two documents, so
# there is nothing to execute.

set -uo pipefail
cd "$(dirname "$0")/../.."

spec=spec/semantics.md
gate=lib/gate.ml
fail=0

note() { echo "ok: $1"; }
bad() {
  echo "FAIL: $1"
  fail=1
}

# --- 1. the kernel's verdict vocabulary, derived from the code ---
# lib/gate.ml::verdict_to_string renders every variant; those
# renderings ARE the reportable vocabulary.
kernel_verdicts=$(sed -n '/^let.*verdict_to_string = function/,/^$/p' "$gate" \
  | sed -n 's/.*-> "\([a-z-]*\)".*/\1/p' | sort -u)
kernel_count=$(printf '%s\n' "$kernel_verdicts" | grep -c .)
if [ "$kernel_count" = "4" ]; then
  note "kernel declares 4 verdict strings"
else
  bad "expected 4 verdict strings in $gate, found $kernel_count: $kernel_verdicts"
fi

for v in $kernel_verdicts; do
  if grep -qE "^\| \`$v\`" "$spec"; then
    note "spec documents verdict \`$v\` in a table row"
  else
    bad "spec/semantics.md has no table row for verdict \`$v\` (kernel emits it)"
  fi
done

# --- 2. no stale three-value enumeration anywhere in the spec ---
# The pre-fix text was:  `verdict` (`pass` | `fail` | `unknown`).
if grep -qF '`pass` | `fail` | `unknown`' "$spec"; then
  bad "spec/semantics.md still enumerates the three-value verdict vocabulary \`pass\` | \`fail\` | \`unknown\`"
else
  note "spec carries no three-value verdict enumeration"
fi

# --- 3. the self-check row names all four values ---
selfcheck_row=$(sed -n '/^### `self-check`/,/^### /p' "$spec")
for v in $kernel_verdicts; do
  case "$v" in
  block) needle='fail' ;;
  *) needle=$v ;;
  esac
  if printf '%s' "$selfcheck_row" | grep -qF "$needle"; then
    note "self-check row names \`$needle\`"
  else
    bad "the \`self-check\` CLI row does not name \`$needle\`"
  fi
done

# --- 4. 14c made observable: the waivers[] field set is specified ---
for field in id issuer issued_at expires_at scope covers; do
  if printf '%s' "$selfcheck_row" | grep -qE "\`$field(\[\])?\`"; then
    note "self-check row documents waivers[] field \`$field\`"
  else
    bad "the \`self-check\` CLI row does not document the waivers[] field \`$field\`"
  fi
done

# --- 5. the verdict-to-exit table agrees with bin/Mathc.ml ---
# The pairs below are constitution.md Invariant 14b's codes. They
# are pinned in TWO places on purpose: the spec table must state
# them, and bin/Mathc.ml must still ship them. Change either one
# without the other and this fixture fails — which is the whole
# point of a drift fixture.
cli=bin/Mathc.ml
for arm in "Gate.Pass | Gate.Open_with_waiver -> 0" "Gate.Block -> 1" "Gate.Unknown -> 3"; do
  if grep -qF "| $arm" "$cli"; then
    note "bin/Mathc.ml ships the arm \`$arm\`"
  else
    bad "bin/Mathc.ml no longer ships the exit arm \`$arm\`"
  fi
done

exit_rows=$(sed -n '/^### Verdict to exit code/,/^Exit `2`/p' "$spec")
if [ -z "$exit_rows" ]; then
  bad "spec/semantics.md has no '### Verdict to exit code' table"
fi
while read -r variant code; do
  [ -n "${variant:-}" ] || continue
  if printf '%s' "$exit_rows" | grep -qE "^\| \`$variant\` \| \`$code\` \|"; then
    note "spec exit table states $variant -> $code"
  else
    bad "spec exit table does not state $variant -> $code"
  fi
done <<EOF
Pass 0
Open_with_waiver 0
Block 1
Unknown 3
EOF

# --- 6. the waiver validity interval, spec vs kernel ---
# The kernel predicate must be the half-open interval the spec
# states. `iso_lt now w.expires_at` is the strict upper bound;
# an inclusive arm (`iso_le now w.expires_at`) would contradict
# constitution.md Invariant 14c ("strictly greater than the
# evaluation time").
if grep -qF 'issued_at <= t < w.expires_at' "$spec"; then
  note "spec §Waiver Validity states the half-open interval"
else
  bad "spec/semantics.md does not state 'issued_at <= t < w.expires_at'"
fi
if grep -qF 'iso_lt now w.Domain.expires_at' lib/waiver.ml; then
  note "lib/waiver.ml uses the strict expiry bound (Invariant 14c)"
else
  bad "lib/waiver.ml does not use the strict expiry bound 'iso_lt now w.Domain.expires_at'"
fi
if grep -qF 'iso_le now w.Domain.expires_at' lib/waiver.ml; then
  bad "lib/waiver.ml still includes expires_at in the effective interval"
else
  note "lib/waiver.ml no longer includes expires_at in the effective interval"
fi

if [ "$fail" -ne 0 ]; then
  echo "verdict-vocabulary-spec-coherence: FAILED"
  exit 1
fi
echo "verdict-vocabulary-spec-coherence: ok"
exit 0