#!/usr/bin/env python3
"""scripts/prune-dead-scope-paths.py — drop the scope paths that name NOTHING.

WHY THIS TOOL EXISTS.

A decision's `scope.paths` names the files its attestation's
`materials_digest` is computed over: the digest is the digest of the
CONTENT of the files the scope MATCHES (lib/gate.ml::scope_materials_digest).
An entry that matches no tracked file contributes nothing to the
matched set, so it is not a weaker claim — it is NO claim at all.

Measured on 2026-10-25 over the 246 decisions of `decisions/`:

    81 decisions carried at least one scope path that matches no
    tracked file (162 entries).

    26   lib/render.ml            the file does not exist
    22   OCAML_BEST_PRACTICES.md   the file does not exist
     3   site/index.md             the file does not exist
     2   bootstrap/adapters.yaml   a path relative to decisions/
     2   decisions/<sub-decision-id>-2026-10.yaml   a PLACEHOLDER
     2   attestations/<id>-*.json"     # the attestations
                                   ^ a comment INSIDE the quoted path
     1   |                         a YAML block scalar, not a path

A dead path is not merely harmless, it is a TRAP: it matches nothing
today, and the day somebody creates a file with that name it starts
silently invalidating attestations that nobody re-signed.

WHAT THIS TOOL DOES.

It rewrites `decisions/*.yaml`, dropping the scope-path entries that
match no tracked file and recording each removal in the decision's own
text (a comment under the scope) so a reader can see that the scope
once named `lib/render.ml` and why it no longer does. Everything else
in the file is kept byte-for-byte.

THE MATCHING IS THE KERNEL'S.

The glob rules are imported from `scripts/audit-scopes.py`, which is a
faithful re-implementation of `Gate.glob_match` and
`Gate.segment_match` (lib/gate.ml). This script deliberately does NOT
carry a second copy of those rules: a second copy is exactly how a
matching drifts out of agreement with the gate.

THE SCOPE EXTRACTION IS THE KERNEL'S, TOO.

`lib/memory.ml::extract_scope_paths` is the authority on what a scope
IS: a top-level `scope:` key, a `paths:` key at indent 2, and the list
items under it. The parse here mirrors that shape, and is a SUPERSET
of it in two places the corpus forces:

  * the kernel demands an item sit at indent exactly 4 and stops at
    the first line that is not an item, so a COMMENT or a block-scalar
    continuation inside the list HIDES the items that follow it from
    the digest. Here a comment is skipped and the list continues.
  * a decision may write its items at indent 2, which the kernel
    therefore never reads at all. Those are read here.

Reading MORE than the kernel reads is safe in the direction that
matters: an entry the kernel never read contributes nothing to any
digest, and an entry the kernel DID read but which matches nothing
also contributes nothing. Either way the matched set - and therefore
every materials digest - is unchanged, except for the decisions that
name their own file in their scope: those change because their own
BYTES changed, and must be re-signed. That re-signing is the
attestation store's business, not this script's.

THE PARSE IS NARROW.

`[ \\t]` for indentation, never `\\s`: `\\s` matches a newline, so a
`\\s`-based scan splits on a nested `- id:` line and attributes one
decision's scope to another. That bug shipped once and produced false
accusations (scripts/classify-failed-verifiers.py::parse_corpus says
so for the same reason).

WHAT IT DOES NOT TOUCH.

`scope.exclusions`, `scope.capabilities` and `scope.decisions` are
NOT scope paths. The kernel reads only `scope.paths` when it computes
a materials digest (lib/gate.ml::scope_materials_digest takes the
scope paths and the attestation-store prefixes; the decision's own
exclusions are documentation and are never consulted). A dead
EXCLUSION excludes nothing and breaks nothing; a `scope.decisions`
entry is a cross-reference to another decision, not a path. Pruning
them would be a different edit with a different justification, so this
script leaves them alone and the report says how many there are.

THE DIGEST IS THE KERNEL'S TOO.

Editing a decision changes its bytes, so its `body_sha` / `yaml_sha`
go stale and `mathc validate` rejects it (MC-SHA-DIGEST-STALE). The
restamp is done by the kernel's own tool (`mathc rehash --write`),
never by a second implementation of algebra §7.1's canonicalisation
here: lib/decision.ml says exactly why a second copy is a liability.

USAGE
    scripts/prune-dead-scope-paths.py [--check] [--dry-run]
                                      [--decisions DIR] [--report FILE]
                                      [--rehash-binary PATH]

    (default)          prune the dead entries and restamp the changed
                       decisions with `mathc rehash --write`.
    --check            report the dead entries; write nothing; exit 1
                       if any were found.
    --dry-run          report what would be pruned; write nothing.
"""

import argparse
import collections
import importlib.util
import os
import subprocess
import sys

# The import below must not leave a __pycache__ behind in scripts/.
sys.dont_write_bytecode = True


