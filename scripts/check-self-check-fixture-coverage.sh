#!/usr/bin/env bash
# scripts/check-self-check-fixture-coverage.sh
#
# Acceptance verifier for
#   decisions/audit-0.0.21-fixes.yaml :: self-check-pass-fixture-covers-all
#
# READ-ONLY BY CONSTRUCTION. This script opens no write handle outside
# stdout/stderr: it reads `mathc packages --format=json` and the
# committed fixture files, and exits. Its predecessor for this
# obligation was scripts/regenerate-self-check-fixture.sh, which both
# GENERATED the fixture and declared it correct — a claim that is true
# by construction rather than by measurement, attached to a step that
# emptied a 765-file committed evidence store while reporting pass.
# See decisions/self-check-fixture-coverage-honest-2026-10.yaml@1.
#
# The claim under test, verbatim from that obligation:
#
#   tests/fixtures/self-check-pass/attestations/ contains a pass
#   attestation for every (decision_id, obligation_id) pair enumerated
#   by `mathc packages --format=json`, with the single exception of
#   `portable-linux-musl`, which is bound by a waiver.
#
# So the check is a set comparison against the same enumeration the
# builder used, plus a per-file content check, because a file that
# exists but says something else does not cover anything:
#
#   1. every required pair has a fixture file named
#      <decision>-<obligation>.json;
#   2. that file parses as JSON;
#   3. its `result` is "pass";
#   4. its `subject.decision` / `subject.obligation` name the pair the
#      file name claims — a renamed or copied file is not coverage;
#   5. no fixture file names a pair the kernel no longer enumerates
#      (stale coverage for a retired obligation is drift; the builder
#      deletes such files on its next run, so leaving one is never a
#      deliberate state).
#
# `portable-linux-musl` is exempt in (1) only: the obligation's claim
# names its waiver as the single exception. Exempt files that exist
# are still counted.
#
# EXIT: 0 only when every required pair is covered and every fixture
# file is accounted for. 1 otherwise. 2 on a harness failure (mathc or
# python3 unavailable, unreadable enumeration) — a check that could not
# run must not report the same verdict as one that ran.
#
# NOTE ON CURRENT STATE. At the commit this script was introduced, the
# committed fixture held 186 files against 812 enumerated pairs (805
# required after the portable-linux-musl exemption), so 627 required
# pairs were uncovered and this verifier EXITS 1. That is the honest
# reading of the claim, not a regression introduced here: the
# obligation read `pass` before only because its verifier had just
# rewritten the fixture to satisfy it. Closing the gap is separate work
# — see the decision's `counterexample` and `assumptions`.

set -uo pipefail
cd "$(dirname "$0")/.."

FIXTURE_DIR="tests/fixtures/self-check-pass/attestations"
EXEMPT_DECISION="portable-linux-musl"

MATHC="mathc"
if [ -x "_build/install/default/bin/mathc" ]; then
  MATHC="_build/install/default/bin/mathc"
fi

if ! command -v "$MATHC" >/dev/null 2>&1 && [ ! -x "$MATHC" ]; then
  echo "self-check-fixture-coverage: cannot run: mathc not found" >&2
  exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "self-check-fixture-coverage: cannot run: python3 not found" >&2
  exit 2
fi
if [ ! -d "$FIXTURE_DIR" ]; then
  echo "self-check-fixture-coverage: FAIL: fixture dir $FIXTURE_DIR missing" >&2
  exit 1
fi

CHECK_PY=$(mktemp)
PKGS=$(mktemp)
trap 'rm -f "$CHECK_PY" "$PKGS"' EXIT

cat > "$CHECK_PY" <<'PY_EOF'
import json, os, sys

fixture_dir = os.environ["CHECK_FIXTURE_DIR"]
exempt = os.environ["CHECK_EXEMPT_DECISION"]

try:
    with open(os.environ["CHECK_PKGS"], encoding="utf-8") as fh:
        d = json.load(fh)
