#!/usr/bin/env bash
# tests/fixtures/negative-control-debt.sh — the promise debt of the
# corpus, in three numbers.
#
# WHAT THE DEBT IS. A decision that promises something and names no
# `negative_control` is a check that cannot be shown to fail. The
# fixture with teeth and the fixture that passes whatever happens
# report the same thing — green — and the difference between them is
# invisible unless somebody breaks the property on purpose and watches
# the check catch it.
#
# WHY THREE NUMBERS AND NOT ONE. Until 2026-11-01 this fixture
# reported ONE number: "decisions without a negative control". That
# number conflated three different situations, and the difference
# between them is the whole question:
#
#   CHECKED   the decision names the field `negative_control:` — a
#             control that can fail, and the fixture that proves it.
#
#   DECLARED  the decision carries at least one obligation with the
#             field `declared:` — a promise nobody can check, with a
#             named owner and a date it is looked at again. The
#             promise is not hidden and not pretended to be a check.
#
#   UNCHECKED neither: the decision has obligations, it looks
#             checkable, but no control that can fall and no honest
#             declaration. THIS is the debt.
#
# A decision with NO obligations is in none of the three: it makes no
# promise that could be kept or broken. Its number is printed too, so
# that the three classes and the promise-less decisions add up to the
# corpus — the invariant is checked below, as a SUM, not as three
# independent counters that could each be wrong.
#
# WHY THE INSTRUMENT READS THE YAML ITSELF. The kernel reads
# `negative_control:` (it is the field MC-NEGATIVE-CONTROL-MISSING
# speaks about) and it does NOT read `declared:` — a declaration is
# not a check, and the kernel has no business executing one. So the
# instrument parses the corpus, the way tests/fixtures/
# redundancy-census.sh parses the corpus for the four numbers the
# kernel does not answer. The schema
# (schemas/obligation.json) is read too, and it is the ONLY place
# where the field `declared:` is declared: the instrument takes the
# field's name and its required keys from there, so a field the
# schema does not know cannot be counted by accident.
#
# WHY CEILINGS. The same reason as the other debts: a count that can
# be checked, but not bounded, grows silently. The ceiling that may
# only fall is the UNCHECKED one: that number has to reach zero.
# DECLARED gets its own, slower ceiling: a declared promise is a
# promise to look at it on a date, and dates pass. CHECKED has no
# ceiling at all — it may only grow, and a ceiling on it would be a
# target the corpus is asked to shrink towards.
#
# WHY A NEGATIVE CONTROL. A bound that has never been observed to
# bind is not known to bind. Section 4 builds a synthetic corpus with
# one decision of each kind and requires the instrument to count each
# of them as the rule says — including a decision whose `declared:`
# block is missing a required key, which must NOT be counted as
# declared.
#
# EXIT CODES, following the house convention:
#   0  measured, every ceiling held
#   1  measured, a ceiling did not hold
#   3  nothing was measured (no schema, no corpus) - unknown, not pass

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# --- the ceilings --------------------------------------------------------
#
# CEILING is the UNCHECKED bound: the decisions whose promises are
# neither controlled nor declared. It may fall and may never rise.
#
# MEASURED 2026-11-01: 91 at the moment the instrument landed. The
# corpus had 136 decisions: 44 naming a `negative_control`, 91 in
# neither class, and one (attestation-store-fill) with no obligations
# at all. The number fell twice in this tranche — to 73 when the
# uncheckable promises were DECLARED (the `declared:` fields), and to
# 37 when the decisions that name a control that catches their own
# failure said so (`negative_control:`). The pin follows the truth
# down.
#
# ceiling-fall: 123 -> 91, the corpus changed shape: one number
#   became three, and the number that survived as UNCHECKED is the
#   debt that was always meant to reach zero
# ceiling-fall: 91 -> 73, the uncheckable promises left the debt: the
#   twenty-one decisions that declare them are in the DECLARED class
# ceiling-fall: 73 -> 37, the decisions that name a control that
#   catches their own failure named it, and the debt is what is left
# ceiling-fall: 37 -> 36, the falsified-promise tranche gave
#   waiver-infrastructure-2026-10 a control that catches its own
#   failure: tests/cli/self-check-waiver-verdict.t asserts that a
#   waived gap is reported as open-with-waiver and never as pass
# ceiling-fall: 36 -> 35, the same tranche gave
#   forge-principal-verification-2026-10 the control that catches
#   its own failure: tests/cli/forge-verify.t asserts that an
#   unreachable forge is unknown and exit 3, never pass and exit 0
CEILING=35

