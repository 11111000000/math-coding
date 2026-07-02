# Self-application — convention verifies itself

## Problem

The math-coding convention must apply to itself (fractal
property, ADR-0001). This packet demonstrates self-application:
it has all required files, includes the verifier, and the
verifier itself conforms to the conventions.

## Desired outcome

A complete packet that:

- Has all required files (packet.yaml, task.md, assumptions.yaml,
  refinement.md, traceability.json)
- Has a verifier (verify-consistency.sh)
- Has a verifier-output.yaml that includes provenance

## Constraints

- The verifier is implemented in plain shell, no Python
- Verifier checks structural invariants mechanically

# Adaptations

(none)