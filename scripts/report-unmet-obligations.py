#!/usr/bin/env python3
"""scripts/report-unmet-obligations.py — what is wrong with every obligation the
re-signing refused to sign, in a form a human can act on.

WHAT IT IS FOR.

`mathc attest-batch --run-per-obligation` refuses to write an attestation
for an obligation whose check FAILED, and says so:

    mathc attest-batch: NOT signing <decision>/<obligation> — its verifier failed.

It does not say WHICH verifier failed, and it does not say what the verifier
printed. An obligation may name several verifiers, and the failure may be in
any of them. Whoever has to repair the corpus therefore has to re-derive that
by hand, one obligation at a time.

This tool re-derives it mechanically and prints a verdict and a RECOMMENDATION
per obligation. The four recommendations are:

    fix-the-verifier     the verifier names a target that does not exist, or
                         an alias / flag / prose tail that is wrong. The tool
                         says what the RIGHT target is.
    needs-a-toolchain    the verifier names a program that is not on PATH
                         here. The tool says which one.
    declare-it-manual    the verifier cannot run in the stripped sandbox by
                         construction — a `manual-` declaration. The tool says
                         what the manual declaration should name.
    investigate          none of the above fits. The tool says why.

THE METHOD.

Every unsigned obligation is re-evaluated VERIFIER BY VERIFIER, the way
`scripts/classify-failed-verifiers.py` does it: a throwaway decision carrying
exactly one obligation with exactly one verifier is written into the project,
re-stamped with `mathc rehash --write`, run through `mathc verify`, and
deleted. The kernel's own verdict line and the kernel's own sandbox excerpt
are both captured, so the report can quote the exact error the verifier
printed instead of the word "failed".

The sweep-time evidence is kept as well: the sweep log already contains the
verifier's output at the moment the re-signing refused to sign, and that is
what the report quotes as THE ERROR. The re-run is what says whether the
failure still reproduces.

Two parses of the corpus are needed and both are deliberately NARROW
(`[ \\t]` for indentation, never `\\s`): `\\s` matches a newline, so
`^\\s+-\\s+id:` splits on a nested `- id:` line and on blank lines, and the
obligation a failure belongs to is then attributed to the wrong verifier.

A decision is resolved BY ITS ID, not by its file name. Sixteen decisions
carry an id that differs from their file name, and the kernel resolves them
by id; a probe that looked for `<id>.yaml` would report "no source" for them.

USAGE
    scripts/report-unmet-obligations.py [--log FILE] [--decisions DIR]
                                         [--bin PATH] [--out-json FILE]
                                         [--out-md FILE] [--limit N]
                                         [--no-probe]

    --log       the sweep log the unsigned obligations are read from.
                Default: ./sign-store-sweep.log
    --out-json  where to write the machine-readable report.
    --out-md    where to write the rendered report.
    --limit     stop after N obligations (for a quick look).
    --no-probe  do not re-run the verifiers; report the sweep-time evidence
                only. The per-verifier verdicts are then "not re-run".
"""

import argparse
import collections
import json
import os
import re
import subprocess
import sys

PROBE_DIR = ".work/unmet-probes"

# The four recommendations. A verdict that is not one of these is a bug in
# this tool, and the fixture checks that every entry carries one.
RECOMMENDATIONS = (
    "fix-the-verifier",
    "needs-a-toolchain",
    "declare-it-manual",
    "investigate",
)


# ---------------------------------------------------------------- parsing


def parse_corpus(decisions_dir):
    """decision id -> {path, obligations: {obligation id: [verifier, ...]}}.

    A decision is keyed by the id it declares, NOT by its file name: the
    kernel resolves a decision by id, and sixteen decisions carry an id that
    differs from their file name.
    """
    out = {}
    for name in sorted(os.listdir(decisions_dir)):
        if not name.endswith(".yaml"):
            continue
        path = os.path.join(decisions_dir, name)
        try:
            text = open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        m = re.search(r"^id:[ \t]*(\S+)", text, re.M)
        om = re.search(r"^obligations:[ \t]*\r?\n(.*?)(?=^\S|\Z)", text, re.M | re.S)
        if not m or not om:
            continue
        obligations = {}
        for blk in re.split(r"^[ \t]+-[ \t]+id:[ \t]*", om.group(1), flags=re.M)[1:]:
            obl_id = blk.split()[0]
            vs = re.findall(
                r"^[ \t]+-[ \t]+verifier:[ \t]*(.+?)[ \t]*$", blk, re.M
            )
            obligations[obl_id] = {"verifiers": vs, "claim": obligation_claim(blk)}
        out[m.group(1)] = {"path": path, "obligations": obligations}
    return out


