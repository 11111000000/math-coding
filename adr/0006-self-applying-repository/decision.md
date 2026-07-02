# Decision: 0006 — Self-Applying Repository

## Status

Accepted.

## Context

Without this rule, files outside the convention accumulate
without governance. The exception list grows without bound.

## Decision

Every file in the repository is a packet, part of a packet,
or serves a packet. The exception list is finite and documented:
`INDEX.md` (a view over packets) and `schemas/` (machine-readable
specifications referenced by the convention).

## Consequences

- The repository is fully described by the convention. Removing
  the convention would make the repository meaningless.
- Adding a new file requires opening a packet or documenting
  it as an exception via a new ADR.
- The structural verifier can (and should) check directory
  contents to enforce this rule.

## Alternatives considered

- **Allow arbitrary files**: leads to drift, violates ADR-0001.