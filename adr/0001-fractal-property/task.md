# ADR 0001 — Fractal Property

## Problem

A methodology that does not apply to itself cannot be trusted.

## Desired outcome

`core/core.md` lives inside a packet. The verifier lives inside
a packet. Every change to the convention goes through the
convention's own pipeline.

## Constraints

- The convention must remain small enough to be self-verified
- A complete self-application packet must have refinement.md
  and traceability.json

# Adaptations

(none)