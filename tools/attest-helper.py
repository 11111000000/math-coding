#!/usr/bin/env python3
"""Generate math-coding attestation JSON files (helper).

Per `scripts/generate-attestations.py`. Same canonicalisation:
sort_keys=True, separators=(",", ":"), ensure_ascii=False.

Usage:
    tools/attest-helper.py DECISION OBLIGATION KIND_ IDENTITY [RESULT] [ISSUED_AT]

Emits to stdout a single attestation JSON object.
"""
import json, hashlib, sys

ISSUED_AT_DEFAULT = "2026-10-15T00:00:00Z"

def make_att(decision, obligation, kind_, identity, result="pass", issued_at=ISSUED_AT_DEFAULT):
    return {
        "schema": "math-coding/attestation-3.0-alpha",
        "kind": "attestation",
        "subject": {
            "decision": decision,
            "obligation": obligation,
            "candidate_tree": "HEAD",
            "materials_digest": "",
        },
        "kind_": kind_,
        "producer": {"identity": identity},
        "result": result,
        "issued_at": issued_at,
    }


def canonical(att):
    body = {k: v for k, v in att.items() if k != "id"}
    return json.dumps(body, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def emit(decision, obligation, kind_, identity, result, issued_at):
    att = make_att(decision, obligation, kind_, identity, result, issued_at)
    att["id"] = "sha256:" + hashlib.sha256(canonical(att)).hexdigest()
    return att


if __name__ == "__main__":
    if len(sys.argv) < 5:
        sys.exit("usage: attest-helper.py DECISION OBLIGATION KIND_ IDENTITY [RESULT] [ISSUED_AT]")
    decision, obligation, kind_, identity = sys.argv[1:5]
    result = sys.argv[5] if len(sys.argv) > 5 else "pass"
    issued_at = sys.argv[6] if len(sys.argv) > 6 else ISSUED_AT_DEFAULT
    att = emit(decision, obligation, kind_, identity, result, issued_at)
    print(json.dumps(att, separators=(",", ":"), ensure_ascii=False))
