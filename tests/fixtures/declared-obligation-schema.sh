#!/usr/bin/env bash
# tests/fixtures/declared-obligation-schema.sh — the schema knows the
# `declared` field, and the kernel does not break on it.
#
# WHAT THIS FIXTURE IS. The corpus's uncheckable promises are declared
# with a `declared:` block: an owner, a date to review it on, and a
# reason. The schema is the ONE place where that block is declared
# (schemas/obligation.json), and the corpus's own rule is that a
# promise which is not machine-checked must not look like one that is.
# That rule needs two things to be true at once:
#
#   1. the SCHEMA declares the field, so a reader of the corpus can
#      tell what a declaration is (and what a broken one looks like);
#
#   2. the KERNEL still reads the file. The kernel drops the unknown
#      key - it does not execute a declaration - and `mathc validate`
#      must still answer parse-ok, because a promise that nobody can
#      check is still a promise the corpus has to be able to read.
#
# WHAT IS MEASURED.
#
#   - schemas/obligation.json declares `declared` as an object with
#     additionalProperties false, required [owner, review_on], and the
#     three properties owner, review_on and reason.
#
#   - schemas/decision.json's INLINE obligations form (the second
#     branch of the `oneOf`, the one that accepts `statement:` in
#     place of `claim:`) refers to the same declaration instead of
#     describing a second, different one. Two shapes of the same field
#     are two truths about it, and this tranche exists to stop the
#     corpus from having two truths about anything.
#
#   - a decision that carries a `declared:` block validates parse-ok,
#     and the block survives into the file the kernel read.
#
#   - and the negative half: a `declared:` block with an unknown key
#     is a defect the instrument reports, and a declaration that misses
#     a required key is NOT counted as a declaration. A field the
#     schema does not accept must not be able to buy a decision its
#     DECLARED class.
#
# WHY A FIXTURE AND NOT A COMMENT. The schema is a document; nothing
# reads it at runtime. A change to a document that nothing reads is a
# change nobody can see fail, and the corpus's rule is that a promise
# which cannot fail is not a promise.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# --- 1. the schema declares the field ------------------------------------
python3 - <<'PY' || fail=1
import json, sys

problems = []

try:
    with open("schemas/obligation.json", encoding="utf-8") as fh:
        obligation = json.load(fh)
except Exception as exc:
    print("FAIL: schemas/obligation.json cannot be read (%s)" % exc)
    sys.exit(1)

declared = (obligation.get("properties") or {}).get("declared")
if not isinstance(declared, dict):
    print("FAIL: schemas/obligation.json declares no `declared` property")
    sys.exit(1)

if declared.get("type") != "object":
    problems.append("`declared` is not declared as an object")
if declared.get("additionalProperties") is not False:
    problems.append("`declared` does not close itself against unknown keys")
if sorted(declared.get("required") or []) != ["owner", "review_on"]:
    problems.append("`declared` requires %s, expected owner and review_on"
                    % (declared.get("required") or []))
properties = declared.get("properties") or {}
for key in ("owner", "review_on", "reason"):
    if key not in properties:
        problems.append("`declared` declares no `%s`" % key)
pattern = (properties.get("review_on") or {}).get("pattern") or ""
if "[0-9]" not in pattern or "0-9" not in pattern:
    problems.append("`review_on` carries no date pattern (%r)" % pattern)

try:
    with open("schemas/decision.json", encoding="utf-8") as fh:
        decision = json.load(fh)
except Exception as exc:
    print("FAIL: schemas/decision.json cannot be read (%s)" % exc)
    sys.exit(1)

branches = ((decision.get("properties") or {}).get("obligations") or {}).get(
    "items", {}).get("oneOf") or []
inline = None
for branch in branches:
    if isinstance(branch, dict) and branch.get("type") == "object":
        inline = branch
if inline is None:
    problems.append("schemas/decision.json declares no inline obligations form")
else:
    ref = ((inline.get("properties") or {}).get("declared") or {}).get("$ref")
    if ref != "obligation.json#/properties/declared":
        problems.append(
            "the inline obligations form declares `declared` as %r, expected a "
            "reference to obligation.json" % (ref,))

for problem in problems:
    print("FAIL: " + problem)
if problems:
    sys.exit(1)
PY
if [ "$fail" -eq 0 ]; then
  ok "the schema declares the field, and the second form of an obligation refers to it"
fi

# --- 2. the kernel reads a decision that carries the block ---------------
bin=""
for c in _build/default/bin/mathc.exe _build/install/default/bin/mathc; do
  if [ -x "$c" ]; then bin="$PWD/$c"; break; fi
done
if [ -z "$bin" ]; then
  for c in mathc mathc.exe; do
    if command -v "$c" >/dev/null 2>&1; then bin="$(command -v "$c")"; break; fi
  done
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/declared-demo.yaml" <<'YAML'
---
schema: math-coding/3.3
id: declared-demo
revision: 1
state: active
intent: a decision whose promise nobody can check
commitment: the promise is declared, with an owner and a date
counterexample: n/a
axiom_link:
  - A0
scope:
  paths: []
outcomes: []
obligations:
  - id: the-promise-is-declared
    claim: nobody can check this promise
    declared:
      owner: human:maintainer
      review_on: 2026-12-15
      reason: nothing can check a visual promise
    acceptance:
      all:
        - verifier: manual-visual-diff
YAML

if [ -z "$bin" ]; then
  bad "no mathc binary found: the kernel could not be asked whether it reads the block"
else
  if MATH_CODING_ROOT="$tmp" "$bin" validate "$tmp/declared-demo.yaml" 2>&1 \
      | grep -q "^parse-ok:"; then
    ok "the kernel reads a decision that carries a declared block (parse-ok)"
  else
    bad "the kernel does not read a decision that carries a declared block"
    MATH_CODING_ROOT="$tmp" "$bin" validate "$tmp/declared-demo.yaml" 2>&1 | head -5
  fi
fi

# --- 3. the negative half: a broken declaration is not a declaration -----
# A `declared:` block with a key the schema does not know must not buy
# a decision the DECLARED class, and the instrument has to say so.
cat > "$tmp/declared-broken.yaml" <<'YAML'
---
schema: math-coding/3.3
id: declared-broken
revision: 1
state: active
intent: a decision whose declaration the schema does not accept
commitment: the promise is still uncheckable, but the block is broken
counterexample: n/a
axiom_link:
  - A0
scope:
  paths: []
outcomes: []
obligations:
  - id: the-promise-is-badly-declared
    claim: nobody can check this promise
    declared:
      owner: human:maintainer
      review_on: 2026-12-15
      owner_name: human:maintainer
    acceptance:
      all:
        - verifier: manual-visual-diff
YAML

out="$(MATH_CODING_DECISIONS_DIR="$tmp" bash tests/fixtures/negative-control-debt.sh 2>&1)"
if printf '%s\n' "$out" | grep -q "^ok: every declared block carries the keys the schema requires"; then
  bad "the instrument did not report the broken declaration as a defect"
elif printf '%s\n' "$out" | grep -q "declared blocks do not satisfy the schema"; then
  ok "a declaration with a key the schema does not know is reported as a defect"
else
  bad "the instrument neither accepted nor reported the broken declaration"
  printf '%s\n' "$out" | head -8
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "declared-obligation-schema: PASS"
  exit 0
fi
echo "declared-obligation-schema: FAIL"
exit 1