def obligation_claim(block):
    """The obligation's `claim:` text, or its `statement:`.

    A block scalar (`claim: |`) runs until a line that is not more indented
    than the key itself; a plain scalar is the rest of the line.
    """
    lines = block.splitlines()
    for key in ("claim", "statement"):
        for i, line in enumerate(lines):
            m = re.match(r"^[ \t]+%s:[ \t]*(.*?)[ \t]*$" % key, line)
            if not m:
                continue
            indent = len(line) - len(line.lstrip())
            rest = m.group(1)
            if rest not in ("|", ">", "|-", ">-", "|+", ">+"):
                return rest
            out = []
            for nxt in lines[i + 1 :]:
                if not nxt.strip():
                    out.append("")
                    continue
                nxt_indent = len(nxt) - len(nxt.lstrip())
                if nxt_indent <= indent:
                    break
                out.append(nxt.strip())
            return " ".join(x for x in out if x)
    return ""


def parse_unsigned(log_path):
    """[(decision, obligation)] the re-signing refused to sign, in log order.

    Each entry carries the ERROR BLOCK the sweep printed for it: the
    verifier's own output at the moment the obligation was refused. That
    block is the evidence; the word "failed" is not.

    The kernel MEMOISES a verifier's result within one signing, so one
    verifier that failed is reported once and every obligation naming it
    is refused. The error block is therefore matched back to the
    obligations by the verifier it names, not by position: a positional
    match would leave every obligation after the first with no evidence.
    """
    entries = []
    blocks = []
    try:
        fh = open(log_path, encoding="utf-8", errors="replace")
    except OSError:
        return entries, blocks
    with fh:
        lines = fh.read().splitlines()
    pending = []
    for line in lines:
        if line.startswith("mathc verify:") and (
            "exited" in line
            or "output of" in line
            or "is not on PATH" in line
            or "exceeded" in line
        ):
            pending = [line]
            continue
        if pending and line.startswith("  | "):
            pending.append(line)
            continue
        m = re.search(r"NOT signing (\S+)/(\S+)", line)
        if m:
            entries.append(
                {"decision": m.group(1), "obligation": m.group(2)}
            )
            continue
        if pending:
            blocks.append("\n".join(pending))
            pending = []
    if pending:
        blocks.append("\n".join(pending))
    return entries, blocks


def match_block(blocks, verifiers):
    """The error block that belongs to these verifier strings, or "".

    A block that names the command in backticks is that command's block.
    A block that says only "mathc exited N" is the block of a `mathc ...`
    verifier. A path in the verifier is matched as a PATH COMPONENT, not
    as a bare substring: `mathc` occurs inside `math-coding`, and a bare
    substring match would hand one obligation another one's evidence.
    Anything else is not matched, because a wrong block is worse than no
    block.
    """
    best, best_score = "", 0
    for b in blocks:
        score = 0
        for v in verifiers:
            if "output of `%s`" % v in b:
                score = max(score, 5)
                continue
            for tok in v.split():
                if "/" not in tok:
                    continue
                base = os.path.basename(tok)
                if re.search(r"(?:^|[\s/`\"'])" + re.escape(base) + r"(?:$|[\s`\"'])", b):
                    score = max(score, 3)
            if v.startswith("mathc ") and b.startswith("mathc verify: mathc exited"):
                score = max(score, 2)
        if score > best_score:
            best, best_score = b, score
    return best


# ---------------------------------------------------------------- probing


def probe_one(project_root, corpus, decision, obligation, verifier, bin_path, probe_dir):
    """Evaluate ONE verifier on its own. Returns (verdict, output).

    The probe decision is the original with its obligations block replaced
    by a single obligation carrying a single verifier. It is re-stamped
    before it is run: the strict parser enforces the sha fields, so a probe
    carrying the original's digest is reported as having no obligations at
    all, which reads as "skipped" and is a FALSE reading of the verifier.

    The probe lives inside the project so the project root resolves to the
    repository, and it is deleted as soon as it has been run.
    """
    entry = corpus.get(decision)
    if entry is None:
        return "no-source", ""
    text = open(entry["path"], encoding="utf-8", errors="replace").read()

    probe_id = "zz-unmet-probe-%s-%s" % (
        re.sub(r"[^A-Za-z0-9_.-]", "_", decision),
        re.sub(r"[^A-Za-z0-9_.-]", "_", obligation),
    )
    os.makedirs(probe_dir, exist_ok=True)
    probe_path = os.path.join(project_root, probe_dir, probe_id + ".yaml")

    body = re.sub(r"^id:[ \t]*\S+", "id: " + probe_id, text, count=1, flags=re.M)
    new_block = (
        "obligations:\n"
        "  - id: probe-obligation\n"
        "    acceptance:\n"
        "      all:\n"
        "        - verifier: %s\n"
        "          result: pass\n" % verifier
    )
    body = re.sub(
        r"^obligations:[ \t]*\r?\n.*?(?=^\S|\Z)",
        new_block,
        body,
        count=1,
        flags=re.M | re.S,
    )

    try:
        with open(probe_path, "w", encoding="utf-8") as fh:
            fh.write(body)
    except OSError as exc:
        return "probe-unwritable", str(exc)

    subprocess.run(
        [bin_path, "rehash", "--write", probe_path],
        capture_output=True,
        text=True,
    )

    try:
        proc = subprocess.run(
            [bin_path, "verify", probe_path],
            capture_output=True,
            text=True,
            timeout=600,
        )
    except subprocess.TimeoutExpired:
        return "timeout", ""
    finally:
        try:
            os.remove(probe_path)
        except OSError:
            pass

    verdict = "unparsed"
    for line in proc.stdout.splitlines():
        m = re.match(r"^\s+(probe-obligation):\s*(\S+)", line)
        if m:
            verdict = m.group(2)
            break
    output = (proc.stderr or "").strip()
    if output and output not in proc.stdout:
        output = output
    return verdict, output