# CEILING_DECLARED is the DECLARED bound: the decisions that carry a
# promise nobody can check, with an owner and a date. It falls
# slower than the UNCHECKED one — a declared promise is a promise to
# look at it by a date, and the date passes.
#
# The bound is 21: the number this tranche declares. MEASURED
# 2026-11-01, before the `declared:` fields landed: 0 decisions
# declared anything; after they landed: 21 decisions, 37
# obligations. The ceiling is the promised number, so the corpus may
# not exceed it — and when the declared promises are checked, written
# or archived, the number falls and the pin follows it down.
#
# ceiling-raise: 0 -> 21, the tranche declares the uncheckable
#   promises of twenty-one decisions, so the declared class appears
#   for the first time and its ceiling is the promised number
CEILING_DECLARED=21

SCHEMA="schemas/obligation.json"
DECISIONS_DIR="${MATH_CODING_DECISIONS_DIR:-decisions}"

# --- the measurement -----------------------------------------------------
#
# One rule, over DECISIONS (not over obligations). Prints one line:
#
#   CHECKED <n> DECLARED <n> UNCHECKED <n> NO-PROMISE <n> TOTAL <n>
#
# or, when nothing could be measured:
#
#   unknown <reason>
#
# The classification is a partition, so the four classes add up to the
# corpus. The precedence is DECLARED, then CHECKED, then UNCHECKED:
# a decision that carries a declaration is DECLARED even when it also
# names a control, because a declared obligation must not look like a
# checked one to anything that reads the corpus.
measure() {
  python3 - "$1" "${3:-$SCHEMA}" "${2:-}" <<'PY'
import glob, json, os, re, sys

decisions_dir, schema_path, listing = sys.argv[1], sys.argv[2], sys.argv[3]


def unknown(reason):
    print("unknown " + reason)
    sys.exit(3)


# --- the schema: the only place where `declared:` is declared ------------
try:
    with open(schema_path, encoding="utf-8") as fh:
        schema = json.load(fh)
except Exception as exc:
    unknown("the obligation schema %s cannot be read (%s)" % (schema_path, exc))

declared_schema = ((schema.get("properties") or {}).get("declared") or {})
required = declared_schema.get("required") or []
if not required:
    unknown("the schema declares no required keys for `declared`")
allowed = set((declared_schema.get("properties") or {}).keys())


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError as exc:
        unknown("the decision %s cannot be read (%s)" % (path, exc))


def walk(d):
    if not os.path.isdir(d):
        return []
    out = []
    for path in sorted(glob.glob(os.path.join(d, "**", "*.yaml"), recursive=True)):
        rel = os.path.relpath(path, d)
        if rel.startswith("waivers" + os.sep) or "/waivers/" in rel:
            continue
        out.append(path)
    return out


def is_decision(text):
    # A decision carries the schema math-coding/3.x. Waiver files and
    # migration manifests carry their own schemas and are not rules.
    m = re.search(r"^schema:[ \t]*(\S+)", text, re.M)
    return bool(m) and m.group(1).startswith("math-coding/3")


def top_block(text, header):
    m = re.search(r"^" + header + r":[ \t]*(?:\[\])?[ \t]*\r?\n(.*?)(?=^\S|\Z)",
                  text, re.M | re.S)
    return m.group(1) if m else ""


def obligations(text):
    body = top_block(text, "obligations")
    out, cur = [], None
    for line in body.split("\n"):
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*:", line):
            break
        m = re.match(r"^\s+- id:\s*(\S+)\s*$", line)
        if m:
            cur = {"id": m.group(1), "lines": []}
            out.append(cur)
        elif cur is not None:
            cur["lines"].append(line)
    return out


def declared_block(lines):
    """the `declared:` block of one obligation, as a dict, or None"""
    i = 0
    while i < len(lines):
        m = re.match(r"^(\s*)declared:[ \t]*(.*)$", lines[i])
        if not m:
            i += 1
            continue
        indent = len(m.group(1))
        keys, j = {}, i + 1
        while j < len(lines):
            line = lines[j]
            if not line.strip():
                j += 1
                continue
            if len(line) - len(line.lstrip()) <= indent:
                break
            km = re.match(r"^\s*([A-Za-z_][A-Za-z0-9_]*):[ \t]*(.*)$", line)
            if km:
                keys[km.group(1)] = km.group(2).strip().strip("\"'")
            j += 1
        return keys
    return None


checked, declared, unchecked, no_promise = [], [], [], []
defects = []
total = 0

for path in walk(decisions_dir):
    text = read(path)
    if not is_decision(text):
        continue
    total += 1
    obs = obligations(text)
    if not obs:
        no_promise.append(path)
        continue
    has_declaration = False
    for ob in obs:
        block = declared_block(ob["lines"])
        if block is None:
            continue
        missing = [k for k in required if not block.get(k)]
        if missing:
            defects.append((path, ob["id"],
                            "the declared block misses " + ", ".join(missing)))
            continue
        extra = [k for k in block if k not in allowed]
        if extra:
            defects.append((path, ob["id"],
                            "the declared block carries unknown keys "
                            + ", ".join(sorted(extra))))
            continue
        has_declaration = True
    control = re.search(r"^negative_control:[ \t]*(\S.*)$", text, re.M)
    if has_declaration:
        declared.append(path)
    elif control and control.group(1).strip():
        checked.append(path)
    else:
        unchecked.append(path)

if total == 0:
    unknown("the corpus at %s holds no decision" % decisions_dir)

if listing:
    with open(listing, "w", encoding="utf-8") as fh:
        for path in checked:
            fh.write("checked\t%s\n" % path)
        for path in declared:
            fh.write("declared\t%s\n" % path)
        for path in unchecked:
            fh.write("unchecked\t%s\n" % path)
        for path in no_promise:
            fh.write("no-promise\t%s\n" % path)
        for path, ob, why in defects:
            fh.write("defect\t%s\t%s\t%s\n" % (path, ob, why))

print("CHECKED=%d DECLARED=%d UNCHECKED=%d NO_PROMISE=%d TOTAL=%d"
      % (len(checked), len(declared), len(unchecked), len(no_promise), total))
print("DEFECTS=%d" % len(defects))
PY
}

