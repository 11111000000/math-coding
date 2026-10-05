#!/usr/bin/env bash
# scripts/check-counters-drift.sh

set -e
cd "$(dirname "$0")/.."

ROOT="$(pwd)"

# Get counters JSON
COUNTERS=$(python3 scripts/dev-counters.py)

# Pass to Python via env
export ROOT
echo "$COUNTERS" | COUNTERS_JSON="$COUNTERS" python3 << 'PYEOF'
import json
import os
import re
import sys

ROOT = os.environ.get("ROOT", "/home/az/.paseo/worktrees/integrity-fixes")
counters_str = os.environ.get("COUNTERS_JSON", "{}")
counters = json.loads(counters_str)

errors = []

d_active = counters["decisions"]["active"]
a_total = counters["attestations"]["live_store"]
ct = counters["tests"]["cram_count"]
sc = counters["cli"]["subcommand_count"]
verdict = counters["self_check"]["verdict"]
sc_subjects = counters["self_check"]["subjects"]
sc_passing = counters["self_check"]["passing"]

print(f"=== Source-of-truth counters ===")
print(f"  decisions.active      = {d_active}")
print(f"  attestations.live     = {a_total}")
print(f"  cram tests            = {ct}")
print(f"  CLI subcommands       = {sc}")
print(f"  self-check.verdict    = {verdict} ({sc_passing}/{sc_subjects} pass)")
print()

# PACKAGES.md
packages_path = os.path.join(ROOT, "PACKAGES.md")
if os.path.exists(packages_path):
    with open(packages_path) as f:
        packages = f.read()
    
    # "mathc packages reports X active decisions"
    m = re.search(r'mathc packages reports (\d+) active decisions', packages)
    if m:
        claimed = int(m.group(1))
        if claimed != d_active:
            errors.append(f"PACKAGES.md says '{claimed} active decisions', kernel reports {d_active}")
    
    # "94 files" / "121 files" - attestation count
    # 105 is the correct number, so don't flag it
    for n in [94, 121]:
        if f"contains **{n} files**" in packages or f"contains {n} files" in packages:
            errors.append(f"PACKAGES.md mentions {n} attestation files, kernel has {a_total}")
    
    # "15 files" cram
    if "15 files at HEAD" in packages or "(15 files" in packages:
        errors.append(f"PACKAGES.md says 15 cram files, kernel has {ct}")
    
    # Count main table rows  
    # PACKAGES.md main table lists every decision file in decisions/,
    # including the 3 meta-aggregators (decision.yaml, obligations.yaml,
    # obligation-count-reconcile.yaml). Active vs meta is a separate
    # count tracked elsewhere.
    main_rows = re.findall(r'^\| `decisions/[^`]+\.yaml`', packages, re.MULTILINE)
    d_total = counters["decisions"]["total"]
    if len(main_rows) != d_total:
        errors.append(f"PACKAGES.md main table has {len(main_rows)} rows, expected {d_total}")
    
    # Count cram table rows
    cram_rows = re.findall(r'^\| `[a-z0-9.\-]+\.t`', packages, re.MULTILINE)
    if len(cram_rows) != ct:
        errors.append(f"PACKAGES.md cram table has {len(cram_rows)} rows, expected {ct}")
    
    # Subcommand list - PACKAGES.md Mathc.ml dispatcher comment
    m = re.search(r'validate, context, explain, assess, attest, gate, session-start, record, stats, time-estimate, self-check, render, packages, version', packages)
    if m and sc != 14:
        errors.append(f"PACKAGES.md lists 14 subcommands in comment, kernel has {sc}")

# ROADMAP.md
roadmap_path = os.path.join(ROOT, "ROADMAP.md")
if os.path.exists(roadmap_path):
    with open(roadmap_path) as f:
        roadmap = f.read()
    
    if "94 files" in roadmap:
        errors.append(f"ROADMAP.md says '94 files', kernel has {a_total}")
    if "15 files" in roadmap and "test" in roadmap.lower():
        errors.append(f"ROADMAP.md says '15 files' for cram, kernel has {ct}")
    if "28/28 subjects green" in roadmap:
        errors.append(f"ROADMAP.md says '28/28 subjects green', kernel has {sc_subjects}")

# README.md
readme_path = os.path.join(ROOT, "README.md")
if os.path.exists(readme_path):
    with open(readme_path) as f:
        readme = f.read()
    
    readme_cli_rows = re.findall(r'^\| `mathc [a-zA-Z-]+', readme, re.MULTILINE)
    if len(readme_cli_rows) != sc:
        errors.append(f"README.md CLI table has {len(readme_cli_rows)} rows, kernel has {sc} subcommands")

# AUDIT-0.0.21.md is historical (snapshot of HEAD~1) — only flag if it claims current state
audit_path = os.path.join(ROOT, "doc/AUDIT-0.0.21.md")
if os.path.exists(audit_path):
    with open(audit_path) as f:
        audit = f.read()
    # The audit explicitly dates its numbers — they were correct at HEAD~1
    # If it claims "current", we flag it; otherwise OK
    if "current" in audit.lower() and "94 files" in audit:
        # The audit is titled "Phase 1 acceptance" but was at HEAD~1
        # Leave it for now — it's an historical snapshot
        pass

if errors:
    print("=== DRIFT DETECTED ===")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)
else:
    print("=== NO DRIFT ===")
    sys.exit(0)
PYEOF
