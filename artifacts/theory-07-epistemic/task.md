# Theory 07 — Epistemic State

## Problem

`assumptions.yaml` carries epistemic markers (`fact`,
`hypothesis`, `judgment`, `unknown`) but does not define the
epistemic logic an agent should apply. Without a belief-update
protocol, an agent treats every assumption identically —
which defeats the purpose of the markers.

## Desired outcome

A document that:
- Defines belief state $B(\text{agent}, P)$ as a graded
  function over propositions
- Defines belief updates on evidence
- Maps epistemic markers to belief intervals
- Specifies the **action protocol** for an agent reading an
  assumption: what to do for each marker

## Constraints

- Two-layer scheme: mandatory (judgment, unknown) vs
  auto-inferred (fact, hypothesis)
- The protocol must be implementable in agents.md as a table
- Numerical confidence is optional but encouraged

# Adaptations

(none)