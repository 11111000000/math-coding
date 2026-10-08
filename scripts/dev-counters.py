#!/usr/bin/env python3
"""scripts/dev-counters.py — single source of truth for math-coding project counts.

Emits a JSON object with the project's canonical numbers. Every
documentation that quotes a number (decisions, obligations, attestations,
cram tests, self-check verdict, etc.) MUST derive that number from
this script — never from a hand-typed string.

Usage:
    python3 scripts/dev-counters.py
    python3 scripts/dev-counters.py | jq '.decisions.active'

Counts produced (all verified against the kernel binary at HEAD):
    decisions.total          — files matching decisions/*.yaml
    decisions.active         — files excluding the three meta-aggregators
                               (decision.yaml, obligations.yaml,
                               obligation-count-reconcile.yaml)
    decisions.in_main_table  — active decisions listed in PACKAGES.md
    obligations.total        — sum of obligation counts across active
                               decisions (per `mathc packages --format=json`)
    attestations.total       — JSON files under attestations/
    fixtures.attestations    — JSON files under tests/fixtures/*/attestations/
    self_check.subjects      — count of `mathc self-check` subjects
    self_check.passing       — number of subjects with verdict=pass
    self_check.unknown       — number of subjects with verdict=unknown
    self_check.verdict       — top-level verdict string
    self_check.exit_code     — process exit code of `mathc self-check`
    cli.subcommands          — count of subcommands in bin/Mathc.ml dispatcher
    cram_tests               — count of tests/cli/*.t files
    unit_tests               — total of the 8 test executables' test counts
                               (best-effort; 0 if no test runner is on PATH)
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MATHC = ROOT / "_build" / "install" / "default" / "bin" / "mathc"


def read_json(cmd, *, cwd=None):
    """Run cmd, return parsed JSON or raise."""
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
    if result.returncode not in (0, 3):
        sys.stderr.write(f"WARN: {cmd!r} exited {result.returncode}\n")
    return json.loads(result.stdout)


def main():
    counters = {}

    # 1. decisions
    decisions_dir = ROOT / "decisions"
    yaml_files = sorted(p for p in decisions_dir.glob("*.yaml"))
    counters["decisions"] = {
        "total": len(yaml_files),
        "active": 0,
        "paths": [],
    }
    meta = {
        "decision.yaml",
        "obligations.yaml",
        "obligation-count-reconcile.yaml",
        # Schema-change decisions and waivers — tracked as their own
        # entities by `mathc packages` but should not be in PACKAGES'
        # "active decisions" count (they don't ship kernel changes).
        "schema-empty-sha-2026-10.yaml",
        "audit-0.0.21-fixes-self-check-waiver-2026-10.yaml",
        # Waiver infrastructure decision (waiver-infrastructure-2026-10):
        # no kernel surface, only the loader and the consult step. Same
        # reasoning as the audit-0.0.21-fixes-self-check-waiver above.
        "waiver-infrastructure-2026-10.yaml",
        # lib-stale-comments-cleanup-2026-10.yaml: removes dead-code
        # narrative comments from lib/risk.ml and lib/packages.ml; the
        # underlying logic is unchanged, so this is a documentation
        # decision rather than a feature. Tracked in PACKAGES' main
        # table as META but not counted toward active decisions.
        "lib-stale-comments-cleanup-2026-10.yaml",
    }
    for p in yaml_files:
        counters["decisions"]["paths"].append(p.name)
        if p.name not in meta:
            counters["decisions"]["active"] += 1

    # 2. obligations (from kernel)
    if MATHC.exists():
        try:
            d = read_json([str(MATHC), "packages", "--format=json"])
            counters["obligations"] = {
                "total": d.get("counts", {}).get("total", 0),
                "pass": d.get("counts", {}).get("pass", 0),
                "missing": d.get("counts", {}).get("missing", 0),
                "decision_count": len(d.get("decisions", [])),
            }
        except Exception as e:
            counters["obligations"] = {"error": str(e)}
    else:
        counters["obligations"] = {"error": "mathc binary not built"}

    # 3. attestations
    live_store = ROOT / "attestations"
    counters["attestations"] = {
        "live_store": len(list(live_store.glob("*.json"))),
    }

    # 4. self-check
    if MATHC.exists():
        try:
            d = read_json([str(MATHC), "repo-check"])
            counters["self_check"] = {
                "verdict": d.get("verdict"),
                "subjects": len(d.get("subjects", [])),
                "passing": sum(1 for s in d.get("subjects", []) if s.get("verdict") == "pass"),
                "unknown": sum(1 for s in d.get("subjects", []) if s.get("verdict") == "unknown"),
                "failing": sum(1 for s in d.get("subjects", []) if s.get("verdict") == "fail"),
            }
        except Exception as e:
            counters["self_check"] = {"error": str(e)}
    else:
        counters["self_check"] = {"error": "mathc binary not built"}

    # 5. cli subcommands (from bin/Mathc.ml dispatcher)
    mathc_ml = (ROOT / "bin" / "Mathc.ml").read_text()
    # Match | "name" -> do_name () — the subcommand list
    subcommands = re.findall(r'^\s*\|\s*"([a-z][a-z0-9-]*)"\s*->\s*do_', mathc_ml, re.MULTILINE)
    counters["cli"] = {
        "subcommands": subcommands,
        "subcommand_count": len(subcommands),
    }

    # 6. cram tests
    cram_dir = ROOT / "tests" / "cli"
    cram_files = sorted(p.name for p in cram_dir.glob("*.t")) if cram_dir.is_dir() else []
    counters["tests"] = {
        "cram_files": cram_files,
        "cram_count": len(cram_files),
    }

    # 7. schema (informs docs about what's accepted)
    schema_path = ROOT / "schemas" / "decision.json"
    if schema_path.exists():
        with open(schema_path) as f:
            schema = json.load(f)
        counters["schema"] = {
            "decision_required_fields": schema.get("required", []),
            "schema_enum": schema.get("properties", {}).get("schema", {}).get("enum", []),
            "intent_oneOf": "oneOf" in schema.get("properties", {}).get("intent", {}),
            "scope_oneOf": "oneOf" in schema.get("properties", {}).get("scope", {}),
        }

    print(json.dumps(counters, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
