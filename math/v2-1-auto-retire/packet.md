---
schema_version: "2.1"
name: v2-1-auto-retire
proposition: "mathc supersede automatically marks the old packet as state=retired and writes superseded_by, eliminating the applied-but-superseded limbo."
register: judgment
state: draft
actor: human
confidence: 1.00
kind: policy
beneficiary: developer
superseded_by:
---

## Why

Packets with superseded_by populated but state=applied (e.g. agents-protocol) are a known limbo that confuses readers.

## Care

Auto-retire commits to a chain: the new packet must be applied first; if it isn't, retire shouldn't happen.

## Thesis

mathc supersede OLD NEW PROP atomically: creates NEW with state=draft and witness at HEAD, edits OLD to add superseded_by and state=retired.

## Antithesis

Auto-modifying state without explicit consent surprises users; manual retire via transition is more predictable.

## Synthesis

Supersession is by definition a state change. Auto-retire is the natural extension; users opt out by editing OLD manually after supersede.
