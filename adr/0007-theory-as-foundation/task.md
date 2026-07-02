# ADR 0007 — Theory as Foundation

## Problem

Rules without mathematical grounding feel arbitrary to readers
and AI agents. Adoption is shallow because each rule appears
to be a convention without justification.

## Desired outcome

Eight theory documents live in core/01-Theory/. Each section
of core.md cites its theoretical foundation. AI agents reading
the convention can reason about each rule from first principles.

## Constraints

- Theory lives in core/, not separate wiki
- Each theory is itself a packet (fractal property)
- Theory uses compact notation with prose explanations