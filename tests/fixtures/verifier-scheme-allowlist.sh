#!/usr/bin/env bash
# tests/fixtures/verifier-scheme-allowlist.sh — a verifier scheme the
# kernel does not know is a promise the corpus cannot keep.
#
# WHAT IT MEASURES. Every obligation in the corpus names a verifier.
# The kernel can execute some of those names and not others: the
# scheme of a verifier string is its first whitespace-delimited token
# (bin/Mathc.ml::parse_verifier_string), and the kernel executes a
# string only when the scheme is in `canonical_verifier_schemes` or
# begins with one of `canonical_verifier_prefixes`
# (bin/Mathc.ml::known_verifier_scheme). A scheme outside both is a
# string the kernel cannot run. The corpus still carries the
# obligation, and the store may still carry a `pass` for it.
#
# The kernel DOES say something about this: `mathc validate` emits one
# Warn-level MC-VERIFIER-SCHEME-UNKNOWN per offending verifier string
# (decisions/verifier-scheme-convention-2026-11.yaml). A warning per
# file is not a number. Nothing aggregated the warnings over the
# corpus, so the corpus could grow offenders one file at a time and
# nothing anywhere said so. THIS is that number.
#
# THE LIST IS READ OUT OF THE KERNEL, NEVER COPIED. A copy of the
# scheme list is a second place where "what the kernel can execute"
# is answered, and a copy drifts: the kernel learned `shell-grep-absent`
# on 2026-10-29, and the census that carried its own copy went on
# calling it a declaration for four obligations
# (tests/fixtures/executed-evidence-census.sh says so in its header).
# This fixture reads the two bindings out of bin/Mathc.ml on every
# run. If the bindings cannot be read, the fixture reports NOTHING and
# exits 3 (unknown): a fixture that cannot tell a check from a
# declaration must not report a number, least of all a zero.
#
# THE COUNT IS IN OBLIGATIONS, NOT IN STRINGS. One obligation may
# carry two offending verifiers; the obligation is the unit that
# becomes a promise nobody keeps, so it is the unit counted. The
# number of offending STRINGS is reported beside it, because the two
# answer different questions and the difference between them is
# information.
#
# THE NUMBER IS CROSS-CHECKED AGAINST THE KERNEL. The fixture parses
# the corpus itself, because it must not depend on the shape of a
# CLI's output format. But a fixture that classifies differently from
# the thing it censuses measures the wrong thing - so the fixture also
# asks the kernel, over the same corpus, how many
# MC-VERIFIER-SCHEME-UNKNOWN it emits, and REQUIRES the two numbers to
# agree. If they disagree, the fixture exits 3 (unknown) and names
# both: it cannot conclude which of the two is right, and a number it
# cannot stand behind is not a number.
#
# WHY A CEILING. The same reason as the other instruments in this
# directory: a number that can be checked but not bounded grows
# silently. Each ceiling here may FALL and may never RISE. Raising one
# is an explicit, reviewable edit of this file, with the reason
# written down beside it.
#
# WHY A NEGATIVE CONTROL. A bound that has never been observed to
# bind is not known to bind. Section 5 builds a synthetic corpus that
# exceeds the ceiling and requires this fixture to report it as over
# the ceiling - by the fixture's own measurement AND by the kernel's
# own diagnostic, so the control proves the comparison can fail and
# not only that the parser can be run. Section 6 proves the unknown
# path: with the kernel's source made unreadable, the fixture must
# report "unknown" and exit 3, never a zero.
#
# WHAT THIS FIXTURE DOES NOT DO. It does not rewrite a verifier, it
# does not decide whether an obligation should exist, and it does not
# decide whether a bespoke scheme should be added to the kernel's
# allowlist. Those are decisions. This counts what can be counted, so
# the decisions are made against a number instead of an impression.
#
# Exit codes, following the house convention:
#   0  measured, the ceiling held
#   1  measured, the ceiling did not hold
#   3  nothing was measured (no allowlist to read, no kernel to ask,
#      or the two disagree) - unknown, not pass

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# --- the ceiling --------------------------------------------------------
#
# MEASURED 2026-10-31 against the corpus at main b9a0decb: five
# obligations carry a verifier whose scheme the kernel does not know.
# The kernel's own diagnostic says so, once per offending string -
# six strings in five obligations, because `decisions-renamed` in
# decisions/cli-canonical-name.yaml carries two.
#
# The five are not all the same defect, and the breakdown is reported
# so that the debt can be paid in the right order:
#
#   2  a YAML single quote the reader does not remove. The kernel's
#      scalar reader strips DOUBLE quotes and leaves SINGLE ones
#      (lib/codec.ml::parse_yaml_scalar), so
#      `verifier: 'shell-grep-absent ...'` reaches the kernel as the
#      scheme `'shell-grep-absent` - a scheme nobody can execute.
#      Both are in decisions/cli-canonical-name.yaml.
#
#   1  a YAML DOUBLE quote that the comment stripper removes with the
#      comment: `verifier: "shell-grep spec/constitution.md # ..."`
#      loses its closing quote to the `#` (lib/codec.ml::yaml_strip
#      cuts at the first `#`), so the reader does not strip it
#      either, and the scheme is `"shell-grep`. It is in
#      decisions/constitution-header-3-3-update-2026-10.yaml.
#
#   2  a bespoke scheme that was never on the list:
#      `mathc-self-check-verdict-pass` (twice) and `mathc-validate`.
#      These are not quoting accidents; they are names the kernel
#      never learned.
#
# The census counts QUOTED verifier strings - raw text that begins
# with a quote - and pins that number at 5. The census measures the
# accident; this fixture measures the consequence, and the two sets are
# not the same set. Of the census's five quoted strings, TWO reach the
# kernel with a sound scheme (their closing double quote survives and
# the reader strips it), so the census counts two obligations the
# kernel executes perfectly well; and THREE of this fixture's six
# offending strings are not quoting accidents at all - they name
# schemes the kernel never learned. The census's number is about
# SYNTAX; this one is about EXECUTION.
#
# The ceiling may only fall. It reaches 0 when the corpus carries no
# obligation whose verifier the kernel cannot execute - the work of
# tranche T2.3 of docs/plans/redundancy-and-portability-2026-11.md.
# ceiling-fall: 5 -> 0, every verifier scheme in the corpus is canonical now
CEILING_NON_CANONICAL_OBLIGATIONS=0

