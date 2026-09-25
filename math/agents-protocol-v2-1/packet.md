---
schema_version: "2.1"
name: agents-protocol-v2-1
proposition: "v2.1 protocol: mathc decide is the one-step command; convention documents its own kernel; AGENTS.md regenerates from this packet."
register: judgment
state: applied
actor: human
confidence: 1.00
kind: policy
beneficiary: developer
superseded_by:
---

## Why

v2.0-Y protocol documented five-step manual flow (record, commit, amend, commit, review) which causes draft limbo; v2.1 collapses to one command and enforces dialectic for judgment.

## Care

Auto-retire on supersede changes state without explicit confirmation; agents editing old packets manually after supersede will see drift.

## Thesis

AI agents working on a math-coding project record non-trivial decisions as packets through mathc decide; the convention describes protocol via the same kernel that verifies user packets. Y-fixed-point: foundation packets verify with the same kernel.

## Antithesis

Centralizing protocol in one packet makes it a single point of failure; if agents-protocol-v2-1 is wrong, all subsequent packets inherit the error.

## Synthesis

Single packet is the right shape: a v2.1 protocol is a coherent design choice, not a list of options. Drift detection catches divergence. v2-1-decide-command is the implementation, this packet is the documentation.
