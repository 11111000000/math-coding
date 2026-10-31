#!/usr/bin/env bash
# tests/fixtures/aggregator-matches-parent.sh
#
# Verifier for decisions/obligation-count-reconcile.yaml
# (`aggregator-7-of-7`).
#
# WHAT IT PROVES. decisions/obligations.yaml is the aggregator that
# lets a reader see the bootstrap policy's obligation set without
# parsing the parent. It must therefore list EXACTLY the obligation
# ids that decisions/decision.yaml carries, in the same order, and it
# must name the parent it aggregates. The check reads both files and
# compares the two lists.
#
# WHY A FIXTURE AND NOT A `shell-grep`. The revision-2 check was
#
#     shell-grep decisions/obligations.yaml revision: 2
#
# which asks whether the aggregator's TEXT still contains a revision
# string. That is a fact about a string, not about the two lists
# agreeing, and the claim it was attached to was about the agreement
# ("lists exactly the seven obligations of decisions/decision.yaml@2
# with identical ids, in the same order"). The claim was also stale:
# the parent is no longer at revision 2.
#
# A fixed-string search cannot compare two files. A program can, and
# the program is this one.
#
# WHAT IT DOES NOT CHECK. The aggregator records the parent revision
# it was reconciled against; this fixture does not require that
# pointer to be the parent's CURRENT revision - a revision pointer is
# a record of when the two were reconciled, and the parent's own
# revision moves for reasons that have nothing to do with its
# obligation set. What has to hold, and is what this fixture checks,
# is that the obligation SETS agree.
#
# THE NEGATIVE CONTROL. A synthetic parent and aggregator whose
# lists differ - one id missing, one id extra, one id out of order -
# must be reported as disagreeing. A check that cannot fail is not a
# check.
#
# Exit codes, following the house convention:
#   0  measured, the two lists agree
#   1  measured, they do not
#   3  nothing was measured - unknown, not pass

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok() { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

parent="${1:-decisions/decision.yaml}"
aggregator="${2:-decisions/obligations.yaml}"

# --- the extraction ------------------------------------------------------
#
# The ids of one file's `obligations:` block, in order. The top-level
# key is tracked so that the `outcomes:`, `assumptions:` and
# `relations:` blocks - which have `id:` items of their own - are not
# mistaken for obligations.
ids_of() {
  awk '
    /^[A-Za-z_][A-Za-z0-9_.-]*:/ {
      key = $0
      sub(/:.*$/, "", key)
    }
    key == "obligations" && /^[[:space:]]*-[[:space:]]*id:[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
    }
  ' "$1"
}

# The id a file declares. The aggregator names the parent it
# aggregates under a `decision:` block; the parent itself declares
# its id at the top level. Both forms are read.
parent_id_of() {
  awk '
    /^decision:/ { inblock = 1; next }
    inblock && /^[[:space:]]+id:[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]+id:[[:space:]]*/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
    inblock && /^[^[:space:]]/ { inblock = 0 }
    /^id:[[:space:]]*/ {
      line = $0
      sub(/^id:[[:space:]]*/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "$1"
}

compare() {
  local parent_file="$1" aggregator_file="$2"
  local label="$3"
  local p_ids a_ids p_id a_id missing extra
  local problems=0

  p_ids="$(ids_of "$parent_file")"
  a_ids="$(ids_of "$aggregator_file")"
  p_id="$(parent_id_of "$parent_file")"
  a_id="$(parent_id_of "$aggregator_file")"

  if [ -z "$p_ids" ]; then
    bad "$label: the parent $parent_file declares no obligation id - nothing to compare"
    return 1
  fi
  if [ -z "$a_ids" ]; then
    bad "$label: the aggregator $aggregator_file declares no obligation id - nothing to compare"
    return 1
  fi

  # the parent the aggregator names
  if [ -n "$a_id" ] && [ "$a_id" != "$p_id" ]; then
    bad "$label: the aggregator names parent '$a_id', the file it aggregates is '$p_id'"
    problems=$((problems + 1))
  else
    ok "$label: the aggregator names its parent ($a_id)"
  fi

  # every id of the parent is in the aggregator
  missing=""
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    printf '%s\n' "$a_ids" | grep -qxF "$id" || missing="$missing $id"
  done <<<"$p_ids"
  if [ -n "$missing" ]; then
    bad "$label: the aggregator is missing the parent id(s):$missing"
    problems=$((problems + 1))
  else
    ok "$label: every parent obligation id is in the aggregator ($(printf '%s\n' "$p_ids" | grep -c .) ids)"
  fi

  # the aggregator declares no id the parent does not
  extra=""
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    printf '%s\n' "$p_ids" | grep -qxF "$id" || extra="$extra $id"
  done <<<"$a_ids"
  if [ -n "$extra" ]; then
    bad "$label: the aggregator declares id(s) the parent does not carry:$extra"
    problems=$((problems + 1))
  else
    ok "$label: the aggregator declares no id the parent does not carry"
  fi

  # the same order
  if [ "$p_ids" = "$a_ids" ]; then
    ok "$label: the two lists are in the same order"
  else
    bad "$label: the two lists are in a different order"
    problems=$((problems + 1))
  fi

  [ "$problems" -eq 0 ]
}

# --- 1. measure ----------------------------------------------------------
if [ ! -f "$parent" ] || [ ! -f "$aggregator" ]; then
  ok "no parent or no aggregator to compare: nothing was measured, and a measurement of nothing is not a measurement"
  echo
  echo "aggregator-matches-parent: SKIPPED (nothing was measured - unknown, not pass)"
  exit 3
fi

compare "$parent" "$aggregator" "the live corpus"

# --- 2. the check must be able to fail ------------------------------------
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work"
cat >"$work/parent.yaml" <<'YAML'
---
schema: math-coding/3.3
id: bootstrap-v3
revision: 3
state: active
obligations:
  - id: preserve-v2
    claim: |
      one
  - id: conformance-coverage
    claim: |
      two
YAML
cat >"$work/aggregator.yaml" <<'YAML'
---
schema: math-coding/obligations-3.0-alpha
decision:
  id: bootstrap-v3
  revision: 3
obligations:
  - id: conformance-coverage
    kind: invariant
    statement: two
  - id: preserve-v2
    kind: invariant
    statement: one
YAML
# The synthetic corpus is EXPECTED to be reported as disagreeing, so
# the failures it prints are the control working, not the control
# failing. The verdict flag is restored around it.
fail_before="$fail"
if compare "$work/parent.yaml" "$work/aggregator.yaml" "the synthetic corpus"; then
  fail="$fail_before"
  bad "negative control: the synthetic corpus was reported as agreeing - the check cannot fail, so its green means nothing"
else
  fail="$fail_before"
  ok "negative control: the synthetic corpus is reported as disagreeing (the same ids in a different order) - the check can go red"
fi

# --- 3. verdict ----------------------------------------------------------
echo
if [ "$fail" -ne 0 ]; then
  echo "aggregator-matches-parent: FAIL"
  exit 1
fi
echo "aggregator-matches-parent: PASS"
exit 0