# --- 0. the items behind the numbers -------------------------------------
# A number nobody can act on is a number, not a measurement. The
# classes are printed one decision per line, so the next tranche knows
# which decisions it is looking at.
if [ "${1:-}" = "--list" ]; then
  list_file="$(mktemp)"
  trap 'rm -f "$list_file"' EXIT
  measure "$DECISIONS_DIR" "$list_file" >/dev/null
  cat "$list_file"
  exit 0
fi

# --- 1. measure ----------------------------------------------------------
measured="$(measure "$DECISIONS_DIR")"
case "$measured" in
  unknown*)
    ok "$measured — nothing was measured, and nothing measured is not zero"
    echo
    echo "negative-control-debt: SKIPPED (nothing was measured - unknown, not pass)"
    exit 3
    ;;
esac

number() { printf '%s\n' "$measured" | tr ' ' '\n' | sed -n "s/^$1=//p" | head -1; }
checked="$(number CHECKED)"
declared="$(number DECLARED)"
unchecked="$(number UNCHECKED)"
no_promise="$(number NO_PROMISE)"
total="$(number TOTAL)"
defects="$(number DEFECTS)"
for v in "$checked" "$declared" "$unchecked" "$no_promise" "$total" "$defects"; do
  if [ -z "$v" ]; then
    ok "the measurement is unreadable ($measured) — nothing was measured, and nothing measured is not zero"
    echo
    echo "negative-control-debt: SKIPPED (nothing was measured - unknown, not pass)"
    exit 3
  fi
done

printf 'ok: checked: %s, declared: %s, unchecked: %s, no promise: %s, decisions: %s\n' \
  "$checked" "$declared" "$unchecked" "$no_promise" "$total"

# --- 2. the invariant: the classes are a partition of the corpus ---------
# Checked as a SUM, not as three independent counters: three counters
# that could each be wrong would still print three numbers.
sum=$((checked + declared + unchecked + no_promise))
if [ "$sum" -eq "$total" ]; then
  ok "the four classes add up to the corpus: $checked + $declared + $unchecked + $no_promise = $total"
else
  bad "the four classes do NOT add up to the corpus: $checked + $declared + $unchecked + $no_promise = $sum, corpus $total"
fi

# --- 3. the ceilings -----------------------------------------------------
if [ "$unchecked" -le "$CEILING" ]; then
  ok "decisions whose promises are neither controlled nor declared: $unchecked (ceiling $CEILING)"
else
  bad "decisions whose promises are neither controlled nor declared: $unchecked EXCEEDS the ceiling $CEILING — the debt grew"
fi

if [ "$declared" -le "$CEILING_DECLARED" ]; then
  ok "decisions that declare an uncheckable promise: $declared (ceiling $CEILING_DECLARED)"
else
  bad "decisions that declare an uncheckable promise: $declared EXCEEDS the ceiling $CEILING_DECLARED — the declared class grew"
fi

# CHECKED has no ceiling on purpose: it may only grow, and a number
# that is asked to shrink is a target the corpus is pushed towards.
ok "checked decisions: $checked (no ceiling: this number may only grow)"

if [ "$defects" -gt 0 ]; then
  bad "$defects declared blocks do not satisfy the schema — a declaration the schema does not accept is not a declaration"
else
  ok "every declared block carries the keys the schema requires"
