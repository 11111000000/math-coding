# 05-accounting

## Problem

How does the convention record what it knows, what it has
checked, what has changed, and what has been replaced?

## Desired outcome

An epistemic axiom — A5 — that fixes five epistemic
markers, five verdict outcomes, the SHA witness convention,
the supersession DAG, and the three modes.

## Constraints

- Five epistemic markers. Fewer loses distinction; more
  adds noise.
- Five verdict outcomes: VERIFIED, NEEDS_REVISION,
  UNVERIFIABLE:TOOL_MISSING, UNVERIFIABLE:DEFERRED,
  UNVERIFIABLE:OUT_OF_SCOPE.
- Every change carries a git SHA in `applications:`.
- Supersession is a strict partial order.
- Three modes: light (commit only), standard (5-file
  packet), strict (packet + theory link).