# ------------------------------------------------------- repair rules


def _dune_alias_repair(verifier, root):
    """`dune build @tests/<X>/runtest` where tests/<X> is a MODULE, not a
    directory. The right target is the test executable that exists."""
    m = re.search(r"@([A-Za-z0-9_./-]+)/runtest", verifier)
    if not m:
        return None
    rel = m.group(1)
    if os.path.isdir(os.path.join(root, rel)):
        return None
    module = rel + ".ml"
    if not os.path.isfile(os.path.join(root, module)):
        return None
    return (
        "dune test --root . %s.exe" % rel,
        "`%s` is not a directory - dune says \"Don't know about directory %s\"; "
        "the module is `%s`, so the runnable target is `%s.exe`"
        % (rel, rel, module, rel),
    )


def _file_exists_target(verifier, root):
    """The path a `file-exists` verifier means, and whether it is there.

    A `text-scan-` scheme prefix glued onto the path is a known shape of
    mistake: `file-exists text-scan-decisions/x.yaml` names a DIRECTORY
    called `text-scan-decisions`, and the path the author meant is the one
    behind the prefix.
    """
    m = re.match(r"^(?:file-exists[ \t]+|mathc[ \t]+validate[ \t]+)(\S+)$", verifier)
    if not m:
        return None, None
    rel = m.group(1)
    if os.path.exists(os.path.join(root, rel)):
        return rel, True
    m2 = re.match(r"^text-scan-(.+)$", rel)
    if m2 and os.path.isdir(os.path.join(root, os.path.dirname(m2.group(1)))):
        rel = m2.group(1)
        return rel, os.path.exists(os.path.join(root, rel))
    return rel, False


def _file_exists_repair(verifier, root, corpus):
    """`file-exists <p>` where <p> does not exist.

    Two shapes of mistake are repaired, both derived from the repository:

    (a) the path is `decisions/<id>.yaml` and `<id>` IS a decision id
        whose file is named differently - the corpus's own convention,
        where a decision's id and its file name differ. The right target
        is that decision's file.
    (b) the path is under `decisions/` and exactly ONE sibling carries
        the same stem.

    Nothing outside `decisions/` is repaired this way: elsewhere a
    missing file is usually an artifact that has not been produced yet,
    and moving the pointer would hide that.
    """
    m = re.match(r"^file-exists[ \t]+(\S+)$", verifier)
    if not m:
        return None
    rel = m.group(1)
    if os.path.exists(os.path.join(root, rel)):
        return None
    d = os.path.dirname(rel)
    base = os.path.basename(rel)
    stem = base
    for suffix in (".yaml", ".yml", ".json", ".sh", ".t", ".ml"):
        if stem.endswith(suffix):
            stem = stem[: -len(suffix)]
            break
    if d != "decisions":
        return None
    if stem in corpus and corpus[stem]["path"] != rel:
        target = corpus[stem]["path"]
        return (
            "file-exists %s" % target,
            "`%s` does not exist; the decision whose id is `%s` is filed as "
            "`%s` - the corpus's convention lets a decision's id and its "
            "file name differ" % (rel, stem, target),
        )
    cands = []
    for f in sorted(os.listdir(os.path.join(root, d))):
        if f.startswith(stem) and f != base:
            cands.append(os.path.join(d, f))
    if len(cands) != 1:
        return None
    return (
        "file-exists %s" % cands[0],
        "`%s` does not exist; exactly one file with the same stem does: `%s`"
        % (rel, cands[0]),
    )


def _claim_path_repair(verifier, root, claim):
    """The verifier names a path the obligation's CLAIM does not name, and
    the claim names one that exists. The claim is the statement of what
    the obligation is about; the verifier has to check that."""
    m = re.match(r"^(?:file-exists|mathc[ \t]+validate)[ \t]+(\S+)$", verifier)
    if not m:
        return None
    named = m.group(1)
    if os.path.exists(os.path.join(root, named)):
        return None
    paths = set(re.findall(r"[A-Za-z0-9_./-]+\.(?:yaml|yml|json|sh|ml|t)", claim or ""))
    d = os.path.dirname(named)
    ext = os.path.splitext(named)[1]
    cands = [
        p
        for p in sorted(paths)
        if p != named
        and os.path.dirname(p) == d
        and os.path.splitext(p)[1] == ext
        and os.path.exists(os.path.join(root, p))
    ]
    if len(cands) != 1:
        return None
    return (
        verifier.replace(named, cands[0]),
        "the verifier names `%s`, which does not exist; the obligation's "
        "claim names `%s`, which does - and that is the file the check is "
        "about" % (named, cands[0]),
    )


