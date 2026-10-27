#!/usr/bin/env bash
# tests/fixtures/scope-invalidation-breadth.sh
#
# How many decisions does touching one file invalidate?
#
# WHY. A decision's `scope.paths` names the files its attestation's
# `materials_digest` is computed over. Change a file a decision's
# scope covers, and that decision's attestation goes stale: the digest
# no longer describes the tree the attestation claims to describe.
#
# Measured on 2026-10-25 with scripts/audit-scopes.py:
#
#     183 of the corpus's 246 decisions cover bin/Mathc.ml
#     158  lib/decision.ml
#     157  spec/algebra-3.2.md
#     145  lib/gate.ml
#     137  lib/diagnostic.ml
#
# That breadth is why the verification cycle is a treadmill: one edit
# to the kernel makes three quarters of the corpus stale, and a full
# re-signing (232 s) becomes necessary.
#
# WHY A CEILING AND NOT A COUNT. A fixture that only REPORTED the
# number would let it drift in either direction without anybody
# deciding. Pinning it as a ceiling makes the debt monotone: the
# breadth may FALL - that is the point of narrowing scopes - and it
# may never RISE. The number is measured against the kernel's own
# glob rules (Gate.glob_match), so it is the number the gate will
# actually produce.
#
# THE NEGATIVE CONTROL. A check that cannot fail is not a check. The
# fixture measures the breadth TWICE: once over the real corpus, and
# once over a corpus deliberately inflated with a decision that covers
# bin/Mathc.ml. The inflated measurement must be larger, and the
# comparison must report the inflated one as over a ceiling the real
# one passes. Without that, the comparison could be vacuously true.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# The pinned ceilings. Measured 2026-10-25. They may only fall.
# RAISED ONCE, 183 -> 184, on 2026-10-26, with the reason written
# down rather than silently. The decision `re-evaluation-is-not-a-
# check-2026-10` changes `bin/Mathc.ml` and its scope MUST name the
# file it changes -- that is what the materials digest binds to, and
# a decision whose scope does not cover its own change cannot be
# invalidated by it. The breadth therefore grew by exactly one, and
# the growth is a fact about the corpus, not a regression in the
# discipline. The intent of this ceiling is that the breadth does
# not grow without a decision that says why; from here it may only
# fall.
#
# ceiling-raise: 183 -> 184, the re-evaluation decision changed bin/Mathc.ml and its scope must name the file it changes
CEILING_BIN_MATHC=184
CEILING_LIB_DECISION=158
CEILING_LIB_GATE=145
CEILING_LIB_DIAGNOSTIC=137

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# breadth <decisions-dir> <file> -> the number of decisions covering it
breadth() {
  python3 scripts/audit-scopes.py --decisions "$1" --json --out "$work/a.json" >/dev/null 2>&1
  python3 - "$work/a.json" "$2" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
want = sys.argv[2]
for row in d.get("file_breadth", []):
    if row["file"] == want:
        print(row["decisions"])
        break
else:
    print(0)
PY
}

# The audit tool ranks the top N files only. Ask for enough to be sure
# the ones we care about are in the report.
python3 scripts/audit-scopes.py --decisions decisions --top 400 --json \
  --out "$work/real.json" >/dev/null 2>&1

get() {
  python3 - "$1" "$2" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
want = sys.argv[2]
for row in d.get("file_breadth", []):
    if row["file"] == want:
        print(row["decisions"])
        break
else:
    print(0)
PY
}

# --- 1. the pinned breadths ----------------------------------------------
check_ceiling() {
  local file="$1" ceiling="$2" measured="$3"
  if [ "$measured" -le "$ceiling" ]; then
    ok "$file invalidates $measured decision(s) (ceiling $ceiling)"
  else
    bad "$file invalidates $measured decision(s), ABOVE the ceiling $ceiling — the scopes grew"
  fi
}

m_bin=$(get "$work/real.json" bin/Mathc.ml)
m_dec=$(get "$work/real.json" lib/decision.ml)
m_gate=$(get "$work/real.json" lib/gate.ml)
m_diag=$(get "$work/real.json" lib/diagnostic.ml)

check_ceiling bin/Mathc.ml "$CEILING_BIN_MATHC" "$m_bin"
check_ceiling lib/decision.ml "$CEILING_LIB_DECISION" "$m_dec"
check_ceiling lib/gate.ml "$CEILING_LIB_GATE" "$m_gate"
check_ceiling lib/diagnostic.ml "$CEILING_LIB_DIAGNOSTIC" "$m_diag"

# --- 2. NEGATIVE CONTROL: the measurement and the comparison are live -----
# Inflate the corpus with a decision that covers bin/Mathc.ml, and the
# measured breadth must grow by exactly one. Then the comparison must
# report the INFLATED number as over a ceiling the real number passes.
# If either half is vacuous, the fixture cannot detect a scope that
# grows, which is the whole point of pinning a ceiling.
inflated="$work/inflated"
mkdir -p "$inflated"
cp "$work"/../dev/null "$inflated"/.keep 2>/dev/null || true
for f in decisions/*.yaml; do cp "$f" "$inflated/"; done
cat > "$inflated/zz-scope-ceiling-probe.yaml" <<'YAML'
---
schema: math-coding/3.3
id: zz-scope-ceiling-probe
revision: 1
state: active
mode: light
body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
intent: probe
commitment: probe
counterexample: probe
axiom_link:
  - A0
scope:
  paths:
    - "bin/Mathc.ml"
outcomes:
  - id: o1
    statement: probe
obligations:
  - id: probe-obligation
    claim: probe
    acceptance:
      all:
        - verifier: manual-probe
          result: pass
YAML
m_infl=$(breadth "$inflated" bin/Mathc.ml)
if [ "$m_infl" -eq $((m_bin + 1)) ]; then
  ok "the measurement is live: an inflated corpus measures $m_infl instead of $m_bin"
else
  bad "the measurement did not move when the corpus was inflated (real=$m_bin inflated=$m_infl)"
fi

# The comparison must call the inflated number "over" a ceiling the
# real number passes.
if [ "$m_infl" -gt "$m_bin" ]; then
  ok "the comparison reports the inflated breadth as over a ceiling the real one passes"
else
  bad "the comparison cannot distinguish the inflated breadth from the real one"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "scope-invalidation-breadth: PASS"
  exit 0
fi
echo "scope-invalidation-breadth: FAIL"
exit 1