# --- the kernel --------------------------------------------------------
kernel_bin() {
  if [ -x "_build/default/bin/mathc.exe" ]; then
    printf '%s' "$PWD/_build/default/bin/mathc.exe"; return 0
  fi
  if [ -x "_build/install/default/bin/mathc" ]; then
    printf '%s' "$PWD/_build/install/default/bin/mathc"; return 0
  fi
  if command -v mathc >/dev/null 2>&1; then
    command -v mathc; return 0
  fi
  if command -v mathc.exe >/dev/null 2>&1; then
    command -v mathc.exe; return 0
  fi
  return 1
}

# --- the measurement ----------------------------------------------------
#
# measure <decisions-dir> <kernel-source>
#
# prints "<obligations> <strings>" on stdout, one line per offending
# string on stderr, and the word "unknown" on stdout when the
# allowlist cannot be read out of the kernel's source.
#
# THE YAML SEMANTICS ARE THE KERNEL'S, not a YAML library's. The
# kernel reads a decision with a hand-written reader
# (lib/codec.ml), and a general YAML parser would read the corpus
# DIFFERENTLY from the thing that executes it - which is exactly the
# defect this fixture exists to catch. So the two rules that matter
# are applied here as the kernel applies them:
#
#   1. lib/codec.ml::yaml_strip cuts every line at its first `#`,
#      inside a quoted string too. A closing quote that follows a `#`
#      is therefore gone before the scalar is read.
#   2. lib/codec.ml::parse_yaml_scalar strips a value that BEGINS and
#      ENDS with `"`. It does not strip single quotes. A value that
#      begins with `'` keeps it.
measure() {
  python3 - "$1" "$2" <<'PY'
import glob, os, re, sys, collections

decisions_dir, kernel_src = sys.argv[1], sys.argv[2]

# --- the allowlist, read out of the kernel's own source ----------------
def read_binding(text, name):
    m = re.search(r"\blet\b[^\n=]*\b" + re.escape(name) + r"\s*=\s*\[(.*?)\]",
                  text, re.S)
    if not m:
        return None
    items = re.findall(r'"([^"]*)"', m.group(1))
    return items or None

try:
    src = open(kernel_src, encoding="utf-8", errors="replace").read()
except OSError:
    print("unknown")
    raise SystemExit(0)

schemes = read_binding(src, "canonical_verifier_schemes")
prefixes = read_binding(src, "canonical_verifier_prefixes")
if schemes is None or prefixes is None:
    # The list could not be read. Say so; do not report a number.
    print("unknown")
    raise SystemExit(0)

scheme_set = set(schemes)
prefix_list = list(prefixes)

def known(scheme):
    # bin/Mathc.ml::known_verifier_scheme
    if scheme in scheme_set:
        return True
    for p in prefix_list:
        if len(scheme) >= len(p) and scheme[:len(p)] == p:
            return True
    return False

# --- the kernel's YAML semantics ---------------------------------------
def yaml_strip(text):
    out = []
    for line in text.split("\n"):
        i = line.find("#")
        if i >= 0:
            line = line[:i]
        out.append(line.replace("\r", ""))
    return "\n".join(out)

def scalar_value(raw):
    # lib/codec.ml::parse_yaml_scalar, for the string case.
    t = raw.strip()
    if len(t) >= 2 and t[0] == '"' and t[-1] == '"':
        return t[1:-1]
    return t

def top_block(text, header):
    m = re.search(r"^" + header + r":[ \t]*(?:\[\])?[ \t]*\r?\n(.*?)(?=^\S|\Z)",
                  text, re.M | re.S)
    return m.group(1) if m else ""

def verifier_strings(obl_text):
    """The verifier strings of `obligations[*].acceptance.all[*].verifier`.

    The kernel walks exactly this path (bin/Mathc.ml::
    collect_verifier_scheme_diagnostics), so the fixture walks exactly
    this path: an `acceptance.any` list is NOT walked by the kernel
    and is not walked here.
    """
    out = []
    in_acc = False
    in_all = False
    for line in obl_text.splitlines():
        if re.match(r"^ {2}-[ \t]*id:[ \t]*", line):
            in_acc = False
            in_all = False
            continue
        if re.match(r"^ {4}acceptance:[ \t]*$", line):
            in_acc = True
            in_all = False
            continue
        if re.match(r"^ {4}\S", line):
            in_acc = False
            in_all = False
            continue
        if in_acc and re.match(r"^ {6}all:[ \t]*$", line):
            in_all = True
            continue
        if in_acc and re.match(r"^ {6}\S", line):
            in_all = False
            continue
        if in_all:
            m = re.match(r"^ {8}-[ \t]*verifier:[ \t]*(.+?)[ \t]*$", line)
            if m:
                out.append(m.group(1))
    return out

def walk(d):
    if not os.path.isdir(d):
        return []
    out = []
    for path in sorted(glob.glob(os.path.join(d, "**", "*.yaml"),
                                 recursive=True)):
        rel = os.path.relpath(path, d)
        if rel.startswith("waivers" + os.sep) or "/waivers/" in rel:
            continue
        out.append(path)
    return out

files = walk(decisions_dir)
if not files:
    print("unknown")
    raise SystemExit(0)

offending_obligations = set()
offending_strings = []
by_scheme = collections.Counter()

for path in files:
    try:
        raw = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    text = yaml_strip(raw)
    obl = top_block(text, "obligations")
    if not obl:
        continue
    # walk obligation by obligation, so a string is attributed to one
    for chunk in re.split(r"^ {2}-[ \t]*id:[ \t]*", obl, flags=re.M)[1:]:
        head = chunk.split("\n", 1)[0].strip()
        for v in verifier_strings(chunk):
            value = scalar_value(v)
            parts = [t for t in value.split(" ") if t.strip() != ""]
            if not parts:
                continue
            scheme = parts[0]
            if known(scheme):
                continue
            offending_obligations.add((path, head))
            offending_strings.append((path, head, scheme))
            by_scheme[scheme] += 1

for path, obl_id, scheme in offending_strings:
    print("      %s :: %s :: scheme %r" % (path, obl_id, scheme),
          file=sys.stderr)
print("%d %d" % (len(offending_obligations), len(offending_strings)))
PY
}

