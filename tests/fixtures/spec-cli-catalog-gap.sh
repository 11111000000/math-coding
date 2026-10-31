#!/usr/bin/env bash
# tests/fixtures/spec-cli-catalog-gap.sh
#
# Verifier for decisions/spec-cli-catalog.yaml
# (`the-catalog-gap-is-measured`).
#
# WHAT IT MEASURES. `spec/semantics.md` is normative for the CLI
# surface, and the corpus's rule is that the spec describes what the
# CLI does. The dispatcher in `bin/Mathc.ml` grew past the catalog:
# the spec carries 18 command rows and the dispatcher answers 39
# names, so 21 of them are implemented and undocumented.
#
# WHY A NUMBER AND NOT A PROMISE. The honest form of this promise
# is not "the spec lists every command" -- that was false on the day
# it was written and has been false since, and a promise that has
# been false for a month teaches the reader that the corpus's
# promises are decoration. The honest form is a MEASURED GAP with a
# ceiling that may only fall: every command the dispatcher gains and
# the catalog does not follow moves the number, and a corpus that
# grows the CLI without growing the spec is visible.
#
# BOTH SIDES ARE READ, NEVER COPIED. The command names come out of
# the dispatcher's own match arms in `bin/Mathc.ml`, and the rows
# come out of the `### \`<command>\`` headings in `spec/semantics.md`.
# A copy of either drifts, and a copy that drifts measures a corpus
# that no longer exists.
#
# WHY A NEGATIVE CONTROL. A bound that has never been observed to
# bind is not known to bind, and a measurement that has never been
# observed to move is not a measurement. The control below builds a
# synthetic dispatcher and a synthetic spec whose gap is larger than
# the ceiling and requires the measurement to report it as over, and
# a second pair whose gap is zero and requires the measurement to
# report zero.
#
# EXIT COLES, following the house convention:
#   0  measured, and the measurement held
#   1  measured, and the measurement did not hold
#   3  nothing was measured - unknown, not pass

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok() { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

# The ceiling: the number of dispatcher commands that the normative
# catalog does not document. It may fall and may never rise.
#
# MEASURED 2026-11-01: 21. The spec carries 18 command rows and the
# dispatcher answers 39 names.
#
# This is a NEW ceiling: the promise it bounds was never measured
# before, and the number it starts at is the number the tree has
# today. A raise would need a recorded reason, exactly like every
# other ceiling in this directory.
CEILING_GAP=21

SPEC="${MATH_CODING_SPEC:-spec/semantics.md}"
DISPATCHER="${MATH_CODING_DISPATCHER:-bin/Mathc.ml}"

# measure <spec> <dispatcher>: prints
#   gap=<n>
#   undocumented=<name> <name> ...
measure() {
  python3 - "$1" "$2" <<'PY'
import re
import sys

spec_path, dispatcher_path = sys.argv[1], sys.argv[2]

try:
    spec = open(spec_path, encoding="utf-8").read()
except OSError as exc:
    print("unknown the spec %s cannot be read (%s)" % (spec_path, exc))
    raise SystemExit(3)

try:
    dispatcher = open(dispatcher_path, encoding="utf-8").read()
except OSError as exc:
    print("unknown the dispatcher %s cannot be read (%s)" % (dispatcher_path, exc))
    raise SystemExit(3)

# The dispatcher: the match arms of `dispatch ()`, and only those.
start = dispatcher.find("let dispatch () =")
end = dispatcher.find("\nlet () =", start)
body = dispatcher[start:end] if start >= 0 and end > start else ""
if not body:
    print("unknown the dispatcher's arms cannot be found in %s" % dispatcher_path)
    raise SystemExit(3)

commands = set(re.findall(r'\| "([a-z][a-z0-9-]*)"', body))
if not commands:
    print("unknown the dispatcher in %s names no command" % dispatcher_path)
    raise SystemExit(3)

# The catalog: the `### \`<command>\`` headings.
rows = set(re.findall(r"^### `([a-z][a-z0-9-]*)", spec, re.M))

undocumented = sorted(commands - rows)
print("gap=%d" % len(undocumented))
print("undocumented=%s" % " ".join(undocumented))
print("documented=%d" % len(rows))
print("dispatched=%d" % len(commands))
PY
}

# --- 1. the real corpus -------------------------------------------------
measured="$(measure "$SPEC" "$DISPATCHER")"
case "$measured" in
unknown*)
  ok "$measured -- nothing was measured, and nothing measured is not zero"
  echo
  echo "spec-cli-catalog-gap: SKIPPED (nothing was measured - unknown, not pass)"
  exit 3
  ;;
