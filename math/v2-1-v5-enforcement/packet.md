---
schema_version: "2.1"
name: v2-1-v5-enforcement
proposition: "Packets with register=judgment must have non-empty ## Why, ## Antithesis, ## Synthesis sections; kernel returns Fail V7 otherwise."
register: judgment
state: draft
actor: human
confidence: 1.00
kind: policy
beneficiary: developer
superseded_by:
---

## Why

Empty dialectic sections in judgment packets are a recurring failure mode (8 foundation packets had them empty); without enforcement, the convention lies.

## Care

Strict enforcement blocks legitimate work in flight; agents must know to populate sections before mathc check passes.

## Thesis

check_dialectic reads body_sections from Decision and returns Fail V7 if any of Why/Antithesis/Synthesis is missing or empty for register=judgment.

## Antithesis

Body sections are stylistic; some judgments don't need full dialectic (e.g., 'this is reversible, no mitigation needed').

## Synthesis

Enforce only for register=judgment; for hypothesis/fact/unknown, body is free Markdown. Empty bodies are still allowed.
