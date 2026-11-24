#!/bin/sh
# Verifier for the site-render claim: rebuild the site and confirm that
# the published pages show exactly the map of `mathc map --json`, that every
# claim of spec.json is present with its state, that the canonical
# methodology is delivered, that every local link resolves, that the two
# languages carry the same shape, and that the site names its own pages.
#
# The check has two modes:
#   sh site/check.sh             build the site, check it, run the controls
#   sh site/check.sh --pages DIR check only the pages of DIR, without a build
# The second mode is what the negative controls use: they copy the built
# site, break one page of the copy, and require this check to reject it.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# The shape of the published pages.
#
# The English page and the Russian page of one page are written by hand,
# and nothing notices when one of them loses a section, a row or a step.
# The text of the two is translated, so the check compares the shape and
# not the words: the same headings in the same order, the same number of
# table rows, the same number of list items.
pages_check () {
  python3 - "$1" <<'PY'
import json
import os
import re
import sys
from html.parser import HTMLParser

# The pairs of the site: the English page and the Russian page of the same
# page. The pages of the claims are written by one template each, so they
# cannot drift apart and they are not checked here.
PAIRS = [
    ("index", "index.html", "index.ru.html"),
    ("methodology", "methodology.html", "methodology.ru.html"),
    ("workflow", "workflow.html", "workflow.ru.html"),
    ("interfaces", "interfaces.html", "interfaces.ru.html"),
    ("measurements", "measurements.html", "measurements.ru.html"),
]

# The states and the verdicts the tool can report (lib/domain.ml). The
# legend of the methodology page must name every one of them and must say
# why each of them means what it means.
STATES = ["holds", "refuted", "inconclusive", "outdated", "never-checked",
          "waived"]
VERDICTS = ["green", "red", "unknown", "vacant"]

HEADINGS = ("h1", "h2", "h3", "h4", "h5", "h6")

NAV_BLOCK = re.compile(r'<div class="nav-inner">(.*?)</div>', re.S)
HREF = re.compile(r'href="([^"]+)"')
LEGEND_ROW = re.compile(
    r'<tr><td><span class="v-pill v-([a-z-]+)">([^<]*)</span></td><td>(.*?)</td></tr>',
    re.S)
TAGS = re.compile(r"<[^>]+>")


class Shape(HTMLParser):
    """The shape of a page: its headings, its tables and its lists."""

    def __init__(self):
        HTMLParser.__init__(self, convert_charrefs=True)
        self.headings = []
        self.tables = []
        self.lists = []
        self._heading = None
        self._tables = []
        self._lists = []

    def handle_starttag(self, tag, attrs):
        if tag in HEADINGS:
            self._heading = [int(tag[1]), []]
        elif tag == "table":
            self._tables.append(0)
        elif tag == "tr":
            if self._tables:
                self._tables[-1] += 1
        elif tag in ("ul", "ol"):
            self._lists.append(0)
        elif tag == "li":
            if self._lists:
                self._lists[-1] += 1

    def handle_endtag(self, tag):
        if tag in HEADINGS:
            if self._heading:
                level, buffer = self._heading
                self.headings.append((level, " ".join("".join(buffer).split())))
                self._heading = None
        elif tag == "table":
            if self._tables:
                self.tables.append(self._tables.pop())
        elif tag in ("ul", "ol"):
            if self._lists:
                self.lists.append(self._lists.pop())

    def handle_data(self, data):
        if self._heading:
            self._heading[1].append(data)


def read(dist, name):
    with open(os.path.join(dist, name), encoding="utf-8") as handle:
        return handle.read()


def shape(dist, name):
    parser = Shape()
    parser.feed(read(dist, name))
    return parser


def wording(heading):
    if heading is None:
        return "missing"
    return "%r (h%d)" % (heading[1], heading[0])


def pair_problems(pair, en, ru):
    """The differences of shape between the two pages of one pair."""
    problems = []
    for index in range(max(len(en.headings), len(ru.headings))):
        left = en.headings[index] if index < len(en.headings) else None
        right = ru.headings[index] if index < len(ru.headings) else None
        if left is None or right is None or left[0] != right[0]:
            problems.append(
                "the pair %s: the heading %d differs: en %s, ru %s"
                % (pair, index + 1, wording(left), wording(right)))
            break
    for index in range(max(len(en.tables), len(ru.tables))):
        left = en.tables[index] if index < len(en.tables) else None
        right = ru.tables[index] if index < len(ru.tables) else None
        if left is None or right is None or left != right:
            problems.append(
                "the pair %s: the table %d differs: en %s rows, ru %s rows"
                % (pair, index + 1, left if left is not None else "no",
                   right if right is not None else "no"))
            break
    for index in range(max(len(en.lists), len(ru.lists))):
        left = en.lists[index] if index < len(en.lists) else None
        right = ru.lists[index] if index < len(ru.lists) else None
        if left is None or right is None or left != right:
            problems.append(
                "the pair %s: the list %d differs: en %s items, ru %s items"
                % (pair, index + 1, left if left is not None else "no",
                   right if right is not None else "no"))
            break
    return problems


def normalise(name):
    """The name of the page behind a name: index.ru.html is index.html."""
    if name.endswith(".ru.html"):
        return name[:-len(".ru.html")] + ".html"
    return name


def sitemap_problems(dist):
    """The navigation is the map of the site: it must name every page of
    the site, and it must not name a page that is not there."""
    problems = []
    pages = [name for name in sorted(os.listdir(dist))
             if name.endswith(".html") and name != "404.html"
             and os.path.isfile(os.path.join(dist, name))]
    expected = set(normalise(name) for name in pages)
    for name in pages:
        block = NAV_BLOCK.search(read(dist, name))
        if not block:
            problems.append("the page %s has no navigation" % name)
            continue
        targets = []
        for href in HREF.findall(block.group(1)):
            if href.startswith(("http://", "https://", "//", "#", "mailto:")):
                continue
            targets.append(href)
        for target in targets:
            if not os.path.exists(os.path.join(dist, target)):
                problems.append(
                    "the navigation of %s names %s, which the site does not have"
                    % (name, target))
        found = set(normalise(target) for target in targets)
        for missed in sorted(expected - found):
            problems.append(
                "the navigation of %s does not name %s, which the site has"
                % (name, missed))
    return problems


def tool_problems(dist, map_document):
    """The home pages must show the tool of the map, not a name of it."""
    tool = map_document.get("tool")
    if not tool:
        return []
    pattern = re.compile(
        r'<span>[^<>]{1,40}: ' + re.escape(tool.get("class", "")) +
        r' &middot; <code>' + re.escape(tool.get("fingerprint", "")) +
        r'</code></span>')
    problems = []
    for name in ("index.html", "index.ru.html"):
        if not os.path.isfile(os.path.join(dist, name)):
            continue
        if not pattern.search(read(dist, name)):
            problems.append(
                "the page %s does not show the tool of the map (%s)"
                % (name, tool.get("class", "")))
    return problems


def legend_problems(dist):
    """The legend must name every state of the tool and say why."""
    problems = []
    for name in ("methodology.html", "methodology.ru.html"):
        path = os.path.join(dist, name)
        if not os.path.isfile(path):
            continue
        rows = LEGEND_ROW.findall(read(dist, name))
        if not rows:
            problems.append("the page %s has no legend of the states" % name)
            continue
        named = [state for state, _, _ in rows]
        for state in STATES + VERDICTS:
            if state not in named:
                problems.append(
                    "the legend of %s does not name the state %s" % (name, state))
        for state, _, reason in rows:
            if not TAGS.sub("", reason).strip():
                problems.append(
                    "the legend of %s gives no reason for %s" % (name, state))
    return problems


def main():
    dist = sys.argv[1]
    problems = []
    for pair, en_name, ru_name in PAIRS:
        if not os.path.isfile(os.path.join(dist, en_name)) or \
           not os.path.isfile(os.path.join(dist, ru_name)):
            problems.append("the pair %s: a page of the pair is missing" % pair)
            continue
        problems.extend(pair_problems(pair, shape(dist, en_name),
                                      shape(dist, ru_name)))
    problems.extend(sitemap_problems(dist))
    map_path = os.path.join(dist, "map.json")
    if os.path.isfile(map_path):
        with open(map_path, encoding="utf-8") as handle:
            problems.extend(tool_problems(dist, json.load(handle)))
    else:
        problems.append("the site has no map to show")
    problems.extend(legend_problems(dist))
    for problem in problems:
        print("check: %s" % problem)
    if problems:
        return 1
    print("check: the two languages carry the same shape, the site names its "
          "own pages, and the legend names every state")
    return 0


sys.exit(main())
PY
}

if [ "${1:-}" = "--pages" ]; then
  pages_check "$2"
  exit 0
fi

sh "$ROOT/site/build.sh" >/dev/null
"$ROOT/_build/default/site/render.exe" check "$ROOT" "$ROOT/site/dist" \
  "$ROOT/site/dist/map.json"
pages_check "$ROOT/site/dist"
sh "$ROOT/site/negative-controls.sh"