fi

# --- 4. NEGATIVE CONTROL: the rule must be able to tell the classes apart
# A bound that has never been observed to bind is not known to bind, and
# a rule that has never been observed to classify anything is not known
# to classify. The synthetic corpus holds one decision of each kind:
# a controlled one, a declared one, an unchecked one, a promise-less
# one, and one whose `declared:` block misses a required key — which
# must NOT be counted as declared.
control="$(mktemp -d)"
trap 'rm -rf "$control"' EXIT

cat > "$control/control-checked.yaml" <<'YAML'
---
schema: math-coding/3.3
id: control-checked
revision: 1
state: active
negative_control: tests/fixtures/some-control.sh
intent: a decision that names a control
commitment: the control can fail
obligations:
  - id: the-control-is-named
    claim: the decision names the fixture that catches its failure
    acceptance:
      all:
        - verifier: tests/fixtures/some-control.sh
YAML

cat > "$control/control-declared.yaml" <<'YAML'
---
schema: math-coding/3.3
id: control-declared
revision: 1
state: active
intent: a decision that declares an uncheckable promise
commitment: the promise has an owner and a date
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

cat > "$control/control-unchecked.yaml" <<'YAML'
---
schema: math-coding/3.3
id: control-unchecked
revision: 1
state: active
intent: a decision that looks checkable and is not controlled
commitment: nothing here can fall
obligations:
  - id: the-promise-is-not-controlled
    claim: a check that cannot fail
    acceptance:
      all:
        - verifier: tests/cli/some.t
YAML

cat > "$control/control-no-promise.yaml" <<'YAML'
---
schema: math-coding/3.3
id: control-no-promise
revision: 1
state: active
intent: a decision that makes no promise
commitment: there is nothing to keep
outcomes: []
YAML

cat > "$control/control-broken-declaration.yaml" <<'YAML'
---
schema: math-coding/3.3
id: control-broken-declaration
revision: 1
state: active
intent: a decision whose declaration is missing the date
commitment: an incomplete declaration is not a declaration
obligations:
  - id: the-promise-is-badly-declared
    claim: nobody can check this promise
    declared:
      owner: human:maintainer
    acceptance:
      all:
        - verifier: manual-visual-diff
YAML

control_out="$(measure "$control")"
case "$control_out" in
  unknown*)
    bad "negative control: the synthetic corpus was not measured ($control_out)"
    ;;
  *)
    cnumber() { printf '%s\n' "$control_out" | tr ' ' '\n' | sed -n "s/^$1=//p" | head -1; }
    c_checked="$(cnumber CHECKED)"
    c_declared="$(cnumber DECLARED)"
    c_unchecked="$(cnumber UNCHECKED)"
    c_none="$(cnumber NO_PROMISE)"
    c_total="$(cnumber TOTAL)"
    c_defects="$(cnumber DEFECTS)"
    if [ "$c_checked" -eq 1 ] && [ "$c_declared" -eq 1 ] && [ "$c_unchecked" -eq 2 ] \
       && [ "$c_none" -eq 1 ] && [ "$c_total" -eq 5 ]; then
      ok "negative control: the synthetic corpus is counted as the rule says (1 checked, 1 declared, 2 unchecked, 1 without a promise, 5 decisions)"
    else
      bad "negative control: the synthetic corpus was counted as $c_checked checked, $c_declared declared, $c_unchecked unchecked, $c_none without a promise, of $c_total — the rule does not classify what it claims to classify"
    fi
    if [ "$c_defects" -eq 1 ]; then
      ok "negative control: a declared block that misses a required key is reported as a defect and is not counted as a declaration"
    else
      bad "negative control: the incomplete declaration was reported $c_defects times, expected 1 — a declaration the schema does not accept would be counted as one"
    fi
    ;;
esac

# --- 5. NEGATIVE CONTROL: unknown is not zero ---------------------------
# A corpus or a schema that cannot be read is UNKNOWN. An instrument
# that answers "zero" when it could not read anything is a green light
# on a broken lamp.
case "$(measure "$control/does-not-exist")" in
  unknown*) ok "negative control: a corpus that cannot be read answers unknown, not zero" ;;
  *)        bad "negative control: a corpus that cannot be read answered with a number" ;;
esac
case "$(measure "$DECISIONS_DIR" "" "schemas/does-not-exist.json")" in
  unknown*) ok "negative control: a schema that cannot be read answers unknown, not zero" ;;
  *)        bad "negative control: a schema that cannot be read answered with a number" ;;
esac

echo
if [ "$fail" -eq 0 ]; then
  echo "negative-control-debt: PASS"
  exit 0
fi
echo "negative-control-debt: FAIL"
exit 1
