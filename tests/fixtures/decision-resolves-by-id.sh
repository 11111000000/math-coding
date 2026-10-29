#!/usr/bin/env bash
# tests/fixtures/decision-resolves-by-id.sh
#
# A decision is found by its ID, by scanning the decisions directory.
#
# WHY. The kernel used to resolve a decision by CONCATENATING its id
# with ".yaml". Sixteen decisions in this corpus carry an id that
# differs from their file name - candidate-tree-resolves-to-a-commit
# lives in candidate-tree-resolves-to-a-commit-2026-10.yaml,
# bootstrap-v3 lives in decision.yaml - so for every one of them the
# file was not there, the parse failed, and every one of its
# obligations was reported as FAILED. Measured on 2026-10-25: 69 of
# the 110 obligations the re-signing refused to sign were failing
# for exactly this reason, and nothing said so: the kernel could not
# find the decision it was asked about and reported it as a broken
# check.
#
# THE NEGATIVE CONTROL. A check that cannot fail is not a check. Two
# things must hold, and the second is what makes the first mean
# anything:
#
#   1. a decision whose file name differs from its id is resolved and
#      its obligation is verified;
#   2. a decision whose verifier genuinely FAILS is still reported as
#      a failure and is still left unsigned.
#
# Without (2), (1) would also be satisfied by a kernel that reports
# everything as a pass.

set -uo pipefail
cd "$(dirname "$0")/../.."

BIN="${MATHC_BIN:-}"
if [ -z "$BIN" ]; then
  for c in _build/default/bin/mathc.exe _build/install/default/bin/mathc; do
    [ -x "$c" ] && BIN="$PWD/$c" && break
  done
  command -v mathc >/dev/null 2>&1 && [ -z "$BIN" ] && BIN="$(command -v mathc)"
fi
if [ -z "$BIN" ]; then
  echo "FAIL: no mathc binary found"
  echo "decision-resolves-by-id: FAIL"
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

Z='sha256:0000000000000000000000000000000000000000000000000000000000000000'

# write_decision <id> <file-name> <verifier> <out-file>
# The file name is deliberately NOT "<id>.yaml".
write_decision() {
  local id="$1" verifier="$3" out="$4"
  cat > "$out" <<YAML
---
schema: math-coding/3.3
id: $id
revision: 1
state: active
mode: light
body_sha: "$Z"
yaml_sha: "$Z"
axiom_link:
  - A0
intent: probe
commitment: probe
counterexample: probe
scope:
  paths: []
outcomes:
  - id: o1
    statement: probe
obligations:
  - id: probe-obligation
    claim: probe
    acceptance:
      all:
        - verifier: $verifier
          result: pass
YAML
  "$BIN" rehash --write "$out" >/dev/null 2>&1
}

# The probe decision must live in decisions/ - the kernel enumerates
# the corpus by scanning that directory, and a decision that is not
# there is not in the corpus.
probe_dir="decisions"
# shellcheck disable=SC2329   # invoked indirectly (as a trap handler)
cleanup() {
  rm -f "$probe_dir/zz-resolve-probe-"*.yaml
  rm -rf "$work"
}
trap cleanup EXIT

sign_one() {
  # sign_one <decision-id> -> the result string attest-batch reports
  local id="$1" manifest="$work/m.tsv"
  printf '%s\tprobe-obligation\ttest\tci:probe\tpass\n' "$id" > "$manifest"
  "$BIN" attest-batch --manifest="$manifest" --out="$work/out" \
    --run-per-obligation --dry-run 2>/dev/null \
    | python3 -c '
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        d = json.loads(line)
    except Exception:
        continue
    print(d.get("result", "?"))
    break
'
}

# --- 1. a decision whose file name differs from its id --------------------
# The verifier passes, so the obligation must be VERIFIED - which
# means the kernel must have FOUND the decision.
write_decision "zz-resolve-probe-id" "zz-resolve-probe-file-name.yaml" \
  "file-exists VERSION" "$probe_dir/zz-resolve-probe-file-name.yaml"
res=$(sign_one "zz-resolve-probe-id")
if [ "$res" = "pass" ]; then
  ok "a decision whose file name differs from its id is resolved and verified"
else
  bad "the decision was not resolved (result='${res:-<none>}'); the kernel looked for zz-resolve-probe-id.yaml"
fi

# --- 2. NEGATIVE CONTROL: a real failure is still a failure --------------
# The verifier cannot pass - the file does not exist. The obligation
# must be reported as failed and left unsigned. If this were reported
# as a pass, section 1 would prove nothing.
write_decision "zz-resolve-probe-fail" "zz-resolve-probe-fail-file.yaml" \
  "file-exists definitely-not-a-file-anywhere" \
  "$probe_dir/zz-resolve-probe-fail-file.yaml"
res=$(sign_one "zz-resolve-probe-fail")
if [ "$res" = "fail" ]; then
  ok "a genuinely failing verifier is still reported as a failure"
else
  bad "a genuinely failing verifier was not reported as a failure (result='${res:-<none>}') — the resolution fix may be masking broken checks"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "decision-resolves-by-id: PASS"
  exit 0
fi
echo "decision-resolves-by-id: FAIL"
exit 1
