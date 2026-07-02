# Decision: 0005 — Soft Conventions

## Status

Accepted.

## Context

Hard enforcement of conventions blocks the user. Soft
conventions report violations and let the user decide.

## Decision

The convention is enforced by the verifier, not by tooling
that blocks the user. The verifier reports which packets
violate the convention and how. The user decides whether to
fix the packet or override the convention (with documentation
in `# Adaptations`).

## Consequences

- A user who deviates from the convention sees a verifier
  failure but can proceed.
- Deviations are recorded in git diff and in `# Adaptations`.
- The convention can be updated to accommodate new patterns by
  adding a new packet (ADR) and updating the verifier.

## Alternatives considered

- **Hard enforcement**: too rigid, breaks legitimate edge cases,
  contradicts ADR-0001 (fractal property requires flexibility).