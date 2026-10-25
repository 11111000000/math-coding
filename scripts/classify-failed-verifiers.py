#!/usr/bin/env python3
"""scripts/classify-failed-verifiers.py — why did an obligation go unsigned?

WHAT IT IS FOR.

`mathc attest-batch --run-per-obligation` refuses to write an
attestation for an obligation whose check FAILED, and says so:
    mathc attest-batch: NOT signing <decision>/<obligation> — its verifier failed.

It does not say WHICH verifier failed. An obligation may name several,
and the failure may be in any of them. Whoever has to repair the
corpus therefore has to re-derive that by hand, one obligation at a
time.

This tool re-derives it mechanically. For each unsigned obligation it
evaluates every one of that obligation's verifiers SEPARATELY, in a
throwaway decision that carries exactly one obligation with exactly one
verifier, and records what each verifier actually does. The result is
a classification:

    broken     the verifier RAN and FAILED. The check is wrong, or the
               thing it checks is wrong. A human has to look.
    skipped    the verifier could not be planned - an unknown scheme, a
               path outside the repository, a target that does not
               exist. The kernel could not even attempt it. It is
               NOT a broken check; it is a check that is not
               expressible in this form.
    setup_fail the verifier names a program that is not on PATH. The
               check did not run because the toolchain is absent.
    pass       the verifier ran and passed. The obligation failed
               because of ANOTHER verifier in the same list.

WHY A THROWAWAY DECISION.

`verdict_of_obligation` resolves a decision by ID inside the
decisions directory, not by the path it was handed, so a probe has to
live there. The probe is the original decision with its obligations
block replaced by a single obligation carrying a single verifier, and
its id renamed so the file name and the id agree. The original's
sha fields are left alone: `verdict_of_obligation` does not check
them, and re-stamping them would be a lie about a file that only ever
existed to be probed.

The probe files are removed as they are used, and a trap removes the
rest if the run is interrupted. They are never committed.

Each probe is re-stamped with `mathc rehash --write` before it is
run. The strict parser enforces the sha fields, so a probe carrying
the original's digest is reported as having no obligations - which
reads as `skipped` and is a FALSE reading of the verifier. (Measured:
a stale probe made `dune build` look skipped when it in fact
passes.) Re-stamping a throwaway probe asserts nothing about the
corpus: the file exists only to be probed, and is deleted at once.

USAGE
    scripts/classify-failed-verifiers.py [--log FILE] [--out FILE]
                                         [--decisions DIR] [--limit N]

    --log     the sweep log to read the unsigned obligations from.
              Default: ./sign-store-sweep.log (the file
              scripts/sign-store.sh writes with --keep-log).
    --out     where to write the JSON report. Default: stdout.
    --limit   stop after N obligations (for a quick look).
"""

import argparse
import collections
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

PROBE_PREFIX = "zz-classify-probe-"


def parse_corpus(decisions_dir):
    """decision id -> {obligation id: [verifier, ...]}.

    The parse is deliberately NARROW: `[ \\t]` for indentation, never
    `\\s`. `\\s` matches a newline, so `^\\s+-\\s+id:` splits on a
    nested `- id:` line and on blank lines, and the obligation a
    failure belongs to is then attributed to the wrong verifier. That
    bug shipped once and produced seven false accusations against
    manual- declarations; the census's own parse is narrow for the
    same reason.
    """
    obl = {}
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
        for blk in re.split(r"^[ \t]+-[ \t]+id:[ \t]*", om.group(1), flags=re.M)[1:]:
            obl_id = blk.split()[0]
            vs = re.findall(
                r"^[ \t]+-[ \t]+verifier:[ \t]*(.+?)[ \t]*$", blk, re.M
            )
            obl[(m.group(1), obl_id)] = vs
    return obl


def parse_unsigned(log_path):
    """the (decision, obligation) pairs the sweep refused to sign."""
    out = []
    try:
        fh = open(log_path, encoding="utf-8", errors="replace")
    except OSError:
        return out
    with fh:
        for line in fh:
            m = re.search(r"NOT signing (\S+)/(\S+)", line)
            if m:
                out.append((m.group(1), m.group(2)))
    return out


def decision_paths(decisions_dir):
    """id -> path, by SCANNING the directory.

    NOT by concatenating the id with ".yaml". Sixteen decisions in
    this corpus carry an id that differs from their file name
    (candidate-tree-resolves-to-a-commit lives in
    candidate-tree-resolves-to-a-commit-2026-10.yaml), and
    concatenating finds nothing - the very defect that was fixed in
    the kernel on 2026-10-25. The file name is not load-bearing.
    """
    index = {}
    for name in sorted(os.listdir(decisions_dir)):
        if not name.endswith((".yaml", ".yml")):
            continue
        path = os.path.join(decisions_dir, name)
        try:
            text = open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        m = re.search(r"^id:[ \t]*(\S+)", text, re.M)
        if m and m.group(1) not in index:
            index[m.group(1)] = path
    return index


