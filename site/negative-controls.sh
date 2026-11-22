#!/bin/sh
# Every negative control tampers one field of the map and requires the site
# check to reject the page. The controls share one built site: they doctor
# copies of map.json, not the published page, and they never rebuild. A
# tamper that the check does not catch fails the whole script.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
DIST="$ROOT/site/dist"
MAP="$DIST/map.json"

if [ ! -f "$MAP" ]; then
  echo "negative-control: the site is not built; run site/build.sh first" >&2
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

expect_fail () {
  label=$1
  map_copy=$2
  if "$ROOT/_build/default/site/render.exe" check "$ROOT" "$DIST" \
       "$map_copy" >/dev/null 2>"$WORK/err"; then
    echo "negative-control: the check passed on a tampered map ($label)" >&2
    exit 1
  fi
}

python3 - "$MAP" "$WORK" <<'PY'
import json, sys

source, work = sys.argv[1], sys.argv[2]
with open(source) as handle:
    map_document = json.load(handle)

verdict = dict(map_document)
verdict["verdict"] = "red" if verdict["verdict"] != "red" else "green"
with open(work + "/verdict.json", "w") as handle:
    json.dump(verdict, handle)

coverage = dict(map_document)
coverage["uncovered"] = list(coverage.get("uncovered", [])) + [
    "site/negative-control/tampered-file"
]
with open(work + "/uncovered.json", "w") as handle:
    json.dump(coverage, handle)

states = json.loads(json.dumps(map_document))
flipped = False
for entry in states["states"]:
    if entry["state"] != "refuted":
        entry["state"] = "refuted"
        flipped = True
        break
if not flipped:
    states["states"][0]["state"] = "holds"
with open(work + "/state.json", "w") as handle:
    json.dump(states, handle)
PY

expect_fail "verdict" "$WORK/verdict.json"
expect_fail "uncovered" "$WORK/uncovered.json"
expect_fail "state" "$WORK/state.json"

"$ROOT/_build/default/site/render.exe" check "$ROOT" "$DIST" "$MAP"
echo "negative-control: every tampered map was rejected"
