#!/bin/sh
# Every negative control tampers one thing and requires the site check to
# reject it. The controls of the map share one built site: they doctor
# copies of map.json, not the published page, and they never rebuild. The
# controls of the pages copy the built site, break one page of the copy,
# and never touch the published one. A tamper that the check does not
# catch fails the whole script.
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

# The check of the pages, run against a copy of the built site.
expect_fail_pages () {
  label=$1
  copy=$2
  if sh "$ROOT/site/check.sh" --pages "$copy" >"$WORK/err" 2>&1; then
    echo "negative-control: the check passed on a broken site ($label)" >&2
    cat "$WORK/err" >&2
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

# The controls of the pages: one copy of the built site, one thing broken
# in each copy.
python3 - "$DIST" "$WORK" <<'PY'
import os, re, shutil, sys

dist, work = sys.argv[1], sys.argv[2]


def copy(name):
    """A copy of the built site: the published one is never touched."""
    target = os.path.join(work, name)
    shutil.rmtree(target, ignore_errors=True)
    shutil.copytree(dist, target)
    return target


def patch(path, pattern, replacement):
    """Break one thing of one page, and say so when there is nothing to
    break: a control that breaks nothing would pass for the wrong reason."""
    with open(path, encoding="utf-8") as handle:
        page = handle.read()
    page, hits = re.subn(pattern, replacement, page, count=1, flags=re.S)
    if hits == 0:
        raise SystemExit(
            "negative-control: %s does not carry %s" % (path, pattern))
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(page)


# The Russian page loses a section heading.
ru = copy("ru-heading")
patch(os.path.join(ru, "index.ru.html"), r"<h2>.*?</h2>", "")

# The home page loses the tool of the map.
tool = copy("no-tool")
patch(os.path.join(tool, "index.html"),
      r"<span>[^<>]{1,40}: mathc &middot; <code>[0-9a-f]{8,}</code></span>", "")

# A published page loses its canonical address.
meta = copy("no-canonical")
patch(os.path.join(meta, "index.html"), r'<link rel="canonical"[^>]*>\n', "")

# The legend loses the reason of one state.
legend = copy("no-reason")
patch(os.path.join(legend, "methodology.html"),
      r'(<tr><td><span class="v-pill v-[a-z-]+">[^<]*</span></td><td>)[^<]*(</td>)',
      r"\1\2")

# The navigation names a page that the site does not have.
extra = copy("extra-page")
patch(os.path.join(extra, "index.html"), r'(<div class="nav-inner">)',
      r'\1<a class="nav-link" href="nowhere.html">nowhere</a>')

# The navigation misses a page that the site has.
missing = copy("missing-page")
patch(os.path.join(missing, "index.html"),
      r'<a class="nav-link" href="measurements.html">[^<]*</a>', "")
PY

expect_fail_pages "the Russian page lost a section heading" "$WORK/ru-heading"
expect_fail_pages "the home page lost the tool of the map" "$WORK/no-tool"
expect_fail_pages "the legend lost the reason of a state" "$WORK/no-reason"
expect_fail_pages "the navigation named a page that is not there" \
  "$WORK/extra-page"
expect_fail_pages "the navigation missed a page that is there" \
  "$WORK/missing-page"

"$ROOT/_build/default/site/render.exe" check "$ROOT" "$DIST" "$MAP"
echo "negative-control: every tampered map and every broken page was rejected"
