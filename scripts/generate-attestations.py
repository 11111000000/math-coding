#!/usr/bin/env python3
"""Generate math-coding attestation JSON files.

Reads a manifest from stdin (TSV: decision<TAB>obligation<TAB>kind_<TAB>producer_identity)
and emits one attestation JSON per row in the configured
attestations directory. Id is computed as sha256: + SHA-256 of
the canonical JSON (serialised without `id`, sorted keys, no
whitespace).

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
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # scripts/ -> repo root
DECISIONS_DIR = Path(
    os.environ.get("MATH_CODING_DECISIONS_DIR", str(ROOT / "decisions"))
)
ATTESTATIONS_DIR = Path(
    os.environ.get("MATH_CODING_ATTESTATIONS_DIR", str(ROOT / "attestations"))
)

ISSUED_AT = "2026-09-29T18:00:00Z"
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
    path.write_text(json.dumps(att, indent=None, separators=(",", ":"), ensure_ascii=False) + "\n")
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
