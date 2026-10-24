#!/usr/bin/env python3
"""scripts/migrate-verifiers.py — make the corpus's verifier strings honest.

WHY. The corpus carries 1482 obligation-verifier pairs. Of them:

  997  name a scheme the kernel can execute
  327  are PROSE: a sentence, not a reference to anything
  139  are TAUTOLOGIES: `file-exists` with no path,
       `this-decision-file-present`, `tests-pass` — checks that
       always pass and therefore prove nothing
   19  name an existing path in a form the kernel cannot read

The 327 prose strings are the worst case. The kernel's P2 check
accepts them, so the corpus LOOKS machine-verified. It is not: the
strings name either

  - a real command with the wrong syntax (`mathc validate
    decisions/x.yaml`, where the kernel's `mathc` scheme takes one
    subcommand), or
  - a check that was never implemented (`file-grep-zero`,
    `contains-section`, `git-no-paths` — names, not files).

Neither can be executed. The honest forms are:

  - a scheme the kernel can execute, or
  - `manual:<slug>` — an explicit declaration that a human checked
    it. The schema already treats `manual:` as the legal way to say
    "no machine ran this", and P2 already accepts it.

This script rewrites the corpus to those two forms and reports what
it changed. It is idempotent: running it twice changes nothing.

Usage:
  scripts/migrate-verifiers.py            # dry run, report only
  scripts/migrate-verifiers.py --write    # rewrite decisions/*.yaml
  scripts/migrate-verifiers.py --report   # write a report to stdout as JSON
"""
import argparse
import collections
import glob
import json
import os
import re
import sys

# The schemes the kernel can actually EXECUTE.
#
# This list is the kernel's, not the diagnostic's. The canonical
# scheme list in schemas/ and the diagnostic message names more -
# `bash`, `shell-grep`, `grep`, `git` - but bin/Mathc.ml::plan_verifier
# only plans `dune`, `tests/`, `scripts/`, plus the three original
# schemes handled before it: `file-exists`, `dir-exists`, `mathc`.
# Everything else reaches Plan_skip and is reported as skipped, i.e.
# NOT executed.
#
# The distinction matters here: a scheme the kernel merely RECOGNISES
# is still a check that never ran. Listing it as executable would put
# the corpus back where it was.
EXECUTABLE_PREFIXES = (
    "tests/", "scripts/", "dune ", "file-exists ", "dir-exists ",
    "mathc ", "manual-",
)

# The two prefixes the re-evaluation oracle recognises as BUILT-IN
# (bin/Mathc.ml::classify_verifier): `mathc-` and `kernel:`. A
# verifier string that starts with one of them is not prose - it
# names a kernel-level check that the oracle can classify. Moving
# them to `manual:` would have DESTROYED that classification: the
# fixture that pinned `kernel-unchanged` as `compatible` went to
# `inconclusive` after the first migration pass, because
# `mathc-self-check-verdict` had been demoted. They stay.
BUILTIN_PREFIXES = ("mathc-", "kernel:")

# Tautologies: a scheme name with no argument. These never could
# fail, so they never proved anything.
TAUTOLOGIES = {
    "file-exists": "manual-file-exists-unqualified",
    "dir-exists": "manual-dir-exists-unqualified",
    "file-contains": "manual-file-contains-unqualified",
    "tests-pass": "dune runtest",
}

# A `mathc <sub> ...` string is a real command with the wrong
# syntax: the kernel's `mathc` scheme takes ONE subcommand. The
# trailing words are prose that the kernel would try to pass as
# arguments.
MATHC_RE = re.compile(r"^mathc\s+([a-z][a-z0-9-]*)(\s+.*)?$")

# Scheme names the kernel recognises but that need an argument to
# mean anything. Used bare, they name nothing.
KNOWN_BARE_SCHEMES = {
    "shell-grep", "grep", "rg", "git", "jq", "curl", "awk", "sed",
    "contains-section", "file-grep-zero",
    "file-grep-non-zero", "git-no-paths",
    "p6-pre-commit-verification",
    "p7-honesty-in-fixture-assertions",
    "nav-fits-developer-laptop",
    "logo-crisp-at-favicon-size",
    "homepage-first-viewport-shows-only-hero",
    "moderation-section-renders-terminal",
    "russian-page-mirrors-english-structure",
    "hero-width-uses-prose-column",
}