# --- 1. measure --------------------------------------------------------
DECISIONS_DIR="${MATH_CODING_DECISIONS_DIR:-decisions}"
KERNEL_SRC="bin/Mathc.ml"

measured="$(measure "$DECISIONS_DIR" "$KERNEL_SRC" 2>/dev/null)"
if [ "${measured:-}" = "unknown" ]; then
  ok "the canonical scheme list could not be read out of $KERNEL_SRC: nothing was measured, and a measurement of nothing is not a measurement"
  echo "verifier-scheme-allowlist: SKIPPED (unknown, not pass)"
  exit 3
fi

read -r obligations strings <<<"${measured:-}"
if [ -z "${obligations:-}" ] || [ -z "${strings:-}" ]; then
  bad "the measurement produced no numbers - the parse failed"
  echo "verifier-scheme-allowlist: FAIL"
  exit 1
fi

printf 'ok: the corpus carries %s obligations whose verifier scheme is outside the kernel'"'"'s list\n' \
  "$obligations"
printf '     (%s offending verifier strings; the kernel reports one warning per string)\n' \
  "$strings"

# --- 2. the cross-check against the kernel -----------------------------
#
# The kernel is the authority on what its own corpus contains. The
# fixture asks it, over the same corpus, and requires the two counts
# of offending STRINGS to agree. A disagreement means one of the two
# readers is wrong about the corpus, and this fixture cannot say
# which - so it says "unknown" instead of a number.
bin="$(kernel_bin || true)"
if [ -z "$bin" ]; then
  ok "no kernel binary to ask: the cross-check could not conclude, so the measurement does not stand"
  echo "verifier-scheme-allowlist: SKIPPED (unknown, not pass)"
  exit 3
