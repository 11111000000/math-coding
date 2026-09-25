---
schema_version: "2.1"
name: v2-1-sane-defaults
proposition: ".mathrc is optional; without it, defaults (SIGNING_MODE=off, AUTO_AMEND=true, DIALECTIC_REQUIRED.judgment=[Why,Antithesis,Synthesis]) apply."
register: judgment
state: draft
actor: human
confidence: 1.00
kind: policy
beneficiary: developer
superseded_by:
---

## Why

Requiring .mathrc adds friction for new projects; 95% of projects use defaults and only override for specific needs.

## Care

Defaults that hide errors (like FACT_POLICY=warn) may surprise users who expect fail; defaults should be visible in cmd_init.

## Thesis

Signing.get falls back to defaults when key is missing; cmd_init writes .mathrc with explicit defaults for discoverability.

## Antithesis

Hidden defaults make it harder to understand why the kernel behaves a certain way.

## Synthesis

.mathrc is opt-in for overrides; cmd_init writes defaults explicitly so users see what they're accepting.