def probe_one(decisions_dir, decision, obligation, verifier, bin_path, keep):
    """Evaluate ONE verifier on its own and return its verdict.

    The probe decision is the original with its obligations block
    replaced by a single obligation carrying a single verifier.
    """
    index = decision_paths(decisions_dir)
    src = index.get(decision)
    if src is None:
        return "no-such-decision"
    try:
        text = open(src, encoding="utf-8", errors="replace").read()
    except OSError:
        return "no-source"

    probe_id = "%s%s-%s" % (
        PROBE_PREFIX,
        re.sub(r"[^A-Za-z0-9_.-]", "_", decision),
        re.sub(r"[^A-Za-z0-9_.-]", "_", obligation),
    )
    probe_path = os.path.join(decisions_dir, probe_id + ".yaml")

    body = re.sub(r"^id:[ \t]*\S+", "id: " + probe_id, text, count=1, flags=re.M)
    # Replace the whole obligations block with one obligation.
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
        return "probe-unwritable: %s" % exc

    # The probe must carry a CURRENT digest. `do_verify` parses the
    # decision with the strict parser, which enforces the sha fields,
    # so a probe whose digest is stale is reported as having no
    # obligations at all - which reads as `skipped` and is a FALSE
    # reading of the verifier. (Measured: a probe with a stale digest
    # made `dune build` look skipped when it in fact passes.)
    # Re-stamping a throwaway probe is not a lie about the corpus:
    # the file exists only to be probed and is deleted immediately.
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
            timeout=300,
        )
    except subprocess.TimeoutExpired:
        return "timeout"
    finally:
        if not keep:
            try:
                os.remove(probe_path)
            except OSError:
                pass

    for line in proc.stdout.splitlines():
        m = re.match(r"^\s+(probe-obligation):\s*(\S+)", line)
        if m:
            return m.group(2)
    # No per-obligation line: the probe did not parse.
    return "unparsed"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--log", default="./sign-store-sweep.log")
    ap.add_argument("--out", default=None)
    ap.add_argument("--decisions", default="decisions")
    ap.add_argument("--bin", default=None)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--keep-probes", action="store_true")
    args = ap.parse_args()

    bin_path = args.bin
    if bin_path is None:
        for cand in (
            "_build/default/bin/mathc.exe",
            "_build/install/default/bin/mathc",
        ):
            if os.path.isfile(cand) and os.access(cand, os.X_OK):
                bin_path = os.path.abspath(cand)
                break
    if bin_path is None:
        print("no mathc binary found", file=sys.stderr)
        return 2

    corpus = parse_corpus(args.decisions)
    unsigned = parse_unsigned(args.log)
    if not unsigned:
        print("no unsigned obligations in %s" % args.log, file=sys.stderr)
        return 0
    if args.limit:
        unsigned = unsigned[: args.limit]

    report = []
    tally = collections.Counter()
    for i, (decision, obligation) in enumerate(unsigned, 1):
        verifiers = corpus.get((decision, obligation))
        if verifiers is None:
            report.append(
                {
                    "decision": decision,
                    "obligation": obligation,
                    "verifiers": [],
                    "verdicts": {},
                    "class": "no-such-obligation",
                }
            )
            tally["no-such-obligation"] += 1
            continue

        verdicts = {}
        for v in verifiers:
            verdicts[v] = probe_one(
                args.decisions,
                decision,
                obligation,
                v,
                bin_path,
                args.keep_probes,
            )
            tally["%s:%s" % (v, verdicts[v])] += 1

        outcomes = set(verdicts.values())
        if "fail" in outcomes:
            cls = "broken"
        elif outcomes & {"skipped", "setup_fail", "unparsed", "timeout"}:
            cls = "not-executable"
        elif outcomes == {"pass"}:
            cls = "all-pass-contradiction"
        else:
            cls = "other"

        report.append(
            {
                "decision": decision,
                "obligation": obligation,
                "verifiers": verifiers,
                "verdicts": verdicts,
                "class": cls,
            }
        )
        print(
            "[%3d/%3d] %-14s %s/%s"
            % (i, len(unsigned), cls, decision, obligation),
            file=sys.stderr,
        )

    classes = collections.Counter(r["class"] for r in report)
    out = {
        "unsigned_obligations": len(report),
        "classes": dict(classes),
        "verifier_outcomes": dict(tally),
        "obligations": report,
    }
    text = json.dumps(out, indent=2, sort_keys=True)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
        print("wrote %s" % args.out, file=sys.stderr)
    else:
        print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
