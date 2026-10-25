#!/usr/bin/env bash
# tests/fixtures/no-dead-scope-paths.sh
#
# Does any decision name a scope path that matches no tracked file?
#
# WHY. A decision's `scope.paths` names the files its attestation's
# `materials_digest` is computed over: the digest is the digest of the
# CONTENT of the files the scope MATCHES (lib/gate.ml::scope_materials_digest).
# An entry that matches nothing is not a weaker claim - it is NO claim:
# it contributes nothing to the matched set, and it says nothing about
# what the obligation depends on.
#
# It is also a TRAP. A dead path matches nothing today; the day
# somebody creates a file with that name it starts silently
# invalidating attestations that nobody re-signed. Measured on
# 2026-10-25, before the prune: 81 of the corpus's 246 decisions
# carried at least one such entry - `lib/render.ml` in 26 of them,
# `OCAML_BEST_PRACTICES.md` in 22 - and the sharpest were the entries
# whose trailing comment sat INSIDE the quoted path, so the path the
# kernel read was `decisions/audit-0.0.21-fixes.yaml"  # read-only
# reference`.
#
# THE RULE. A scope may name only what the obligation actually
# depends on, and only paths that resolve. See
# decisions/dead-scope-paths-2026-10.yaml.
#
# THE CHECK. scripts/prune-dead-scope-paths.py --check reports every
# scope path that matches no tracked file, using the KERNEL's glob
# rules (Gate.glob_match, via scripts/audit-scopes.py) and the
# kernel's scope extraction (lib/memory.ml::extract_scope_paths). The
# ceiling is ZERO: a dead scope path is not a debt to be tolerated,
# it is a defect.
#
# THE NEGATIVE CONTROL. A check that cannot fail is not a check. The
# fixture measures TWICE: once over the real corpus, and once over a
# throwaway copy of the corpus with a decision that names a path that
# does not exist. The second measurement MUST find the dead path and
# MUST exit non-zero. Without that, the first measurement could be
# vacuously true - a checker that scans nothing reports nothing.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

PRUNE=scripts/prune-dead-scope-paths.py

# The ceiling. Zero: a scope path that names nothing is a defect.
CEILING_DEAD=0

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# counts <output-file> <field> -> the number the tool reported
counts() {
  python3 - "$1" "$2" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
m = re.search(r"(\d+) %s" % re.escape(sys.argv[2]), text)
print(m.group(1) if m else "-1")
PY
}

# --- 1. the corpus carries no dead scope path ------------------------------
if python3 "$PRUNE" --check --decisions decisions >"$work/real.txt" 2>&1; then
  rc_real=0
else
  rc_real=$?
fi
dead=$(counts "$work/real.txt" "with a dead scope path")
scanned=$(counts "$work/real.txt" "decision(s) scanned")
examined=$(counts "$work/real.txt" "scope path(s) examined")

if [ "$dead" = "-1" ]; then
  bad "the checker reported nothing parseable: $(head -2 "$work/real.txt")"
elif [ "$dead" -le "$CEILING_DEAD" ]; then
  ok "no decision names a scope path that matches no tracked file ($scanned decisions, $examined scope paths, ceiling $CEILING_DEAD)"
else
  bad "$dead decision(s) name a scope path that matches no tracked file, above the ceiling $CEILING_DEAD"
  sed -n '2,25p' "$work/real.txt"
fi

if [ "$rc_real" -eq 0 ]; then
  ok "the checker exits 0 on a corpus with no dead scope path"
else
  bad "the checker exited $rc_real on a corpus with no dead scope path"
fi

# The check must not be vacuous: it has to be reading the corpus.
if [ "$scanned" -ge 200 ] && [ "$examined" -ge 500 ]; then
  ok "the checker is not vacuous: it read $scanned decisions and $examined scope paths"
else
  bad "the checker examined only $scanned decisions and $examined scope paths; it is not reading the corpus"
fi

# --- 2. NEGATIVE CONTROL: the check DETECTS a dead path --------------------
# A throwaway copy of the corpus, with one decision that names a file
# that does not exist. The check must find it and must exit non-zero.
copy="$work/corpus"
mkdir -p "$copy"
cp decisions/*.yaml "$copy/"
cat > "$copy/zz-dead-scope-path-probe.yaml" <<'YAML'
---
schema: math-coding/3.3
id: zz-dead-scope-path-probe
revision: 1
state: active
mode: light
body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
intent: probe
commitment: probe
counterexample: probe
scope:
  paths:
    - "lib/there-is-no-such-file.ml"
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

if python3 "$PRUNE" --check --decisions "$copy" >"$work/probe.txt" 2>&1; then
  rc_probe=0
else
  rc_probe=$?
fi
probe_dead=$(counts "$work/probe.txt" "with a dead scope path")

if [ "$rc_probe" -ne 0 ]; then
  ok "the check is live: a corpus carrying a dead scope path exits $rc_probe"
else
  bad "the check cannot detect a dead scope path - it exited 0 on a corpus that carries one"
fi

if [ "$probe_dead" = "1" ]; then
  ok "the check names the dead decision: 1 decision with a dead scope path"
else
  bad "the check reported $probe_dead dead decisions on the probe corpus, expected 1"
fi

if grep -q "lib/there-is-no-such-file.ml" "$work/probe.txt"; then
  ok "the check names the dead path itself: lib/there-is-no-such-file.ml"
else
  bad "the check did not name the dead path it found"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "no-dead-scope-paths: PASS"
  exit 0
fi
echo "no-dead-scope-paths: FAIL"
exit 1
