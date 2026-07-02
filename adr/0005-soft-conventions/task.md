# ADR 0005 — Soft Conventions

## Problem

Should the convention be hard-enforced (blocking the user on
violations) or soft-enforced (reporting but not blocking)?
Hard enforcement is rigid; soft enforcement requires the user
to take responsibility for deviations.

## Desired outcome

The convention is enforced by the verifier, which reports
violations but does not block. The user decides whether to fix
the packet or override the convention with documentation in
# Adaptations.

## Constraints

- must No blocking tooling
- Deviations must be explicit
- Override is documented in # Adaptations