# --- the kernel's glob rules (lib/gate.ml, via scripts/audit-scopes.py) ---


def load_glob_rules():
    """import Gate.glob_match's re-implementation from scripts/audit-scopes.py."""
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, "audit-scopes.py")
    if not os.path.exists(path):
        sys.stderr.write(
            "prune-dead-scope-paths: scripts/audit-scopes.py is missing; "
            "the glob rules are not re-implemented here on purpose\n"
        )
        sys.exit(2)
    spec = importlib.util.spec_from_file_location("audit_scopes", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.glob_match


# --- the corpus ------------------------------------------------------------


def is_top_level(line):
    """lib/memory.ml::is_top_level: no leading whitespace, not a comment,
    not the YAML front-matter marker."""
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


def kernel_value(text):
    """the path value the kernel reads out of a scope item.

    lib/memory.ml strips a matching pair of DOUBLE quotes and nothing
    else, so a trailing comment written inside the quotes stays part of
    the value - which is why such an entry matches nothing."""
    if len(text) >= 2 and text[0] == '"' and text[-1] == '"':
        return text[1:-1]
    return text


class Item(object):
    """one list item of a scope's `paths:` list."""

    def __init__(self, first, last, text):
        self.first = first  # index of the item's first line
        self.last = last  # index of the item's last line (block scalar)
        self.text = text  # the item as written, after the "- "
        self.value = kernel_value(text)  # the path the kernel reads


def find_scope_paths(lines):
    """the `scope.paths` items of one decision.

    Returns (items, paths_key_line). `paths_key_line` is the index of
    the `paths:` key, or None when the decision declares no path list.
    """
    scope_at = None
    for i, line in enumerate(lines):
        if is_top_level(line):
            if line.strip() == "scope:":
                scope_at = i
                break
    if scope_at is None:
        return [], None

    end = len(lines)
    for j in range(scope_at + 1, len(lines)):
        if is_top_level(lines[j]):
            end = j
            break

    paths_at = None
    for j in range(scope_at + 1, end):
        line = lines[j]
        if is_top_level(line):
            break
        if leading_spaces(line) == 2 and line.strip() == "paths:":
            paths_at = j
            break
    if paths_at is None:
        return [], None

    items = []
    j = paths_at + 1
    while j < end:
        line = lines[j]
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            j += 1
            continue
        indent = leading_spaces(line)
        if not (stripped.startswith("- ") and len(stripped) > 2):
            break  # not a list item: the list ends here
        text = stripped[2:].strip()
        last = j
        if text[:1] in ("|", ">"):
            # A block scalar owns its continuation lines: they are part
            # of the item, and removing the item must remove them too.
            k = j + 1
            while k < end:
                nxt = lines[k]
                if not nxt.strip():
                    k += 1
                    continue
                if leading_spaces(nxt) > indent:
                    last = k
                    k += 1
                    continue
                break
        items.append(Item(j, last, text))
        j = last + 1
    return items, paths_at


def classify(value):
    """why the entry names nothing. One line, for the note."""
    if "<" in value and ">" in value:
        return "a placeholder, never a path"
    if value[:1] in ("|", ">"):
        return "a YAML block scalar, not a path"
    if "#" in value:
        return "malformed: a comment inside the quoted path"
    if value[:1] in ('"', "'", "\\"):
        return "malformed: a comment inside the quoted path"
    if value.startswith("~/"):
        return "home-relative: resolves nowhere in the repository"
    if "@" in value:
        return "a decision id, not a path"
    if "::" in value:
        return "a symbol reference, not a path"
    return "no tracked file matches it"


def tracked_files(root):
    try:
        res = subprocess.run(
            ["git", "-C", root, "ls-files"], capture_output=True, text=True
        )
    except OSError:
        return []
    if res.returncode != 0:
        return []
    return [f for f in res.stdout.split("\n") if f]


def repo_root():
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.dirname(here)


def decision_id(text):
    import re

    m = re.search(r"^id:[ \t]*(\S+)", text, re.M)
    return m.group(1) if m else None


# --- the rewrite -----------------------------------------------------------


def note_lines(dead, when):
    """the note left in the decision's own text.

    A header line and one line per removed entry: the entry as the
    kernel read it, and why it named nothing. The entry is printed
    VERBATIM, because the point of the note is that a reader can see
    what the scope once claimed - including the malformed spelling."""
    seen = collections.Counter(it.value for it in dead)
    out = [
        "  # %s: pruned from this scope, per "
        "decisions/dead-scope-paths-2026-10.yaml" % when
    ]
    for value, n in seen.items():
        times = " (x%d)" % n if n > 1 else ""
        out.append(
            "  #   %s%s - %s" % (value, times, classify(value))
        )
    return out


def prune_text(text, dead_values, when):
    """the pruned text: the dead items dropped, the note left behind.

    `dead_values` is a Counter of the path values to drop; the items
    are matched by value in order, so a value that occurs twice is
    dropped as many times as it is dead."""
    lines = text.split("\n")
    items, paths_at = find_scope_paths(lines)
    if paths_at is None or not items:
        return text

    dead = []
    survivors = []
    for it in items:
        if dead_values.get(it.value, 0) > 0:
            dead_values[it.value] -= 1
            dead.append(it)
        else:
            survivors.append(it)
    if not dead:
        return text

    removed_lines = set()
    for it in dead:
        for k in range(it.first, it.last + 1):
            removed_lines.add(k)

    out = []
    for idx, line in enumerate(lines):
        if idx in removed_lines:
            continue
        if idx == paths_at and not survivors:
            # Every path named nothing: say so explicitly rather than
            # leaving a key with nothing under it.
            out.append("  paths: []")
            out.extend(note_lines(dead, when))
            continue
        out.append(line)
        if survivors and idx == survivors[-1].last:
            out.extend(note_lines(dead, when))
    return "\n".join(out)


# --- the run ---------------------------------------------------------------


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--decisions", default="decisions")
    ap.add_argument("--report", default=None)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--when", default="2026-10-25")
    ap.add_argument("--rehash-binary", default=None)
    args = ap.parse_args()

    root = repo_root()
    glob_match = load_glob_rules()
    files = tracked_files(root)
    if not files:
        sys.stderr.write("prune-dead-scope-paths: no tracked files found\n")
        return 2

    decisions_dir = args.decisions
    if not os.path.isabs(decisions_dir):
        decisions_dir = os.path.join(root, decisions_dir)

    report = []
    changed = []
    offenders = collections.Counter()
    touched = 0
    scanned = 0
    examined = 0

    for name in sorted(os.listdir(decisions_dir)):
        if not name.endswith((".yaml", ".yml")):
            continue
        path = os.path.join(decisions_dir, name)
        try:
            text = open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        items, paths_at = find_scope_paths(text.split("\n"))
        if paths_at is None:
            continue
        scanned += 1
        examined += len(items)
        dead = []
        for it in items:
            if not any(glob_match(it.value, f) for f in files):
                dead.append(it)
        if not dead:
            continue
        touched += 1
        for it in dead:
            offenders[it.value] += 1
        did = decision_id(text) or name
        report.append("%s (%s): pruned %d entr%s" % (
            name, did, len(dead), "y" if len(dead) == 1 else "ies"))
        for it in dead:
            report.append("    %s - %s" % (it.value, classify(it.value)))
        if not args.check and not args.dry_run:
            dead_values = collections.Counter(it.value for it in dead)
            new_text = prune_text(text, dead_values, args.when)
            if new_text != text:
                with open(path, "w", encoding="utf-8") as fh:
                    fh.write(new_text)
                changed.append(path)

    header = [
        "prune-dead-scope-paths: %d decision(s) scanned, %d scope path(s) "
        "examined, %d with a dead scope path" % (scanned, examined, touched),
    ]
    if offenders:
        header.append(
            "the %d most repeated dead paths:" % min(20, len(offenders))
        )
        for value, n in offenders.most_common(20):
            header.append("    %5d  %s" % (n, value))
    body = "\n".join(header + report)
    print(body)

    if args.report:
        report_path = args.report
        if not os.path.isabs(report_path):
            report_path = os.path.join(root, report_path)
        parent = os.path.dirname(report_path)
        if parent and not os.path.isdir(parent):
            os.makedirs(parent)
        with open(report_path, "w", encoding="utf-8") as fh:
            fh.write(body + "\n")
        print("wrote %s" % report_path)

    if args.check:
        return 1 if touched else 0

    if args.dry_run:
        return 0

    if changed:
        binary = args.rehash_binary
        if binary is None:
            for candidate in (
                os.path.join(root, "_build", "default", "bin", "mathc.exe"),
                os.path.join(root, "_build", "install", "default", "bin", "mathc"),
            ):
                if os.path.exists(candidate):
                    binary = candidate
                    break
        if binary is None:
            sys.stderr.write(
                "prune-dead-scope-paths: %d file(s) changed but no mathc "
                "binary was found; restamp them with\n"
                "  mathc rehash --write %s\n" % (len(changed), " ".join(changed))
            )
            return 2
        res = subprocess.run(
            [binary, "rehash", "--write"] + changed,
            capture_output=True,
            text=True,
        )
        if res.returncode != 0:
            sys.stderr.write(res.stdout + res.stderr)
            sys.stderr.write(
                "prune-dead-scope-paths: the restamp failed; the corpus is "
                "left with stale body_sha fields\n"
            )
            return 2
        print("restamped %d decision(s) with %s" % (len(changed), binary))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        # `... | head` closes the pipe; that is not an error of ours.
        os._exit(0)