esac

number() { printf '%s\n' "$measured" | sed -n "s/^$1=//p" | head -1; }
gap="$(number gap)"
documented="$(number documented)"
dispatched="$(number dispatched)"
undocumented="$(number undocumented)"

if [ -z "$gap" ]; then
  bad "the measurement is unreadable -- nothing was measured, and nothing measured is not zero"
  echo
  echo "spec-cli-catalog-gap: SKIPPED (nothing was measured - unknown, not pass)"
  exit 3
fi

printf 'ok: the normative catalog documents %s of the %s commands the dispatcher answers\n' \
  "$documented" "$dispatched"
if [ "$gap" -le "$CEILING_GAP" ]; then
  ok "dispatcher commands with no normative row: $gap (ceiling $CEILING_GAP)"
else
  bad "dispatcher commands with no normative row: $gap EXCEEDS the ceiling $CEILING_GAP - the CLI grew and the spec did not"
fi
if [ -n "$undocumented" ]; then
  printf '     the undocumented ones are: %s\n' "$undocumented"
fi

# --- 2. NEGATIVE CONTROL ------------------------------------------------
# (a) a pair whose gap is larger than the ceiling: the measurement has
#     to report it as over.
control="$(mktemp -d)"
trap 'rm -rf "$control"' EXIT

{
  echo 'let dispatch () ='
  echo '  match Sys.argv.(1) with'
  i=0
  while [ "$i" -lt 40 ]; do
    echo "  | \"control-command-$i\" -> do_nothing ()"
    i=$((i + 1))
  done
  echo '  | other -> exit 2'
  echo 'let () = dispatch ()'
} > "$control/dispatcher.ml"
printf '# synthetic spec\n\n### `control-command-0`\n\ntext\n' > "$control/spec.md"

control_out="$(measure "$control/spec.md" "$control/dispatcher.ml")"
control_gap="$(printf '%s\n' "$control_out" | sed -n 's/^gap=//p' | head -1)"
if [ "$control_gap" = "39" ] && [ "$control_gap" -gt "$CEILING_GAP" ]; then
  ok "negative control: a synthetic corpus measures $control_gap undocumented commands, over the ceiling $CEILING_GAP"
else
  bad "negative control: the synthetic corpus measured '$control_gap' undocumented commands (expected 39, over the ceiling $CEILING_GAP) - the measurement does not measure the gap"
fi

# (b) a pair whose gap is zero: the measurement has to report zero, so
#     the control above is not the measurement always failing.
{
  echo 'let dispatch () ='
  echo '  match Sys.argv.(1) with'
  echo '  | "control-command-0" -> do_nothing ()'
  echo '  | other -> exit 2'
  echo 'let () = dispatch ()'
} > "$control/dispatcher-full.ml"
printf '# synthetic spec\n\n### `control-command-0`\n\ntext\n' > "$control/spec-full.md"

full_out="$(measure "$control/spec-full.md" "$control/dispatcher-full.ml")"
full_gap="$(printf '%s\n' "$full_out" | sed -n 's/^gap=//p' | head -1)"
if [ "$full_gap" = "0" ]; then
  ok "negative control: a synthetic corpus whose catalog covers its dispatcher measures zero"
else
  bad "negative control: the synthetic corpus measured '$full_gap' undocumented commands (expected 0) - the measurement counts something else"
fi

# (c) a spec that cannot be read is unknown, not zero.
missing_out="$(measure "$control/does-not-exist.md" "$control/dispatcher.ml")"
case "$missing_out" in
unknown*) ok "negative control: a spec that cannot be read answers unknown, not zero" ;;
*) bad "negative control: a spec that cannot not be read answered with a number" ;;
esac

echo
if [ "$fail" -eq 0 ]; then
  echo "spec-cli-catalog-gap: PASS"
  exit 0
fi
echo "spec-cli-catalog-gap: FAIL"
exit 1
