#!/bin/sh
# Preregistered utility-pilot kit: validate, summarize, self-test, and check prereg.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$script_dir/.." && pwd)
protocol="$script_dir/BENCHMARK-PROTOCOL.md"
ledger="$script_dir/task-ledger.py"
dry="$script_dir/dry-run.jsonl"

usage() {
  cat <<'EOF'
usage:
  pilot-kit.sh prereq
  pilot-kit.sh validate LEDGER.jsonl
  pilot-kit.sh summary LEDGER.jsonl
  pilot-kit.sh selftest
EOF
}

need_file() {
  [ -s "$1" ] || { printf 'pilot-kit: missing or empty file: %s\n' "$1" >&2; exit 2; }
}

prereq() {
  need_file "$protocol"
  need_file "$ledger"
  need_file "$dry"
  grep -q 'spec_schema_version = 7' "$protocol"
  grep -q 'evidence_schema_version = 7' "$protocol"
  grep -q '^## 1\. Проверяемая гипотеза$' "$protocol"
  grep -q '^## 2\. Экспериментальные руки$' "$protocol"
  grep -q '^## 3\. Предварительная регистрация$' "$protocol"
  grep -q '^## 6\. Критерий принятия метода$' "$protocol"
  grep -q '^## 12\. Решение по результатам$' "$protocol"
  grep -q 'не менее 30% снижения' "$protocol"
  grep -q 'снижении основного показателя не менее чем на' "$protocol"
  grep -q 'mathc_build' "$protocol"
  printf '%s\n' '{"preregistered":true,"spec_schema_version":7,"evidence_schema_version":7,"arms":["baseline","checklist","protocol"],"weights":{"utility_measurement":2,"cost":1,"risk_coverage":2,"adoption":1},"status":"ready-for-owner-run"}'
}

validate() {
  [ "$#" -eq 1 ] || { usage >&2; exit 2; }
  python3 "$ledger" validate "$1"
}

summary() {
  [ "$#" -eq 1 ] || { usage >&2; exit 2; }
  python3 "$ledger" summary "$1"
}

selftest() {
  need_file "$dry"
  work=$(mktemp -d "${TMPDIR:-/tmp}/mathc-pilot-kit.XXXXXX")
  trap 'rm -rf "$work"' EXIT HUP INT TERM

  validate "$dry" | grep -q 'valid: 4 run(s)'
  summary "$dry" | grep -q '"runs": 4'

  python3 - "$dry" "$work/mixed.jsonl" <<'PY'
import json, sys
lines = [json.loads(x) for x in open(sys.argv[1], encoding="utf-8")]
records = [x for x in lines if x.get("schema_version") == 1 and x.get("comparison_id") == "dry-run-v1"]
assert len(records) >= 3, "dry-run fixture is too small"
records[2]["mathc_build"] = "different-build"
with open(sys.argv[2], "w", encoding="utf-8") as out:
    for record in records[:3]:
        out.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")
PY
  if validate "$work/mixed.jsonl" >/dev/null 2>&1; then
    printf 'pilot-kit: mixed mathc_build was accepted\n' >&2
    exit 1
  fi

  python3 - "$dry" "$work/incomplete.jsonl" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as source:
    record = next(json.loads(x) for x in source)
record["outcome"] = "accepted"
record["accepted_by"] = None
with open(sys.argv[2], "w", encoding="utf-8") as out:
    out.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")
PY
  if validate "$work/incomplete.jsonl" >/dev/null 2>&1; then
    printf 'pilot-kit: acceptance without reviewer was accepted\n' >&2
    exit 1
  fi

  prereq >/dev/null
  printf '%s\n' 'pilot-kit: PASS'
}

case "${1:-}" in
  prereq) shift 0; prereq ;;
  validate) shift; validate "$@" ;;
  summary) shift; summary "$@" ;;
  selftest) selftest ;;
  help|-h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
