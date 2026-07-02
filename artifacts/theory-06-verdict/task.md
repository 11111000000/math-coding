# Theory 06 — Verdict

## Problem

The convention defines five verdicts (`VERIFIED`,
`NEEDS_REVISION`, `UNVERIFIABLE:TOOL_MISSING`,
`UNVERIFIABLE:OUT_OF_SCOPE`, `UNVERIFIABLE:DEFERRED`) but
without explaining what each means **as a mathematical
statement**. An agent cannot reason about verdicts without
knowing what theorem is being claimed.

## Desired outcome

A document that:
- Defines each verdict as a logical statement about the spec,
  the model, and the verification context
- States the conditions under which each verdict is achievable
- Connects to model checking (TLC) and proof (TLAPS)
- Distinguishes "verified" (proved) from "not yet verified"
  (open)

## Constraints

- Each verdict maps to a logical statement of the form
  $\text{Spec} \models P$ or its negation
- UNVERIFIABLE:* are epistemic about the verification process,
  not about the spec itself

# Adaptations

(none)