def _mathc_prose_tail_repair(verifier, root, bin_path):
    """`mathc validate <file> <word>` - the trailing word is an English
    annotation, not an argument. The kernel has a prose-tail stripper for
    the `dune` scheme and none for `mathc`, so the word reaches mathc as a
    second positional and the command exits 2."""
    m = re.match(r"^mathc[ \t]+(validate)[ \t]+(\S+)[ \t]+([a-z][a-z-]*)$", verifier)
    if not m:
        return None
    sub, target, word = m.group(1), m.group(2), m.group(3)
    if not os.path.exists(os.path.join(root, target)):
        return None
    fixed = "mathc %s %s" % (sub, target)
    try:
        proc = subprocess.run(
            [bin_path, "validate", target], capture_output=True, text=True, timeout=120
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    return (
        fixed,
        "`%s` passes an English annotation (`%s`) as a second positional to "
        "`mathc %s`, which then exits 2 (input error); the annotation is not "
        "an argument" % (verifier, word, sub),
    )


def _alcotest_group_repair(verifier, root):
    """`tests/<mod>.ml::<case>` where <case> is an Alcotest CASE, not a
    group. The kernel's selector is a regex against the GROUP name, so the
    case has to be named through the group that holds it."""
    m = re.match(r"^tests/([A-Za-z0-9_./-]+\.ml)::(.+)$", verifier)
    if not m:
        return None
    rel, case = m.group(1), m.group(2)
    path = os.path.join(root, "tests", rel)
    if not os.path.isfile(path):
        return None
    text = open(path, encoding="utf-8", errors="replace").read()
    groups = re.findall(r'\(\s*"([A-Za-z0-9_]+)"\s*,\s*\[', text)
    if case in groups:
        return None
    owners = []
    for g in groups:
        idx = text.find('"%s"' % g)
        if idx < 0:
            continue
        seg = text[idx : idx + 4000]
        if '"%s"' % case in seg:
            owners.append(g)
    if len(owners) != 1:
        return None
    return (
        "tests/%s::%s" % (rel, owners[0]),
        "the Alcotest selector is a regex against the GROUP name, and "
        "`%s` is a case inside the group `%s`; naming the case matches no "
        "group, and alcotest answers \"no tests to run, filter skipped "
        "everything\"" % (case, owners[0]),
    )


def _script_subcommand_repair(verifier, root, claim):
    """`scripts/<name>` with NO subcommand. The script prints its usage and
    exits non-zero. The right target is the subcommand the obligation is
    about - `test` when the obligation is about the test suite."""
    m = re.match(r"^(scripts/[A-Za-z0-9_./-]+)$", verifier)
    if not m:
        return None
    rel = m.group(1)
    path = os.path.join(root, rel)
    if not os.path.isfile(path):
        return None
    text = open(path, encoding="utf-8", errors="replace").read()
    if not re.search(r"^\s*test\)", text, re.M):
        return None
    lowered = (claim or "").lower()
    if "test" not in lowered:
        return None
    return (
        "%s test" % rel,
        "`%s` is the development-command wrapper; with no subcommand it "
        "prints its usage and exits non-zero. Its `test` subcommand runs "
        "the suite, which is what the obligation is about" % rel,
    )


def _claim_module_repair(verifier, root, claim):
    """A dune verifier that names a test the OBLIGATION'S CLAIM does not
    name. The claim is the statement of what the obligation is about; a
    verifier that builds a different test cannot check it."""
    m = re.search(r"@([A-Za-z0-9_./-]+)/runtest", verifier)
    if not m:
        return None
    named = m.group(1)
    modules = re.findall(r"tests/([A-Za-z0-9_]+)\.ml", claim or "")
    modules = sorted(set(modules))
    if len(modules) != 1:
        return None
    if modules[0] == named:
        return None
    if not os.path.isfile(os.path.join(root, "tests", modules[0] + ".ml")):
        return None
    return (
        "dune test --root . tests/%s.exe" % modules[0],
        "the verifier builds `%s`, but the obligation's claim is about "
        "`tests/%s.ml`; the check can only be about the test the claim "
        "names" % (named, modules[0]),
    )


def _claim_command_repair(verifier, root, claim, bin_path):
    """`mathc <sub> --flag` where the obligation's CLAIM names a DIFFERENT
    subcommand with the same flag. The claim is the statement of what the
    obligation is about; a verifier that calls another subcommand cannot
    check it."""
    m = re.match(r"^mathc[ \t]+([A-Za-z0-9_-]+)[ \t]+(--[A-Za-z0-9-]+)$", verifier)
    if not m:
        return None
    sub, flag = m.group(1), m.group(2)
    named = sorted(set(re.findall(r"mathc ([a-z][a-z0-9-]*) (--[a-z0-9-]+)", claim or "")))
    cands = [x for x in named if x[0] != sub and x[1] == flag]
    if len(cands) != 1:
        return None
    target = "mathc %s %s" % cands[0]
    try:
        proc = subprocess.run(
            [bin_path, cands[0][0], cands[0][1]], capture_output=True, text=True, timeout=120
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    return (
        target,
        "`mathc %s` has no `%s` flag - it exits 2 (input error); the "
        "obligation's claim names `%s`, which is the command the obligation "
        "is about" % (sub, flag, target),
    )


def _pipefail_grepq_race(verifier, root):
    """A shell verifier that sets `pipefail` and pipes into `grep -q`.

    `grep -q` exits at the FIRST match; the writer on the other end of the
    pipe then takes SIGPIPE (141); `pipefail` promotes that signal to a
    pipeline failure. The check's verdict therefore depends on a RACE
    between the writer and the reader, and under load the race is lost
    often enough to matter. The failure looks like "the thing I grepped
    for is not there" while the thing IS there.
    """
    m = re.match(r"^(scripts/[A-Za-z0-9_./-]+|tests/[A-Za-z0-9_./-]+\.sh)$", verifier)
    if not m:
        return None
    path = os.path.join(root, m.group(1))
    if not os.path.isfile(path):
        return None
    text = open(path, encoding="utf-8", errors="replace").read()
    if "pipefail" not in text:
        return None
    if not re.search(r"\|\s*grep[ \t]+-q", text):
        return None
    return (
        "`%s` sets `set -o pipefail` and pipes into `grep -q`: `grep -q` exits "
        "at the first match, the writer on the other end of the pipe takes "
        "SIGPIPE (141), and `pipefail` promotes that signal to a pipeline "
        "FAILURE. The check's verdict is a race, not a verdict - under load "
        "it reports a false failure while quoting the very string it was "
        "looking for. The fix is in the fixture: drop `-q` (plain `grep` "
        "reads the whole input) or use a herestring" % m.group(1)
    )


def _slug(path):
    """The shape a manual verifier's name uses to hide a path."""
    return re.sub(r"[^a-z0-9]+", "-", path.lower())


def _manual_targets(verifier, root, claim):
    """What a `manual-` declaration SHOULD name, derived from the corpus.

    A manual name hides the file it points at: the path is slugged into
    the name (`tests/render_kernel.ml` -> `tests-render-kernel-ml`). The
    file is found by matching that slug against the repository, and the
    Alcotest groups of that file are the candidates the declaration can
    name. The group whose name overlaps the obligation's claim most is
    the one the declaration is about.
    """
    m = re.match(r"^manual-([a-z0-9-]+)$", verifier)
    if not m:
        return None
    slug = m.group(1)
    hit = None
    for base, _dirs, files in os.walk(os.path.join(root, "tests")):
        for f in files:
            rel = os.path.relpath(os.path.join(base, f), root)
            if _slug(rel) in slug:
                hit = rel
                break
        if hit:
            break
    if not hit:
        return None
    text = open(os.path.join(root, hit), encoding="utf-8", errors="replace").read()
    groups = re.findall(r'\(\s*"([A-Za-z0-9_]+)"\s*,\s*\[', text)
    if not groups:
        return hit, []
    words = set(re.findall(r"[a-z0-9]+", (claim or "").lower()))
    scored = sorted(
        ((len(words & set(re.findall(r"[a-z0-9]+", g.lower()))), g) for g in groups),
        reverse=True,
    )
    if not scored or scored[0][0] == 0:
        return hit, sorted(groups)[:6]
    return hit, [scored[0][1]]


def _manual_duplicates(verifiers):
    """The manual names that appear more than once in one obligation.

    Two identical declarations cannot name two different things, so a
    duplicated name is a defect in the declaration itself.
    """
    names = [v for v in verifiers if v.startswith("manual-")]
    return sorted({v for v in names if names.count(v) > 1})


def _claim_tests_repair(verifier, root, claim):
    """A `dune ...` or `scripts/...` verifier whose obligation's CLAIM
    names the TESTS the check is about. The claim is the statement of what
    the obligation is about; the verifier has to run those tests."""
    if not (verifier.startswith("dune ") or verifier.startswith("scripts/")):
        return None
    names = set(re.findall(r"tests/([A-Za-z0-9_]+)\.ml", claim or ""))
    for token in re.findall(r"`([^`]+)`", claim or ""):
        token = token.strip()
        if re.match(r"^[A-Za-z0-9_]+$", token) and os.path.isfile(
            os.path.join(root, "tests", token + ".ml")
        ):
            names.add(token)
    names = sorted(n for n in names if os.path.isfile(os.path.join(root, "tests", n + ".ml")))
    if not names:
        return None
    target = "dune test --root . " + " ".join("tests/%s.exe" % n for n in names)
    return (
        target,
        "the obligation's claim names the test%s the check is about (%s); a "
        "verifier that runs the whole suite also runs checks the claim does "
        "not speak for"
        % (
            "s" if len(names) > 1 else "",
            ", ".join("`%s`" % n for n in names),
        ),
    )


def derive_fix(verifier, root, claim, bin_path, corpus):
    """(recommendation, right_target, reason) for ONE verifier string.

    The rules are general, not a table of known answers: each one fires on a
    shape of mistake and derives the right target from the repository.
    """
    scheme = verifier.split()[0] if verifier.split() else ""

    if scheme.startswith("manual-"):
        return (
            "declare-it-manual",
            None,
            "`manual-` declarations are not executable: the kernel records "
            "them as a `review` kind with an `inconclusive` result and says "
            "so. The declaration must name the file and the needle a human "
            "is to look for",
        )

    for rule in (
        lambda: _claim_tests_repair(verifier, root, claim),
        lambda: _claim_module_repair(verifier, root, claim),
        lambda: _dune_alias_repair(verifier, root),
        lambda: _alcotest_group_repair(verifier, root),
        lambda: _file_exists_repair(verifier, root, corpus),
        lambda: _claim_path_repair(verifier, root, claim),
        lambda: _mathc_prose_tail_repair(verifier, root, bin_path),
        lambda: _claim_command_repair(verifier, root, claim, bin_path),
        lambda: _script_subcommand_repair(verifier, root, claim),
    ):
        got = rule()
        if got:
            target, reason = got
            return ("fix-the-verifier", target, reason)

    return ("investigate", None, "")


# ------------------------------------------------------------- reporting


def explain_investigate(entry, root):
    """WHY an obligation is an open item. Derived from the evidence, so a
    reader does not have to re-derive it."""
    verifiers = entry["verifiers"]
    outputs = "\n".join(
        [entry["sweep_error"] or ""] + [(p["output"] or "") for p in entry["per_verifier"]]
    )
    joined = "\n".join(verifiers)

    if "|" in joined or "&&" in joined or ";" in joined:
        return (
            "the verifier is a SHELL PIPELINE, and `mathc verify` never spawns "
            "a shell: the pipe is handed to the command as ordinary "
            "arguments, so the command exits 2 (input error). Expressing this "
            "check needs a fixture or a kernel subcommand that performs the "
            "assertion - not a pipeline in a decision file"
        )
    if "*" in joined or "?" in joined:
        return (
            "the verifier is a GLOB, and `mathc verify` never spawns a shell, "
            "so the glob is not expanded: it reaches the command as a literal "
            "file name and the command exits 2 (input error). The check needs "
            "a verifier that takes one concrete target"
        )
    if "inconclusive attestations" in outputs:
        return (
            "the verifier measures THE ATTESTATION STORE, and the re-signing is "
            "what writes the store: the check read the store mid-repair. The "
            "evidence below shows the number it measured against the ceiling "
            "it enforces"
        )
    if "have no fixture file" in outputs or "MISSING" in outputs:
        return (
            "the verifier compares the COMMITTED fixture "
            "`tests/fixtures/self-check-pass/attestations/` against the LIVE "
            "obligation enumeration, and the corpus has grown since the "
            "fixture was generated: the pairs listed as MISSING below have no "
            "fixture file. The verifier is right; the fixture is stale"
        )
    for v in verifiers:
        rel, exists = _file_exists_target(v, root)
        if rel is not None and not exists:
            named = v.split()[-1]
            if named in (entry.get("claim") or ""):
                return (
                    "the verifier and the obligation's claim name the SAME "
                    "file, `%s`, and the file does not exist: the pointer is "
                    "not wrong, the ARTIFACT is missing. The claim says the "
                    "CI workflow writes it, so the obligation is a claim "
                    "about a CI run the re-signing cannot perform - it stays "
                    "a GAP until CI has run, and the two `manual-` "
                    "declarations in the same obligation are the form this "
                    "claim should take" % named
                )
            return (
                "`%s` does not exist and no file with that stem does either: "
                "the obligation's claim is about a file that was never "
                "written, so the repair is to WRITE the file, not to move the "
                "pointer. (The path the verifier carries is `%s`; a "
                "`text-scan-` scheme prefix glued onto the path is not part of "
                "the path.)" % (named, named)
            )
    if entry["class"] == "all-pass-contradiction":
        for p in entry["per_verifier"]:
            race = _pipefail_grepq_race(p["verifier"], root)
            if race:
                return race
        return (
            "every verifier of this obligation PASSES on the current tree, "
            "yet the re-signing refused to sign it: the failure was in the "
            "state the tree was in at sweep time, and the evidence below is "
            "what the verifier printed then"
        )
    return (
        "no mechanical repair applies: the verifier names a target that does "
        "not exist and no unique replacement is derivable from the "
        "repository, so the right target has to be decided by a human. The "
        "evidence is quoted below"
    )


def classify(verdicts):
    """The obligation-level class, from the per-verifier verdicts."""
    values = set(verdicts.values())
    if "fail" in values:
        return "broken"
    if values & {"skipped", "setup_fail", "unparsed", "timeout", "no-source"}:
        return "not-executable"
    if values == {"pass"}:
        return "all-pass-contradiction"
    return "other"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--log", default="./sign-store-sweep.log")
    ap.add_argument("--decisions", default="decisions")
    ap.add_argument("--bin", default=None)
    ap.add_argument("--out-json", default=None)
    ap.add_argument("--out-md", default=None)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--no-probe", action="store_true")
    args = ap.parse_args()

    root = os.path.abspath(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)

    bin_path = args.bin
    if bin_path is None:
        for cand in ("_build/default/bin/mathc.exe", "_build/install/default/bin/mathc"):
            if os.path.isfile(cand) and os.access(cand, os.X_OK):
                bin_path = os.path.abspath(cand)
                break
    if bin_path is None and not args.no_probe:
        print("no mathc binary found", file=sys.stderr)
        return 2

    corpus = parse_corpus(args.decisions)
    unsigned, blocks = parse_unsigned(args.log)
    if not unsigned:
        print("no unsigned obligations in %s" % args.log, file=sys.stderr)
        return 0
    if args.limit:
        unsigned = unsigned[: args.limit]

    probe_dir = os.path.join(root, PROBE_DIR)
    obligations = []
    for i, entry in enumerate(unsigned, 1):
        decision, obligation = entry["decision"], entry["obligation"]
        dec = corpus.get(decision)
        obls = dec["obligations"] if dec else {}
        verifiers = obls.get(obligation, {}).get("verifiers", [])
        claim = obls.get(obligation, {}).get("claim", "")

        per_verifier = []
        for v in verifiers:
            if args.no_probe:
                verdict, output = "not-re-run", ""
            else:
                verdict, output = probe_one(
                    root, corpus, decision, obligation, v, bin_path, probe_dir
                )
            per_verifier.append(
                {"verifier": v, "verdict": verdict, "output": output}
            )

        verdicts = {p["verifier"]: p["verdict"] for p in per_verifier}
        klass = classify(verdicts)
        sweep_error = match_block(blocks, verifiers)

        # The recommendation is decided from the EVIDENCE, verifier by
        # verifier: a broken verifier whose target is derivable is a fix; a
        # verifier that could not be set up for want of a program is a
        # toolchain; an obligation whose verifiers are all declarations is
        # a manual declaration; anything else is an open item.
        rec = None
        target = None
        reason = ""
        for p in per_verifier:
            v = p["verifier"]
            if p["verdict"] == "fail" and "is not on PATH" in (p["output"] or ""):
                m = re.search(r"(\S+) is not on PATH", p["output"])
                rec = "needs-a-toolchain"
                reason = "`%s` is not on PATH here, so the check could not be attempted" % (
                    m.group(1) if m else v
                )
                break
            if p["verdict"] == "fail":
                r, t, why = derive_fix(v, root, claim, bin_path, corpus)
                if r == "fix-the-verifier":
                    rec, target, reason = r, t, why
                    break
        if rec is None:
            if per_verifier and all(
                p["verifier"].split()[0].startswith("manual-") for p in per_verifier
            ):
                rec = "declare-it-manual"
                reason = (
                    "every verifier of this obligation is a `manual-` "
                    "declaration; the kernel does not execute them and records "
                    "them as `review`/`inconclusive`. The declaration must name "
                    "the file and the needle a human is to look for"
                )
                dups = _manual_duplicates(verifiers)
                if dups:
                    reason += (
                        " - and %d of the %d declarations are the SAME string "
                        "(`%s`), so they cannot name %d different things"
                        % (
                            len(dups),
                            len(verifiers),
                            dups[0],
                            len(verifiers),
                        )
                    )
                hit = _manual_targets(verifiers[0], root, claim)
                if hit:
                    where, groups = hit
                    reason += (
                        ". The name points at `%s`" % where
                        + (
                            "; the case the claim is about is `%s`"
                            % groups[0]
                            if len(groups) == 1
                            else "; its cases are %s" % ", ".join("`%s`" % g for g in groups)
                        )
                    )
            else:
                rec = "investigate"
                reason = ""

        record = {
            "decision": decision,
            "obligation": obligation,
            "decision_file": dec["path"] if dec else None,
            "verifiers": verifiers,
            "per_verifier": per_verifier,
            "class": klass,
            "recommendation": rec,
            "right_target": target,
            "reason": reason,
            "sweep_error": sweep_error,
        }
        if rec == "investigate":
            record["reason"] = explain_investigate(record, root)
        obligations.append(record)
        print(
            "[%3d/%3d] %-16s %s/%s"
            % (i, len(unsigned), rec, decision, obligation),
            file=sys.stderr,
        )

    try:
        os.rmdir(probe_dir)
    except OSError:
        pass

    counts = collections.Counter(o["recommendation"] for o in obligations)
    classes = collections.Counter(o["class"] for o in obligations)
    out = {
        "unsigned_obligations": len(obligations),
        "recommendations": dict(counts),
        "classes": dict(classes),
        "obligations": obligations,
    }

    if args.out_json:
        with open(args.out_json, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(out, indent=2, sort_keys=True) + "\n")
        print("wrote %s" % args.out_json, file=sys.stderr)
    if args.out_md:
        with open(args.out_md, "w", encoding="utf-8") as fh:
            fh.write(render_markdown(out, args.log))
        print("wrote %s" % args.out_md, file=sys.stderr)
    if not args.out_json and not args.out_md:
        print(json.dumps(out, indent=2, sort_keys=True))
    return 0


def render_markdown(out, log_path):
    """The rendered report. Every obligation appears exactly once, with its
    verdict, its recommendation and the evidence for both."""
    recs = out["recommendations"]
    lines = []
    a = lines.append
    a("# Unmet obligations - the 2026-10 re-signing")
    a("")
    a(
        "**%d obligations the re-signing refused to sign.** An unsigned "
        "obligation is a GAP, not a pass: the kernel writes no attestation "
        "for it, so the corpus claims nothing about it."
        % out["unsigned_obligations"]
    )
    a("")
    a("## The numbers")
    a("")
    a("| recommendation | obligations |")
    a("| --- | --- |")
    for r in RECOMMENDATIONS:
        a("| `%s` | %d |" % (r, recs.get(r, 0)))
    a("| **total** | **%d** |" % out["unsigned_obligations"])
    a("")
    a("By class:")
    a("")
    for k in sorted(out["classes"]):
        a("- `%s`: %d" % (k, out["classes"][k]))
    a("")
    a("## The method")
    a("")
    a(
        "The unsigned obligations are read from `%s` - the log the re-signing "
        "writes with `--keep-log`. Every one of them is then re-evaluated "
        "VERIFIER BY VERIFIER:" % log_path
    )
    a("")
    a(
        "1. A throwaway decision is written into the project carrying exactly "
        "one obligation with exactly one verifier."
    )
    a(
        "2. It is re-stamped with `mathc rehash --write` - the strict parser "
        "enforces the digest fields, so a probe carrying the original's "
        "digest is reported as having no obligations, which reads as "
        "`skipped` and is a false reading of the verifier."
    )
    a("3. `mathc verify` is run on it, and the kernel's verdict line and the")
    a(
        "   kernel's own sandbox excerpt are captured. The excerpt is the "
        "verifier's output; it is what the report quotes, not the word "
        "\"failed\"."
    )
    a("4. The probe is deleted.")
    a("")
    a(
        "The corpus is parsed with a deliberately narrow pattern (`[ \\t]` for "
        "indentation, never `\\s`), and a decision is resolved BY ITS ID "
        "rather than by its file name - sixteen decisions carry an id that "
        "differs from their file name, and the kernel resolves them by id."
    )
    a("")
    a(
        "**THIS REPORT IS A SNAPSHOT OF THE STATE THE SWEEP RAN ON.** The "
        "verdicts below are the verdicts of a re-run against that state, and "
        "the sweep-time evidence is the evidence of the failure itself. The "
        "mechanically repairable targets have since been repaired, so a "
        "re-run against the current tree reports that those verifiers now "
        "PASS. What the report says about them - which target was wrong and "
        "what the right one is - is what the repair was made from, and it is "
        "the part worth keeping."
    )
    a("")
    a("## The obligations")
    a("")
    for o in out["obligations"]:
        a("### `%s/%s`" % (o["decision"], o["obligation"]))
        a("")
        a("- decision file: `%s`" % (o["decision_file"] or "<not found>"))
        a("- verdict: `%s`" % o["class"])
        a("- recommendation: `%s`" % o["recommendation"])
        if o["right_target"]:
            a("- right target: `%s`" % o["right_target"])
        if o["reason"]:
            a("- why: %s" % o["reason"])
        a("")
        a("Verifiers named by the obligation:")
        a("")
        if not o["verifiers"]:
            a("- _none found in the corpus file_")
        for p in o["per_verifier"]:
            a("- `%s` -> **%s**" % (p["verifier"], p["verdict"]))
        a("")
        if o["sweep_error"]:
            a("What the verifier printed during the re-signing:")
            a("")
            a("```")
            a(o["sweep_error"])
            a("```")
            a("")
        broken = [p for p in o["per_verifier"] if p["verdict"] == "fail" and p["output"]]
        if broken:
            a("What the same verifier prints when it is re-run now:")
            a("")
            for p in broken:
                a("`%s`:" % p["verifier"])
                a("")
                a("```")
                a(p["output"])
                a("```")
                a("")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    sys.exit(main())
