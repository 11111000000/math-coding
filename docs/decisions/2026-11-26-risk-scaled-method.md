# ADR: risk-scaled Math Coding

## Status

Proposed for owner review.

## Context

The first controlled pilot found that full protocol cost was not justified for
every change. File coverage alone said nothing about semantic risk, and an
uncontrolled list of permanent claims made the map hard to use.

## Decision

Use four levels. Level 0 is ordinary CI. Level 1 records an `Observed` check
without a negative control. Level 2 uses a negative control and may reach
`Holds`. Level 3 adds a portable bundle and explicit environment. Claims declare
`risk`, semantic `risks`, and `archived`; a claim budget makes long-lived
accumulation visible.

## Consequences

Low- and medium-risk work gets a cheaper honest loop. High-risk work keeps the
strict gate. Active claims must stay small or be archived after acceptance. A
human owner must separately review whether the scaled method actually helps;
that remains `method-usefulness`, not a machine verdict.