# `manual:` slugs must be a single token.
SLUG_RE = re.compile(r"[^a-z0-9]+")


def slugify(text):
    s = SLUG_RE.sub("-", text.lower()).strip("-")
    s = re.sub(r"-{2,}", "-", s)
    return s[:48] if s else "unnamed"


def manual_slug(text):
    return "manual-" + slugify(text)


def is_executable(value):
    v = value.strip()
    if v.startswith(EXECUTABLE_PREFIXES):
        return True
    # A bare path that exists and names a file the kernel can run.
    return False



# Does the target a `tests/...` or `scripts/...` verifier names
# actually exist?
#
# The corpus cites checks that were never written: a test case that
# no file declares, a cram file that is not there, a script that was
# renamed. 133 verifier strings named something that does not exist,
# and the legacy attestations - all of them carrying an empty
# materials_digest, which the gate treats as a WILDCARD - recorded
# them as `pass`. A corpus that cites a check nobody wrote and
# signs it as passing is not a corpus that is verified; it is a
# corpus that is decorated.
#
# The forms the kernel can execute:
#   tests/X.t          a cram file; dune runs the whole file
#   tests/X.ml         an Alcotest module; `dune exec tests/X.exe`
#   tests/X.ml::case   one case of that module
#   tests/X.exe         the built binary of X.ml
#   scripts/X           a shell fixture
def target_exists(value, ml_cases):
    base, _, sel = value.partition('::')
    base = os.path.normpath(base)
    if base.startswith('tests/'):
        if base.endswith('.t'):
            return os.path.exists(base)
        if base.endswith('.exe'):
            return os.path.exists(base) or os.path.exists(base[:-4] + '.ml')
        if base.endswith('.ml'):
            if not os.path.exists(base):
                return False
            if sel and sel not in ml_cases.get(base, set()):
                return False
            return True
        return os.path.exists(base)
    if base.startswith('scripts/'):
        return os.path.exists(base)
    return True


# The corpus's verifier strings sometimes carry a PROSE TAIL after the
# command: `dune build @tests/x/runtest --root . exits 0`. The
# kernel's parse_verifier_string splits on whitespace and passes
# EVERY token to the program, so dune was invoked with the argument
# "exits" and then "0" - and reported a failure of the project for
# a check that had nothing wrong with it.
#
# The tail always starts at a word that cannot begin an argument.
PROSE_TAIL_WORDS = {
    "exits", "passes", "pass", "contains", "is", "has", "reports",
    "yields", "produces", "says", "prints", "returns", "fails",
    "succeeds", "works", "non-zero", "zero", "empty", "one",
}


def strip_prose_tail(value):
    """Cut a trailing prose clause off a command-shaped verifier."""
    toks = value.split()
    for i, t in enumerate(toks):
        if t in PROSE_TAIL_WORDS:
            return " ".join(toks[:i]).strip()
    return value