fi

kernel_warnings=0
kernel_files=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  kernel_files=$((kernel_files + 1))
  n="$("$bin" validate "$f" 2>&1 >/dev/null | grep -c 'MC-VERIFIER-SCHEME-UNKNOWN')"
  kernel_warnings=$((kernel_warnings + n))
done <<EOF
$(find "$DECISIONS_DIR" -name '*.yaml' -not -path '*/waivers/*' | LC_ALL=C sort)
EOF

if [ "$kernel_warnings" -ne "$strings" ]; then
  bad "this fixture counts $strings offending verifier strings and the kernel reports $kernel_warnings MC-VERIFIER-SCHEME-UNKNOWN warnings over the same corpus: the two readers disagree, so the number is unknown"
  echo "verifier-scheme-allowlist: SKIPPED (unknown, not pass)"
  exit 3
fi
ok "the kernel reports the same $kernel_warnings MC-VERIFIER-SCHEME-UNKNOWN warnings over $kernel_files decisions: the two readers agree"

# --- 3. the ceiling ----------------------------------------------------
if [ "$obligations" -le "$CEILING_NON_CANONICAL_OBLIGATIONS" ]; then
  ok "obligations with a verifier scheme the kernel does not know: $obligations (ceiling $CEILING_NON_CANONICAL_OBLIGATIONS)"
else
  bad "obligations with a verifier scheme the kernel does not know: $obligations EXCEEDS the ceiling $CEILING_NON_CANONICAL_OBLIGATIONS - the corpus grew promises no program can keep"
fi

