---
schema_version: "2.0"
name: process-fsm
proposition: "Decisions exist in five states (draft, applied, reviewed, retired, abandoned); the single forbidden transition is draft → reviewed without witness. Without an explicit state machine, a packet remains 'applied' by default and review loses meaning. With a five-state machine, each decision traverses an explicit path: from proposition (draft) to inhabitation (applied) to human review (reviewed), with possible exit through retired or abandoned. The forbidden transition draft → reviewed without witness closes a trivial bypass: one cannot declare a decision reviewed without passing through inhabitation via git fix. This is the minimal sufficient restriction: one rule closes all bypasses."
register: hypothesis
state: draft
actor: human
confidence: 0.7
superseded_by:
---

## Why

## Care

## Thesis

## Antithesis

## Synthesis

## Notes
