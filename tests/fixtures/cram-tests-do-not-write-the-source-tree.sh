#!/usr/bin/env bash
# tests/fixtures/cram-tests-do-not-write-the-source-tree.sh
#
# No cram case may WRITE into the source tree.
#
# WHY. dune runs the three cram directories (tests/cli, tests/mcp,
# tests/scripts) in PARALLEL, and every one of them executes in the
# same checkout. A case that writes into $DUNE_SOURCEROOT therefore
# writes into a resource the other cases are reading at the same
# moment. The symptom is not a diff: the write and the read interleave
# at a speed the transcript cannot show. On 2026-10-27 exactly one
# case wrote into the tree (tests/cli/install.t wrote a waiver into
# decisions/waivers/), and the CI on that commit failed in a way that
# had no local reproduction and no visible cause -- the transcript
# showed an exit status and nothing else, because the case piped the
# kernel's verdict into `grep -q`.
#
# The same write is a second kind of problem: the source tree is the
# developer's checkout. A case that leaves a file behind when it fails
# hands the NEXT case a corpus that is not the corpus it expects, and
# hands the next RUN a tree that is dirty for reasons the run does
# not know.
#
# WHAT IS A WRITE. Reading a source file is fine -- most cases read
# the spec, the schemas or a script out of the tree. A write is a
# REDIRECTION whose target is under the source root, or a cp/mv whose
# LAST argument is under it. An assignment like
# `install_sh="$DUNE_SOURCEROOT/scripts/install.sh"` is a read: it
# names a file to execute, and it writes nothing.
#
# This is a lint on the test sources, not a proof of absence: a case
# could still write into the tree through a program it invokes. The
# companion half -- the tree is not dirty after the suite runs -- is
# what the aggregator's own before/after comparison measures.
#
# EXIT: 0 when no case writes into the source tree. 1 when one does,
# naming the case and the line. 2 when the scan could not run.

set -uo pipefail
cd "$(dirname "$0")/../.."

if ! command -v python3 >/dev/null 2>&1; then
  echo "cram-tests-do-not-write-the-source-tree: SKIP (python3 unavailable)" >&2
  exit 2
fi

python3 - <<'PY'
import glob
import os
import re
import sys

ROOT = "$DUNE_SOURCEROOT"

# A redirection that is not a file-descriptor duplication. The target
# may be quoted, and the redirection may be `>>`.
REDIRECT = re.compile(
    r'(?<![\d&])>{1,2}(?!&)(?!=)\s*["\']?\s*\$\{?DUNE_SOURCEROOT\}?'
)
# cp / mv / tee at a COMMAND POSITION, and the LAST argument is the
# destination. The command position matters: `install.ps1` and
# `install-tooling/` are file names, not the `install` command, and
# matching them made every reference to a script look like a write.
COPY = re.compile(
    r'(?:^|[;&|(]\s*|\bthen\s+|\bdo\s+|\$\(\s*)(?P<verb>cp|mv|tee)\s+(?P<args>[^\n]*)'
)

problems = []

# cram's own line markers are not shell syntax. A line that begins
# with `$ ` is a COMMAND; a line that begins with `> ` is the
# CONTINUATION of the command above it. Both markers are stripped
# before the line is scanned, so a real redirection inside a
# continuation is still found -- the marker and the redirection are
# two different tokens, and only the first one is cram's.
CRAM_MARKER = re.compile(r'^\s*(?:\$|>)\s?')


for path in sorted(glob.glob("tests/**/*.t", recursive=True)):
    with open(path, encoding="utf-8", errors="replace") as fh:
        for lineno, raw in enumerate(fh, 1):
            stripped = raw.strip()
            if stripped.startswith("#"):
                continue
            line = CRAM_MARKER.sub("", raw, count=1)
            hit = REDIRECT.search(line)
            if hit:
                problems.append((path, lineno, "redirection", stripped))
                continue
            m = COPY.search(line)
            if m:
                args = m.group("args").split()
                # Drop flags; the destination is the last non-flag token.
                toks = [a for a in args if not a.startswith("-")]
                if toks and ROOT in toks[-1]:
                    problems.append((path, lineno, "copy destination", stripped))

if problems:
    for path, lineno, kind, text in problems:
        print(f"FAIL: {path}:{lineno}: {kind} into the source tree")
        print(f"  {text}")
    sys.exit(1)

print("no cram case writes into the source tree")
sys.exit(0)
PY
exit $?
