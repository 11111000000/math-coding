# Self-Application v2

## Problem

The v1 self-application packet had only `verify-consistency.sh`
and no `refinement.md` / `traceability.json`. This was a
**partial fractal**: the convention did not fully apply to
itself.

## Desired outcome

A complete self-application packet:

- Has all required files (packet.yaml, task.md, assumptions.yaml)
- Has refinement.md with five sections
- Has traceability.json with links
- Includes verify-consistency.sh that **implements** the
  invariants from core/core.md

## Constraints

- The verifier must check **all** structural invariants
- The verifier must report provenance (verified_at, scope, tool,
  evidence)

# Adaptations

(none)