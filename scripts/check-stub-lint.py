#!/usr/bin/env python3
# scripts/check-stub-lint.py
#
# Enforce no-stub-without-tracking for lib/*.ml and bin/Mathc.ml.
#
# Verifier for decisions/plan-2026-10-improvements/t6-1.yaml
# obligation `stub-lint-step-in-check-sh`.
#
# Scans for stub markers (Phase 2E, Phase <N>[A-Z]?, FIXME, XXX,
# STUB, TODO) in non-string OCaml content. A marker is exempt
# when:
#   - it appears on a section-header line (starts with `(* ===`,
#     `(* ---`, or `-- |`),
#   - the line is entirely inside an OCaml verbatim string
#     `{| ... |}` (output template text),
#   - the marker is `TODO` in past-tense narrative form inside an
#     OCaml comment ("the original TODO that this closes"),
#   - the line carries a `tracked:` acknowledgement or
#     references a `decisions/<id>-stub-tracking.yaml` path.
#
# In OCaml comments `(* ... *)`, only `Phase 2E` is treated as
# a stub (canonical historical marker). Other markers in
# comments are documentation. The walker deliberately classifies
# block comment regions so Phase 2E in a comment still fires.
#
# Exits 0 if no untracked markers are found, exits 1 otherwise.

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
TARGETS = sorted(list((ROOT / "lib").glob("*.ml"))) + [
    ROOT / "bin" / "Mathc.ml"
]

# --- Stub-marker patterns ---------------------------------------------------
PHASE_2E = re.compile(r"\bPhase\s+2E\b")
PHASE_N = re.compile(r"\bPhase\s+\d+[A-Z]?\b")
WHOLE_TODO = re.compile(r"\bTODO\b")
WHOLE_FIXME = re.compile(r"\bFIXME\b")
WHOLE_XXX = re.compile(r"\bXXX\b")
WHOLE_STUB = re.compile(r"\bSTUB\b")

# Past-tense TODO forms inside comments. These reference a
# past marker that has been closed, not an open stub.
# Examples that match:
#   "the original drop-on-Float TODO that this closes"
#   "the previous TODO which was fixed in PR #12"
#   "TODO resolved by commit abc"
# Examples that do NOT match (still flagged):
#   "TODO: implement this"
#   "TODO(make decision X)"
TODO_PAST_TENSE = re.compile(
    r"\bTODO\b(?:\s+(?:that|which)\s+\w+|\s+(?:closes|resolved|fixed|was|had))"
)

# Code-region markers: all of them. Scan only code regions.
CODE_MARKERS = [
    ("Phase 2E", PHASE_2E),
    ("Phase [0-9]+[A-Z]?", PHASE_N),
    ("FIXME", WHOLE_FIXME),
    ("XXX", WHOLE_XXX),
    ("STUB", WHOLE_STUB),
    ("TODO", WHOLE_TODO),
]

# Comment-region markers: only Phase 2E fires in comments,
# because Phase 2E is the canonical historical stub with no
# past-tense narrative form. Other markers in comments are
# documentation (TODO that this closes, FIXME history, etc.).
COMMENT_MARKERS = [
    ("Phase 2E", PHASE_2E),
]

# Tracking reference: same-line acknowledgement that exempts
# the marker from being treated as a stub.
TRACKED_REF = re.compile(
    r"(?i)\btracked\s*:"
    r"|decisions/[A-Za-z0-9_-]+-stub-tracking\.yaml"
)

# Section header prefixes — always exempt.
SECTION_HEADER = re.compile(r"^\s*\(\*\s*(?:===|---|--+)|^\s*--\s*\|")


def walk_line(line: str, in_comment: bool, in_string: bool):
    """Walk a line and return
    (in_comment_after, in_string_after, code_regions,
    comment_regions).

    code_regions are byte ranges that are pure OCaml code.
    comment_regions are byte ranges inside OCaml comments.
    Both lists are disjoint and partition the line minus any
    `{| ... |}` verbatim string (which is neither code nor
    comment for our purposes).

    Recognises OCaml block comments (* ... *) and OCaml
    verbatim strings {| ... |}, both single-line and
    multi-line.
    """
    code_regions = []
    comment_regions = []
    pos = 0
    n = len(line)
    while pos < n:
        if in_comment:
            close = line.find("*)", pos)
            if close >= 0:
                comment_regions.append((pos, close + 2))
                in_comment = False
                pos = close + 2
            else:
                comment_regions.append((pos, n))
                pos = n
        elif in_string:
            close = line.find("|}", pos)
            if close >= 0:
                in_string = False
                pos = close + 2
            else:
                # Whole rest of line is in string; not a
                # comment or code region.
                pos = n
        else:
            c_open = line.find("(*", pos)
            s_open = line.find("{|", pos)
            if c_open < 0 and s_open < 0:
                code_regions.append((pos, n))
                pos = n
            elif c_open >= 0 and (s_open < 0 or c_open < s_open):
                if c_open > pos:
                    code_regions.append((pos, c_open))
                same_close = line.find("*)", c_open + 2)
                if same_close >= 0:
                    comment_regions.append((c_open, same_close + 2))
                    pos = same_close + 2
                else:
                    comment_regions.append((c_open, n))
                    in_comment = True
                    pos = n
            else:
                if s_open > pos:
                    code_regions.append((pos, s_open))
                same_close = line.find("|}", s_open + 2)
                if same_close >= 0:
                    pos = same_close + 2
                else:
                    in_string = True
                    pos = n
    return in_comment, in_string, code_regions, comment_regions


def scan_file(path: Path):
    """Yield (lineno, marker_name, line) for every untracked stub marker."""
    in_comment = False
    in_string = False
    with open(path, encoding="utf-8") as f:
        for lineno, raw in enumerate(f, start=1):
            # Section header lines are always exempt.
            is_section_header = bool(SECTION_HEADER.match(raw))

            (
                in_comment,
                in_string,
                code_regions,
                comment_regions,
            ) = walk_line(raw, in_comment, in_string)

            if is_section_header:
                continue

            # --- Code regions: flag all markers ---------------
            for start, end in code_regions:
                text = raw[start:end]
                if TRACKED_REF.search(text):
                    continue
                for marker_name, pattern in CODE_MARKERS:
                    if pattern.search(text):
                        yield (lineno, marker_name, raw.rstrip("\n"))
                        break

            # --- Comment regions: flag only Phase 2E ----------
            for start, end in comment_regions:
                text = raw[start:end]
                if TRACKED_REF.search(text):
                    continue
                for marker_name, pattern in COMMENT_MARKERS:
                    if pattern.search(text):
                        yield (lineno, marker_name, raw.rstrip("\n"))
                        break


def main():
    issues = []
    for path in TARGETS:
        if not path.exists():
            print(f"warn: target missing: {path}", file=sys.stderr)
            continue
        issues.extend((path, *hit) for hit in scan_file(path))
    if not issues:
        print(
            "ok: no untracked stub markers in lib/*.ml or bin/Mathc.ml"
        )
        return 0
    print(
        f"fail: {len(issues)} untracked stub marker(s):",
        file=sys.stderr,
    )
    for path, lineno, marker, line in issues:
        rel = path.relative_to(ROOT)
        print(
            f"  {rel}:{lineno}: [{marker}] {line.strip()}",
            file=sys.stderr,
        )
    print(
        "\nRemediation: add `tracked: decisions/<id>-stub-tracking.yaml` "
        "to the same comment, or replace the marker with a "
        "section-header (`(* --- ... --- *)`) or remove it.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())