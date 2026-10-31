#!/usr/bin/env bash
# tests/fixtures/verifier-schemes-are-canonical.sh
#
# The instrument for decisions/corpus-tranche-broken-schemes-2026-11.
#
# WHAT IT PROVES, in three parts.
#
#   1. THE LIST IS HONEST. Every scheme the kernel CLAIMS is
#      canonical really is canonical: the list is read out of the
#      kernel's own diagnostic definition, and a synthetic decision
#      that uses each of those schemes must validate without one
#      MC-VERIFIER-SCHEME-UNKNOWN warning. A list that names a
#      scheme the kernel does not know is a list that lies, and it
#      lies in the direction that matters: it tells an author that a
#      verifier is fine, and the kernel then cannot run it.
#
#   2. THE CORPUS IS CLEAN. No decision in `decisions/` names a
#      scheme outside the canonical list. The question is asked of
#      the KERNEL - the same `mathc validate` an author runs - and
#      not re-implemented here: a census that classifies differently
#      from the thing it censuses measures the wrong thing.
#
#   3. THE CHECK CAN GO RED. A synthetic decision that uses a scheme
#      the kernel does not know MUST be reported. A check that cannot
#      fail is not a check, and this one is the answer to the
#      question "what happens when the corpus regrows a broken
#      verifier?" - the answer has to be a red line, not a shrug.
#
# WHY THE CORPUS SCAN IS A FIXTURE AND NOT A LINT. The corpus-wide
# ratchet against a scheme outside the canonical list belongs to the
# tranche that owns the lints (docs/plans/redundancy-and-portability
# -2026-11.md §4, T0.3). This fixture is the tranche's own
# instrument: it exists to make the promise in this tranche's
# commitment checkable, and it asks the kernel the question rather
# than keeping a copy of the kernel's answers.
#
# Exit codes, following the house convention:
#   0  measured, every claim held
#   1  measured, a claim did not hold
#   3  nothing was measured - unknown, not pass

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok() { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

bin=""
for c in _build/default/bin/mathc.exe _build/install/default/bin/mathc; do
  if [ -x "$c" ]; then bin="$PWD/$c"; break; fi
done
if [ -z "$bin" ]; then
  for c in mathc mathc.exe; do
    if command -v "$c" >/dev/null 2>&1; then bin="$(command -v "$c")"; break; fi
  done
fi
if [ -z "$bin" ]; then
  bad "no mathc binary found (looked in _build/default/bin/, _build/install/default/bin/ and on PATH)"
  echo
  echo "verifier-schemes-are-canonical: FAIL"
  exit 1
fi

work="tests/fixtures/scheme-probe-tmp"
rm -rf "$work"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT

# A synthetic decision carrying one verifier. The scheme is the first
# whitespace-delimited token; the rest is whatever the scheme wants.
mk_decision() {
  local path="$1" scheme="$2"
  cat >"$path" <<YAML
---
schema: math-coding/3.3
id: synthetic-scheme-probe
revision: 1
state: active
mode: light
axiom_link:
  - A0
intent: |
  A synthetic decision that carries one verifier scheme, so that the
  kernel can be asked about that scheme and nothing else.
commitment: |
  The synthetic decision exists so that the check can ask the kernel
  a question about one scheme.
scope:
  paths:
    - "decisions/decision.yaml"
outcomes:
  - id: probe
    statement: |
      The kernel was asked about exactly one scheme.
obligations:
  - id: probe
    claim: |
      A synthetic decision that uses one verifier scheme.
    acceptance:
      all:
        - verifier: $scheme
YAML
}

scheme_warnings() {
  "$bin" validate "$1" 2>&1 | grep -c 'MC-VERIFIER-SCHEME-UNKNOWN' || true
}

# --- 1. the list is honest ------------------------------------------------
#
# The list is read out of the kernel's own diagnostic definition, so
# this fixture cannot hold a stale copy of it.
definition="$("$bin" explain-diagnostic MC-VERIFIER-SCHEME-UNKNOWN 2>/dev/null | jq -r '.definition' 2>/dev/null)"
if [ -z "$definition" ]; then
  bad "the kernel cannot explain MC-VERIFIER-SCHEME-UNKNOWN - nothing was measured"
  echo
  echo "verifier-schemes-are-canonical: FAIL"
  exit 3
fi

flat="$(printf '%s' "$definition" | tr '\n' ' ')"
exact="$(printf '%s' "$flat" | sed -e 's/.*Canonical exact schemes: //' -e 's/ Canonical prefixes.*//')"
prefixes="$(printf '%s' "$flat" | sed -e 's/.*any suffix): //' -e 's/ The verifier string is.*//')"
if [ -z "$exact" ] || [ -z "$prefixes" ]; then
  bad "the kernel's diagnostic does not state the canonical list - the list cannot be checked"
  echo
  echo "verifier-schemes-are-canonical: FAIL"
  exit 3
fi

checked=0
liars=0
IFS=$'\n'
for entry in $(printf '%s,%s' "$exact" "$prefixes" | tr -d '`' | tr ',' '\n' | sed -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' -e 's/\.$//'); do
  [ -n "$entry" ] || continue
  probe="$entry"
  mk_decision "$work/probe.yaml" "$probe argument"
  n="$(scheme_warnings "$work/probe.yaml")"
  checked=$((checked + 1))
  if [ "$n" -ne 0 ]; then
    bad "the kernel calls '$probe' canonical and then warns about it - the list lies"
    liars=$((liars + 1))
  fi
done
if [ "$liars" -eq 0 ] && [ "$checked" -gt 0 ]; then
  ok "every one of the $checked schemes the kernel calls canonical is canonical"
else
  bad "$liars of $checked schemes the kernel calls canonical are not"
fi

# --- 2. the corpus is clean ----------------------------------------------
decisions_dir="${MATH_CODING_DECISIONS_DIR:-decisions}"
if [ ! -d "$decisions_dir" ]; then
  ok "no corpus at $decisions_dir: nothing was measured, and a measurement of nothing is not a measurement"
  echo
  echo "verifier-schemes-are-canonical: SKIPPED (nothing was measured - unknown, not pass)"
  exit 3
fi

dirty=0
counted=0
while IFS= read -r file; do
  counted=$((counted + 1))
  out="$("$bin" validate "$file" 2>&1 | grep 'MC-VERIFIER-SCHEME-UNKNOWN' || true)"
  if [ -n "$out" ]; then
    bad "$file: $out"
    dirty=$((dirty + 1))
  fi
done < <(find "$decisions_dir" -name '*.yaml' -o -name '*.yml' 2>/dev/null | sort)
if [ "$dirty" -eq 0 ]; then
  ok "no decision in $decisions_dir names a scheme outside the canonical list ($counted files asked, by the kernel)"
else
  bad "$dirty decision(s) in $decisions_dir name a scheme outside the canonical list"
fi

# --- 3. the check can go red ---------------------------------------------
mk_decision "$work/rogue.yaml" "mc-not-a-scheme argument"
rogue="$(scheme_warnings "$work/rogue.yaml")"
if [ "$rogue" -ge 1 ]; then
  ok "negative control: a synthetic decision with a scheme the kernel does not know is reported ($rogue warning(s)) - the check can go red"
else
  bad "negative control: a synthetic decision with a scheme the kernel does not know is NOT reported - the check cannot fail, so its green means nothing"
fi

# --- 4. verdict ----------------------------------------------------------
echo
if [ "$fail" -ne 0 ]; then
  echo "verifier-schemes-are-canonical: FAIL"
  exit 1
fi
echo "verifier-schemes-are-canonical: PASS"
exit 0
