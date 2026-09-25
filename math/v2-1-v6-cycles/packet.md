---
schema_version: "2.1"
name: v2-1-v6-cycles
proposition: "Kernel walks the superseded_by graph and returns Fail V6 on cycles, self-loops, and broken links; previously a known divergence."
register: judgment
state: draft
actor: human
confidence: 1.00
kind: policy
beneficiary: developer
superseded_by:
---

## Why

Cycles in supersession (A -> B -> A) make it impossible to determine which decision is current; the convention must detect them.

## Care

Performance: O(N) per packet on graph walk; total O(N^2). For 1000 packets, this is fast enough; for 100k, needs indexing.

## Thesis

check_supersession builds a name->decision map, walks superseded_by chain, returns Fail if any visited node revisits or targets a missing node.

## Antithesis

Detection is too late: by the time check runs, the cycle is committed to git. Prevention is better.

## Synthesis

Detection is a safety net for prevention; mathc supersede never creates cycles, but external edits could. Detection closes the gap.