except Exception as e:  # enumeration unparseable => harness failure
    print(f"self-check-fixture-coverage: cannot run: bad packages JSON: {e}",
          file=sys.stderr)
    sys.exit(2)

pairs = [(dec["decision_id"], ob["id"])
         for dec in d["decisions"] for ob in dec["obligations"]]
enumerated = set(pairs)
required = {p for p in enumerated if p[0] != exempt}
exempted = enumerated - required

files = sorted(f for f in os.listdir(fixture_dir) if f.endswith(".json"))

missing, malformed, wrong_result, mislabelled = [], [], [], []
covered = set()
for decision, obligation in sorted(required):
    name = f"{decision}-{obligation}.json"
    path = os.path.join(fixture_dir, name)
    if not os.path.isfile(path):
        missing.append(name)
        continue
    try:
        with open(path, encoding="utf-8") as fh:
            att = json.load(fh)
    except Exception as e:
        malformed.append(f"{name}: {e}")
        continue
    if att.get("result") != "pass":
        wrong_result.append(f"{name}: result={att.get('result')!r}")
        continue
    subject = att.get("subject") or {}
    if (subject.get("decision"), subject.get("obligation")) != (decision, obligation):
        mislabelled.append(
            f"{name}: subject=({subject.get('decision')!r}, "
            f"{subject.get('obligation')!r})")
        continue
    covered.add((decision, obligation))

# (5) fixture files naming a pair the kernel no longer enumerates.
expected_names = {f"{decision}-{obligation}.json" for decision, obligation in enumerated}
stale = sorted(f for f in files if f not in expected_names)
# Exact, not a string prefix: the decision `portable-linux-musl` and the
# unrelated `portable-linux-musl-retirement-record-2026-10` share a
# prefix, so startswith() would count the latter as exempt evidence.
exempt_names = {f"{decision}-{obligation}.json" for decision, obligation in exempted}
exempt_present = [f for f in files if f in exempt_names]

print(f"self-check-fixture-coverage: enumerated pairs = {len(enumerated)} "
      f"({len(required)} required, {len(exempted)} exempt under {exempt})")
print(f"self-check-fixture-coverage: fixture files      = {len(files)}")
print(f"self-check-fixture-coverage: required covered   = {len(covered)}")
if exempt_present:
    print(f"self-check-fixture-coverage: exempt files present = "
          f"{len(exempt_present)} (not required)")

problems = []
for label, items, summary in (
    ("MISSING", missing, "required pair(s) have no fixture file"),
    ("MALFORMED", malformed, "fixture file(s) are not valid JSON"),
    ("NOT-PASS", wrong_result, "fixture file(s) are not result=pass"),
    ("MISLABEL", mislabelled, "fixture file(s) name a different subject"),
    ("STALE", stale, "fixture file(s) name a pair the kernel no longer enumerates"),
):
    if not items:
        continue
    problems.append(f"{len(items)} {summary}")
    for line in items[:10]:
        print(f"  {label:<9} {line}", file=sys.stderr)
    if len(items) > 10:
        print(f"  ... and {len(items) - 10} more", file=sys.stderr)

if problems:
    for p in problems:
        print(f"self-check-fixture-coverage: FAIL: {p}", file=sys.stderr)
    sys.exit(1)

print("self-check-fixture-coverage: every enumerated pair is covered by a "
      "result=pass fixture naming that exact subject")
PY_EOF

if ! "$MATHC" packages --format=json > "$PKGS" 2>/dev/null || [ ! -s "$PKGS" ]; then
  echo "self-check-fixture-coverage: cannot run: \`mathc packages\` produced no output" >&2
  exit 2
fi

CHECK_FIXTURE_DIR="$FIXTURE_DIR" \
CHECK_EXEMPT_DECISION="$EXEMPT_DECISION" \
CHECK_PKGS="$PKGS" \
  python3 "$CHECK_PY"
exit $?
