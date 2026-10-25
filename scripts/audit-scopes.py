#!/usr/bin/env python3
"""scripts/audit-scopes.py — how broad is each decision's scope?

WHY THIS TOOL EXISTS.

A decision's `scope.paths` names the files its attestation's
`materials_digest` is computed over. Change a file that a decision's
scope names, and that decision's attestation goes stale: the digest
no longer describes the tree the attestation claims to describe, and
the decision has to be re-signed.

So the cost of touching a file is the number of decisions whose
scope covers it. Measured on 2026-10-25:

    one edit to bin/Mathc.ml  ->  182 of the corpus's 245 decisions
                                 go stale, and a full re-signing
                                 (232 s) becomes necessary.

That breadth is the reason the verification cycle is a treadmill.
Most of it is accidental: `spec/**` names 142 scopes, `lib/**` names
100, and a scope that says "everything under lib" says nothing about
which file the obligation actually depends on.

WHAT THIS TOOL MEASURES.

  * the paths that appear in scopes, and how many decisions name each;
  * the INVALIDATION BREADTH of every tracked file: how many
    decisions' scopes would match if exactly that file changed. This
    is the number that matters - it is the price of touching the
    file;
  * the same breadth for a hypothetical change to a whole directory,
    which is what a `lib/**` scope really means.

THE GLOB RULES ARE THE KERNEL'S.

The matching here is a re-implementation of `Gate.glob_match` and
`Gate.segment_match` (lib/gate.ml), so the number this tool prints
is the number the gate will actually produce. `**` matches any
number of path segments; within a segment, `*` matches any run of
characters and the literal part before the last `*` must match the
start, the literal part after the last `*` must match the end.

THE PARSE IS NARROW.

`[ \\t]` for indentation, never `\\s`: `\\s` matches a newline, so
`^\\s+-\\s+id:` splits on a nested `- id:` line and on blank lines,
and the scope of one decision is then attributed to another. That bug
shipped once and produced false accusations. The census's own parse
is narrow for the same reason, and `extract_scope_paths` in
lib/memory.ml is the kernel's authority for what a scope IS.

USAGE
    scripts/audit-scopes.py [--decisions DIR] [--out FILE]
                            [--top N] [--json]
"""

import argparse
import collections
import json
import os
import re
import subprocess
import sys


# --- the kernel's glob rules (lib/gate.ml) --------------------------------


def segment_match(pat, s):
    parts = pat.split("*")
    if not parts:
        return True
    last = parts[-1]
    n, m = len(last), len(s)
    if not (m >= n and s[m - n:] == last):
        return False
    rest = s[: m - n] if n else s
    for p in parts[:-1]:
        n2 = len(p)
        if n2 == 0:
            continue
        if not (len(rest) >= n2 and rest[:n2] == p):
            return False
        rest = rest[n2:]
    return True


def glob_match(pattern, path):
    ps = pattern.split("/")
    qs = path.split("/")

    def go(ps, qs):
        if not ps and not qs:
            return True
        if ps and ps[0] == "**":
            rest = ps[1:]
            if go(rest, qs):
                return True
            return bool(qs) and go(ps, qs[1:])
        if ps and qs and segment_match(ps[0], qs[0]):
            return go(ps[1:], qs[1:])
        return False

    return go(ps, qs)


# --- the corpus ------------------------------------------------------------


def is_top_level(line):
    if not line:
        return False
    c = line[0]
    if c in " \t#":
        return False
    if line == "---":
        return False
    return True


def leading_spaces(line):
    n = 0
    while n < len(line) and line[n] in " \t":
        n += 1
    return n


def extract_scope_paths(text):
    """The scope paths of one decision, per lib/memory.ml::extract_scope_paths."""
    lines = text.split("\n")

    def find_scope(lines):
        for i, line in enumerate(lines):
            if is_top_level(line):
                if line.strip() == "scope:":
                    return collect_paths(lines[i + 1 :])
                continue
        return []

    def collect_paths(lines):
        out = []
        in_paths = False
        for line in lines:
            if is_top_level(line):
                break
            indent = leading_spaces(line)
            trimmed = line.strip()
            if indent == 2 and trimmed == "paths:":
                in_paths = True
                continue
            if in_paths:
                if indent <= 2 and trimmed.startswith("-"):
                    continue
                if trimmed.startswith("- "):
                    out.append(trimmed[2:].strip().strip("\"'"))
        return out

    return find_scope(lines)


def decision_id(text):
    m = re.search(r"^id:[ \t]*(\S+)", text, re.M)
    return m.group(1) if m else None


def load_corpus(decisions_dir):
    out = {}
    for name in sorted(os.listdir(decisions_dir)):
        if not name.endswith((".yaml", ".yml")):
            continue
        path = os.path.join(decisions_dir, name)
        try:
            text = open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        did = decision_id(text)
        if not did:
            continue
        out[did] = extract_scope_paths(text)
    return out


def tracked_files():
    try:
        res = subprocess.run(
            ["git", "ls-files"], capture_output=True, text=True
        )
        return [f for f in res.stdout.split("\n") if f]
    except OSError:
        return []


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--decisions", default="decisions")
    ap.add_argument("--out", default=None)
    ap.add_argument("--top", type=int, default=20)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    corpus = load_corpus(args.decisions)
    files = tracked_files()

    # Which decisions cover which file.
    covered = collections.defaultdict(set)  # file -> {decision}
    pattern_count = collections.Counter()  # pattern -> decisions
    for did, paths in corpus.items():
        for p in paths:
            pattern_count[p] += 1
        for f in files:
            if any(glob_match(p, f) for p in paths):
                covered[f].add(did)

    breadth = {f: len(d) for f, d in covered.items()}
    ranked_files = sorted(breadth.items(), key=lambda kv: (-kv[1], kv[0]))
    ranked_patterns = pattern_count.most_common()

    # How many decisions a change to a whole DIRECTORY would touch.
    dir_breadth = collections.Counter()
    for f, d in covered.items():
        parts = f.split("/")
        for i in range(1, len(parts) + 1):
            dir_breadth["/".join(parts[:i])] += len(d)

    if args.json:
        payload = {
            "decisions": len(corpus),
            "tracked_files": len(files),
            "patterns": [{"path": p, "decisions": n} for p, n in ranked_patterns],
            "file_breadth": [
                {"file": f, "decisions": n} for f, n in ranked_files[: args.top]
            ],
        }
        text = json.dumps(payload, indent=2, sort_keys=True)
        if args.out:
            open(args.out, "w", encoding="utf-8").write(text + "\n")
            print("wrote %s" % args.out, file=sys.stderr)
        else:
            print(text)
        return 0

    print("decisions with a scope: %d" % len(corpus))
    print("tracked files:          %d" % len(files))
    print()
    print("the %d most expensive FILES to touch" % args.top)
    print("  (decisions whose scope covers the file, and therefore go stale)")
    for f, n in ranked_files[: args.top]:
        print("  %5d  %s" % (n, f))
    print()
    print("the %d most repeated SCOPE PATTERNS" % args.top)
    print("  (decisions that name the pattern)")
    for p, n in ranked_patterns[: args.top]:
        print("  %5d  %s" % (n, p))
    print()
    print("the most expensive DIRECTORIES to touch")
    for d, n in dir_breadth.most_common(10):
        print("  %5d  %s/" % (n, d))
    return 0


if __name__ == "__main__":
    sys.exit(main())
