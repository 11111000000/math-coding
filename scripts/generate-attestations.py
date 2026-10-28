#!/usr/bin/env python3
"""Write math-coding attestation JSON files.

Reads a manifest from stdin (TSV: decision<TAB>obligation<TAB>kind_<TAB>producer_identity)
and writes one attestation JSON per row into the configured
attestations directory. Id is computed as sha256: + SHA-256 of
the canonical JSON (serialised without `id`, sorted keys, no
whitespace).

WHERE THE FILES GO. The attestation store is GENERATED evidence,
not a committed artefact: `.gitignore` excludes `/attestations/`,
and CI regenerates the store and uploads it as a build artefact
instead of reading one out of the tree (decision
decisions/store-not-committed-2026-10.yaml). The default target
below is the working tree's store.

IDEMPOTENCE. This script writes what the manifest names, and
nothing else: running it twice over the same manifest leaves the
same files with the same names and the same content. It does NOT
delete files it did not write - which files belong in the store is
the generation path's question, not this writer's
(scripts/sign-store.sh owns it, and it answers it by dropping
everything a run did not observe).

Output directory selection (in order of precedence):
  1. $MATH_CODING_ATTESTATIONS_DIR (if set)
  2. <repo_root>/attestations (default fallback)

The decisions-directory selection is also honoured for
parity with the kernel's MATH_CODING_DECISIONS_DIR semantics,
even though this script does not currently read decisions:
  1. $MATH_CODING_DECISIONS_DIR (if set)
  2. <repo_root>/decisions (default fallback)

Usage:
  python3 scripts/generate-attestations.py [--help]
  cat manifest.tsv | python3 scripts/generate-attestations.py

Environment variables:
  MATH_CODING_ATTESTATIONS_DIR  Directory where .json files are written.
  MATH_CODING_DECISIONS_DIR     Directory the kernel treats as the
                                decisions root (read-only here;
                                declared for parity).
"""
import argparse
import hashlib
import json
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # scripts/ -> repo root
DECISIONS_DIR = Path(
    os.environ.get("MATH_CODING_DECISIONS_DIR", str(ROOT / "decisions"))
)
ATTESTATIONS_DIR = Path(
    os.environ.get("MATH_CODING_ATTESTATIONS_DIR", str(ROOT / "attestations"))
)

ISSUED_AT = "2026-09-29T18:00:00Z"

# The literal "HEAD" is a POINTER, not a fact: it resolves to
# whatever HEAD is when the file is read, so the attestation it
# names can be neither reproduced nor refuted. The kernel refuses to
# write such a field (bin/Mathc.ml::resolve_candidate_tree, decision
# candidate-tree-resolves-to-a-commit-2026-10), and this twin has
# carried the constant since. The decision that governs the field
# scopes itself to bin/ and lib/ and records this constant there as
# a known, still-open defect with a named review signal; it is NOT
# changed here, because the value is part of the id of every
# attestation this script has ever written and re-minting those ids
# is a decision about the corpus, not about this writer.
CANDIDATE_TREE = "HEAD"


def make_attestation(decision: str, obligation: str, kind_: str, identity: str, result: str = "pass") -> dict:
    return {
        "schema": "math-coding/attestation-3.0-alpha",
        "kind": "attestation",
        "subject": {
            "decision": decision,
            "obligation": obligation,
            "candidate_tree": CANDIDATE_TREE,
            "materials_digest": "",
        },
        "kind_": kind_,
        "producer": {"identity": identity},
        "result": result,
        "issued_at": ISSUED_AT,
    }


def canonical_json(obj: dict) -> bytes:
    """Sort keys, no whitespace, ensure_ascii=False (per AGENTS.md / source-map line 280-282)."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def attestation_id(att: dict) -> str:
    # id is computed over the canonical JSON without the id field.
    body = {k: v for k, v in att.items() if k != "id"}
    payload = canonical_json(body)
    digest = hashlib.sha256(payload).hexdigest()
    return f"sha256:{digest}"


def emit(decision: str, obligation: str, kind_: str, identity: str, result: str = "pass") -> Path:
    ATTESTATIONS_DIR.mkdir(parents=True, exist_ok=True)
    att = make_attestation(decision, obligation, kind_, identity, result)
    att["id"] = attestation_id(att)
    name = f"{decision}-{obligation}.json"
    path = ATTESTATIONS_DIR / name
    payload = json.dumps(att, indent=None, separators=(",", ":"), ensure_ascii=False) + "\n"
    # ATOMIC. The store is read WHILE it is written - the gate reads
    # it, the self-check reads it, and a sweep rewrites it - so a
    # reader must never see a half-written file. The write goes to a
    # temporary file in the SAME directory and is renamed over the
    # target: the rename is atomic within a directory, so a reader
    # sees either the previous file or the new one.
    #
    # The temporary file does NOT end in `.json`: the kernel's store
    # loader admits every file with that extension
    # (lib/attestations/attestations.ml), and a half-written
    # attestation with that name would be read as evidence.
    fd, tmp = tempfile.mkstemp(dir=str(ATTESTATIONS_DIR), prefix=".tmp-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(payload)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.remove(tmp)
        except OSError:
            pass
        raise
    # validate against schema's id pattern
    import re
    assert re.match(r"^sha256:[0-9a-f]{64}$", att["id"]), att["id"]
    return path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="generate-attestations",
        description=(
            "Generate math-coding attestation JSON files from a TSV "
            "manifest on stdin. See module docstring for env-var semantics."
        ),
    )
    parser.parse_args(argv)
    for line in sys.stdin:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 4:
            print(f"skip malformed: {line!r}", file=sys.stderr)
            continue
        decision, obligation, kind_, identity = parts[:4]
        result = parts[4] if len(parts) >= 5 else "pass"
        path = emit(decision, obligation, kind_, identity, result)
        print(f"wrote {path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