# --- 4. what the offenders are -----------------------------------------
# Reported, not bounded: the debt is one of several kinds, and the
# kind decides who can pay it.
printf 'ok: the offenders by scheme:\n'
measure_detail="$(measure "$DECISIONS_DIR" "$KERNEL_SRC" 2>&1 >/dev/null)"
if [ -n "$measure_detail" ]; then
  printf '%s\n' "$measure_detail" | sed 's/^/     /'
fi

# --- 5. the negative control -------------------------------------------
# A bound that has never been observed to bind is not known to bind.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/decisions"

i=0
while [ "$i" -lt $((CEILING_NON_CANONICAL_OBLIGATIONS + 3)) ]; do
  cat > "$work/decisions/control-$i.yaml" <<YAML
---
schema: math-coding/3.3
id: scheme-control-$i
revision: 1
state: active
mode: light
axiom_link:
  - A0
intent: |
  A synthetic decision, so the lint has a corpus to measure.
commitment: |
  The control corpus exists.
scope:
  paths:
    - "decisions/**"
outcomes:
  - id: control
    statement: |
      The control corpus exists.
counterexample: |
  A synthetic decision, so the lint has a corpus to measure.
obligations:
  - id: a-scheme-the-kernel-does-not-know
    claim: |
      The control obligation exists.
    acceptance:
      all:
        - verifier: bespoke-scheme-$i some/path needle
YAML
  i=$((i + 1))
done

control_measured="$(measure "$work/decisions" "$KERNEL_SRC" 2>/dev/null)"
read -r control_obligations control_strings <<<"${control_measured:-}"
if [ -z "${control_obligations:-}" ]; then
  bad "the negative control measured nothing: the fixture cannot measure a synthetic corpus, so its ceiling cannot bind"
elif [ "$control_obligations" -gt "$CEILING_NON_CANONICAL_OBLIGATIONS" ]; then
  ok "negative control: a synthetic corpus measures $control_obligations obligations with a scheme the kernel does not know, above the ceiling $CEILING_NON_CANONICAL_OBLIGATIONS"
else
  bad "negative control: the synthetic corpus measured $control_obligations offending obligations, not above the ceiling $CEILING_NON_CANONICAL_OBLIGATIONS - the ceiling cannot bind"
fi

# The control must also be seen BY THE KERNEL, or the fixture proves
# only that its own parser can count. A control the kernel does not
# see is a control that does not exist.
control_kernel=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n="$("$bin" validate "$f" 2>&1 >/dev/null | grep -c 'MC-VERIFIER-SCHEME-UNKNOWN')"
  control_kernel=$((control_kernel + n))
done <<EOF
$(find "$work/decisions" -name '*.yaml' | LC_ALL=C sort)
EOF
if [ "$control_kernel" -eq "$control_strings" ] && [ "$control_kernel" -gt 0 ]; then
  ok "negative control: the kernel reports the same $control_kernel warnings over the synthetic corpus - the control is real, not only self-reported"
else
  bad "negative control: the kernel reports $control_kernel warnings over the synthetic corpus and the fixture counted $control_strings - the control does not exist for the kernel"
fi

# --- 6. the unknown path -----------------------------------------------
# Nothing measured is UNKNOWN, not a zero. With the kernel's source
# unreadable, the fixture must say so and exit 3 - never report 0 and
# pass. This control is the one that keeps the instrument honest in
# the failure mode that matters most: a fixture that cannot read the
# list would otherwise report "0 offenders" and be green forever.
if measure "$work/decisions" "$work/no-such-kernel.ml" 2>/dev/null | grep -q '^unknown$'; then
  ok "unknown control: with the kernel's source unreadable the measurement reports unknown rather than a number"
else
  bad "unknown control: with the kernel's source unreadable the measurement did not report unknown - a fixture that cannot read the list must not report zero"
fi

# --- 7. verdict --------------------------------------------------------
if [ "$fail" -ne 0 ]; then
  echo "verifier-scheme-allowlist: FAIL"
  exit 1
fi
echo "verifier-scheme-allowlist: PASS"
exit 0