def classify(value, decision_id, path_exists, ml_cases):
    """Return (new_value, kind) for one verifier string."""
    raw = value.strip()

    def unquote(s):
        # Strip ONLY the outer wrapping characters, and only when they
        # match. `bash -c '...'` keeps its inner quotes; a value
        # wrapped in backticks - a prose quoting habit that leaks
        # into the machine-readable value - loses them, because the
        # kernel's parse_verifier_string does not know about
        # backticks and a path in backticks resolves to a path that
        # does not exist.
        if len(s) >= 2 and s[0] == s[-1] and s[0] in '"\'`':
            return s[1:-1]
        if s.endswith("`"):
            return s[:-1].rstrip()
        return s

    v = unquote(raw)

    if v == "this-decision-file-present":
        # The decision file itself exists at a known path. That is a
        # real, per-decision, machine-checkable fact.
        return ("file-exists decisions/%s.yaml" % decision_id, "anchored")

    if v in TAUTOLOGIES:
        return (TAUTOLOGIES[v], "tautology")

    # A `tests/...` or `scripts/...` verifier whose target does not
    # exist. The kernel would plan it, fail to build or run it, and
    # report a failure of the PROJECT for a check that was never
    # written. Declare it instead.
    if v.startswith(("tests/", "scripts/")) and not target_exists(v, ml_cases):
        return (manual_slug("target-missing-" + v), "declared-manual")

    if v.startswith(EXECUTABLE_PREFIXES):
        # A command-shaped verifier may carry a prose tail the
        # kernel would otherwise pass to the program as arguments.
        cut = strip_prose_tail(v)
        if cut != v:
            return (cut, "stripped-prose-tail")
        return (v, "unchanged")

    if v.startswith(BUILTIN_PREFIXES):
        # A built-in kernel verifier. The oracle classifies these by
        # prefix; demoting them to `manual:` would lose the
        # classification.
        return (v, "unchanged")

    m = MATHC_RE.match(v)
    if m:
        # `mathc validate decisions/x.yaml` -> `mathc validate`.
        # The trailing words are prose the kernel would misparse as
        # arguments to the subcommand.
        return ("mathc " + m.group(1), "mathc-syntax")

    # A bare path to a file in the repository, with no scheme. The
    # kernel's `file-exists` scheme wants the scheme spelled out.
    # `decisions/x.yaml` is a real file and a real check.
    if " " not in v and (path_exists(v) or v.endswith(".yaml")):
        return ("file-exists " + raw, "anchored")

    # A path into a BUILD OUTPUT directory. `dist/` is produced by
    # `mathc render`; it is not a repository file, so `file-exists`
    # against it can only be true on a machine that has rendered.
    # Declare it.
    if v.startswith("dist/"):
        return (manual_slug("rendered-asset-" + v[5:].rsplit(".", 1)[0]), "declared-manual")

    # A bare SCHEME name with no argument: `shell-grep`,
    # `mathc-self-check-verdict`. The kernel recognises the scheme
    # but there is nothing to check - no path, no needle. That is a
    # check that cannot fail, so it is declared, not executed.
    if " " not in v and v in KNOWN_BARE_SCHEMES:
        return (manual_slug(v + "-unqualified"), "tautology")

    # Everything else is prose: a shell command the kernel cannot
    # run (`grep -c X file == 0`, `rg -n ... file`, `git diff ...`),
    # or a sentence. Declare it.
    #
    # Growing the kernel's scheme list so these could be executed is
    # a real piece of work and is recorded as a follow-up; until it
    # exists, calling them `manual:` is the honest description.
    return (manual_slug(v), "declared-manual")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--decisions-dir", default="decisions")
    args = ap.parse_args()

    known = set()
    for root, dirs, files in os.walk("."):
        if root.startswith("./.git") or root.startswith("./_build"):
            dirs[:] = []
            continue
        for f in files:
            known.add(os.path.join(root, f)[2:])

    def path_exists(p):
        return p in known or os.path.exists(p)

    # The Alcotest case names each test module declares, so a
    # `tests/X.ml::case` verifier can be checked against reality.
    ml_cases = {}
    for p in glob.glob('tests/**/*.ml', recursive=True):
        try:
            t = open(p).read()
        except Exception:
            continue
        ml_cases[os.path.normpath(p)] = set(
            re.findall(r'Alcotest\.test_case\s+"([^"]+)"', t))

    kinds = collections.Counter()
    changes = []
    files_changed = 0

    for path in sorted(glob.glob(os.path.join(args.decisions_dir, "*.yaml"))):
        text = open(path).read()
        m = re.search(r"^id:\s*(\S+)", text, re.M)
        decision_id = m.group(1) if m else ""
        out = []
        touched = False
        for line in text.split("\n"):
            vm = re.match(r"^(\s*-?\s*verifier:\s*)(.+?)(\s*)$", line)
            if vm:
                old = vm.group(2).strip()
                new, kind = classify(old, decision_id, path_exists, ml_cases)
                kinds[kind] += 1
                if new != old:
                    touched = True
                    changes.append({
                        "file": path,
                        "decision": decision_id,
                        "old": old,
                        "new": new,
                        "kind": kind,
                    })
                    line = vm.group(1) + new + vm.group(3)
            out.append(line)
        if touched:
            files_changed += 1
            if args.write:
                open(path, "w").write("\n".join(out))

    report = {
        "files_changed": files_changed,
        "verifiers_by_kind": dict(kinds),
        "changes": changes,
    }
    if args.report:
        json.dump(report, sys.stdout, indent=1, ensure_ascii=False)
        print()
    else:
        print("verifiers by kind:")
        for k, v in kinds.most_common():
            print("  %6d  %s" % (v, k))
        print("files changed: %d" % files_changed)
        if not args.write:
            print("(dry run; pass --write to apply)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
