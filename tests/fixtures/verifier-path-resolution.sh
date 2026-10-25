#!/usr/bin/env bash
# tests/fixtures/verifier-path-resolution.sh
#
# A verifier's evidence path must resolve inside the project tree that
# contains the decision.
#
# TWO SEVERITIES, DELIBERATELY DIFFERENT:
#
#   - ABSOLUTE -> Block. An absolute path names one machine's
#     directory layout. It resolves on the author's workstation and
#     nowhere else, so the obligation cannot be checked by any
#     reader. There is no legitimate form of it.
#
#   - MISSING / UNRESOLVABLE -> Warn. A relative path that does not
#     exist may name a build artifact (absent in a fresh checkout
#     before the first `dune build`), a generated file, or a
#     `file.ml::case` selector. Rejecting on that would make
#     `mathc validate` unusable before the first build, so the gap
#     is made visible instead.
#
# THE NEGATIVE CONTROL. A check that cannot fail is not a check.
# Section 4 runs the same comparison against a decision that has NO
# path at all: the fixture must report it as clean, so that a
# failing section 1 or 2 cannot be confused with "the diagnostic
# fires on everything".

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
  echo "verifier-path-resolution: FAIL"
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The probe decisions must live INSIDE a project: the project root is
# what a relative `path:` is resolved against, and the root is found by
# walking up from the VALIDATED FILE. A decision in a bare temp dir has
# no project above it, so a relative path would have nothing to resolve
# against and the missing-path case could not be exercised.
proj="$work/proj"
mkdir -p "$proj"
printf '(lang dune 3.0)
' > "$proj/dune-project"
Z='sha256:0000000000000000000000000000000000000000000000000000000000000000'

# write_decision <id> <path-key or "none">
write_decision() {
  local id="$1" pathline="$2" out="$3"
  {
    echo "---"
    echo "schema: math-coding/3.3"
    echo "id: $id"
    echo "revision: 1"
    echo "state: active"
    echo "mode: light"
    echo "body_sha: \"$Z\""
    echo "yaml_sha: \"$Z\""
    echo "axiom_link:"
    echo "  - A0"
    echo "intent: probe"
    echo "commitment: probe"
    echo "counterexample: probe"
    echo "scope:"
    echo "  paths: []"
    echo "outcomes:"
    echo "  - id: o1"
    echo "    statement: probe"
    echo "obligations:"
    echo "  - id: obl"
    echo "    claim: probe"
    echo "    acceptance:"
    echo "      all:"
    echo "        - verifier: file-exists x"
    echo "          result: pass"
    [ "$pathline" != "none" ] && echo "          path: $pathline"
  } > "$out"
  "$BIN" rehash --write "$out" >/dev/null 2>&1
}

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# --- 1. an absolute path is a Block ---------------------------------------
write_decision abs-probe /absolute/elsewhere.sh "$proj/abs.yaml"
out="$("$BIN" validate "$proj/abs.yaml" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q MC-VERIFIER-PATH-UNRESOLVED; then
  ok "an absolute verifier path is rejected with MC-VERIFIER-PATH-UNRESOLVED"
else
  bad "an absolute verifier path was not rejected (rc=$rc): $(printf '%s' "$out" | head -2)"
fi
if printf '%s' "$out" | grep -q 'severity: block'; then
  ok "the absolute case is a block"
else
  bad "the absolute case is not a block: $(printf '%s' "$out" | head -3)"
fi

# --- 2. a missing relative path is a Warn, not a rejection ---------------
write_decision rel-probe does/not/exist.sh "$proj/rel.yaml"
out="$("$BIN" validate "$proj/rel.yaml" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'parse-ok'; then
  ok "a missing relative verifier path leaves the verdict parse-ok"
else
  bad "a missing relative verifier path did not stay parse-ok (rc=$rc): $(printf '%s' "$out" | head -2)"
fi
if printf '%s' "$out" | grep -q MC-VERIFIER-PATH-UNRESOLVED; then
  ok "the missing relative case still reports the gap"
else
  bad "the missing relative case reports no gap: $(printf '%s' "$out" | head -3)"
fi

# --- 2b. a MANUAL declaration is out of the rule's scope -------------------
# `path:`/`needle:` on a `manual-` acceptance item is an ANNOTATION FOR
# THE REVIEWER ("look in this file for this string"), not an executable
# check. The kernel drops the key today, which is a separate defect
# (recorded in the decision); until the schema carries it, an absolute
# path there is a portability wart, not a broken obligation, and must
# not reject the file.
write_decision manual-probe none "$work/manual.yaml"
python3 - "$work/manual.yaml" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("        - verifier: file-exists x",
              "        - verifier: manual-file-exists-unqualified")
s = s.replace("          result: pass",
              "          path: /home/someone/else/private.txt\n          result: pass")
open(p, "w").write(s)
PYEOF
"$BIN" rehash --write "$work/manual.yaml" >/dev/null 2>&1
out="$("$BIN" validate "$work/manual.yaml" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  ok "a manual- declaration with an absolute path does not reject the file"
else
  bad "a manual- declaration with an absolute path rejected the file (rc=$rc): $(printf '%s' "$out" | head -2)"
fi

# --- 3. the diagnostic is explainable --------------------------------------
if "$BIN" explain-diagnostic MC-VERIFIER-PATH-UNRESOLVED 2>&1 \
     | grep -q '"code":"MC-VERIFIER-PATH-UNRESOLVED"'; then
  ok "the diagnostic is registered and explainable"
else
  bad "MC-VERIFIER-PATH-UNRESOLVED is not in the diagnostic registry"
fi

# --- 4. NEGATIVE CONTROL: a decision with no path is clean ----------------
write_decision clean-probe none "$proj/clean.yaml"
out="$("$BIN" validate "$proj/clean.yaml" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -q MC-VERIFIER-PATH-UNRESOLVED; then
  ok "a decision with no path key is clean — the diagnostic fires on the path, not on everything"
else
  bad "a decision with no path key was reported as a violation (rc=$rc): $(printf '%s' "$out" | head -3)"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "verifier-path-resolution: PASS"
  exit 0
fi
echo "verifier-path-resolution: FAIL"
exit 1
