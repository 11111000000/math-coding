#!/bin/sh
set -eu

resolve_command() {
  command -v "$1" 2>/dev/null || printf '%s\n' "$1"
}

mathc="$(resolve_command "${MATHC:-mathc}")"
stand="$(resolve_command "${MATHC_STAND:-mathc-stand}")"
work="$(mktemp -d "${TMPDIR:-/tmp}/mathc-onboarding.XXXXXX")"
trap 'rm -rf "$work"' EXIT HUP INT TERM
source_changed_marker="source changed"

fail() {
  printf 'agent onboarding: %s\n' "$1" >&2
  exit 1
}

[ -x "$mathc" ] || fail "MATHC is not executable: $mathc"
[ -x "$stand" ] || fail "MATHC_STAND is not executable: $stand"

plain="$work/plain"
git init -q "$plain"
"$mathc" --root "$plain" adopt > "$work/plain-adopt.json"
grep -F '"sources": []' "$work/plain-adopt.json" >/dev/null || fail "no-ADR adoption is not read-only"
"$mathc" --root "$plain" init
"$mathc" --root "$plain" goal "the subject is expected" subject.txt owner
printf 'expected\n' > "$plain/subject.txt"
"$mathc" --root "$plain" add sample "the subject is expected" subject.txt "not expected" fact \
  --requirement "verifier:grep -q expected subject.txt" \
  --control "printf broken > subject.txt"
"$mathc" --root "$plain" run
"$mathc" --root "$plain" map > "$work/plain-map.txt"
grep -F 'green' "$work/plain-map.txt" >/dev/null || fail "no-ADR project is not green"
grep -F 'holds' "$work/plain-map.txt" >/dev/null || fail "no-ADR claim does not hold"
"$mathc" --root "$plain" install
"$mathc" --root "$plain" map > "$work/plain-installed-map.txt"
grep -F 'uncovered: 0 file(s)' "$work/plain-installed-map.txt" >/dev/null \
  || fail "generated agent page was reported as uncovered"
"$mathc" --root "$plain" doctor > "$work/plain-doctor.txt"
"$stand" "$plain" \
  --human-minutes 1 --agent-tokens 100 --person-minute-cost 1 \
  --machine-second-cost 0.1 --token-cost 0.01 --defect-cost 100 > "$work/plain-stand.txt"
grep -F 'criterion: not computable - no defect was caught' "$work/plain-stand.txt" >/dev/null \
  || fail "stand did not preserve the criterion boundary"
printf 'no-ADR onboarding: PASS\n'

madr="$work/madr"
git init -q "$madr"
mkdir -p "$madr/docs/adr"
cat > "$madr/docs/adr/0001-expected.md" <<'EOF'
# Keep the expected subject

## Decision outcome

The subject must stay expected.
EOF
before="$(sha256sum "$madr/docs/adr/0001-expected.md")"
"$mathc" --root "$madr" adopt > "$work/madr-adopt.json"
grep -F '"path": "docs/adr"' "$work/madr-adopt.json" >/dev/null || fail "MADR directory was not detected"
"$mathc" --root "$madr" import-adr docs/adr/0001-expected.md > "$work/madr-draft.json"
grep -F 'The subject must stay expected.' "$work/madr-draft.json" >/dev/null \
  || fail "MADR decision text was not preserved"
grep -F '"requirements": []' "$work/madr-draft.json" >/dev/null \
  || fail "MADR import activated a claim"
after="$(sha256sum "$madr/docs/adr/0001-expected.md")"
[ "$before" = "$after" ] || fail "MADR import changed its source"
"$mathc" --root "$madr" init
"$mathc" --root "$madr" goal "the ADR requirement stays implemented" subject.txt owner
printf 'expected\n' > "$madr/subject.txt"
"$mathc" --root "$madr" add storage "the ADR requirement stays implemented" subject.txt "the ADR is contradicted" fact \
  --requirement "verifier:grep -q expected subject.txt" \
  --control "printf broken > subject.txt" \
  --source docs/adr/0001-expected.md
"$mathc" --root "$madr" run
"$mathc" --root "$madr" map > "$work/madr-green.txt"
grep -F 'green' "$work/madr-green.txt" >/dev/null || fail "MADR project is not green"
printf '\nThe decision was reviewed in the onboarding pilot.\n' >> "$madr/docs/adr/0001-expected.md"
if "$mathc" --root "$madr" map > "$work/madr-changed-map.txt" 2>&1; then
  fail "changed ADR left a green verdict"
else
  code=$?
  [ "$code" -eq 3 ] || fail "changed ADR produced exit $code instead of unknown"
fi
grep -F "$source_changed_marker" "$work/madr-changed-map.txt" >/dev/null \
  || fail "changed ADR was not marked as changed"
"$mathc" --root "$madr" re-evaluate > "$work/madr-pending.json"
grep -F 'storage' "$work/madr-pending.json" >/dev/null \
  || fail "changed ADR was not queued for re-evaluation"
"$mathc" --root "$madr" next > "$work/madr-next.txt"
grep -F 'review-source storage' "$work/madr-next.txt" >/dev/null \
  || fail "next did not route the source review"
"$mathc" --root "$madr" review-source storage --by owner --reason "reviewed the changed ADR in the onboarding pilot"
if "$mathc" --root "$madr" map > "$work/madr-reviewed-map.txt" 2>&1; then
  fail "source review skipped fresh verification"
else
  code=$?
  [ "$code" -eq 3 ] || fail "reviewed ADR produced exit $code instead of unknown"
fi
grep -F 'outdated' "$work/madr-reviewed-map.txt" >/dev/null \
  || fail "source review did not invalidate old evidence"
if grep -F "$source_changed_marker" "$work/madr-reviewed-map.txt" >/dev/null; then
  fail "source review did not update the source digest"
fi
"$mathc" --root "$madr" run
"$mathc" --root "$madr" map > "$work/madr-final-map.txt"
grep -F 'green' "$work/madr-final-map.txt" >/dev/null || fail "reviewed MADR project is not green"
"$mathc" --root "$madr" re-evaluate > "$work/madr-final-pending.json"
if grep -F 'storage' "$work/madr-final-pending.json" >/dev/null; then
  fail "reviewed MADR project still requires re-evaluation"
fi
"$mathc" --root "$madr" install
"$mathc" --root "$madr" doctor > "$work/madr-doctor.txt"
printf 'MADR onboarding and source review: PASS\n'
