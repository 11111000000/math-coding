# Decision: 0006 — Self-Applying Repository

## Status

Accepted.

## Context

Without this rule, files outside the convention accumulate
without governance. The exception list grows without bound.

The "every artifact is a packet" rule applies to the
**math-coding repository itself** (self-application mode).
When math-coding is applied to an external production
project, packets live in a dedicated directory (typically
`specs/` or `math/`, configured via `.mathcodingrc`); the
project's code keeps its native structure. The link between
packets and project code is explicit through `refinement.md`
and `traceability.json`. See `core/core.md §Two modes of
application`.

## Decision

Every file in the **math-coding repository** is a packet,
part of a packet, or serves a packet. The exception list is
finite and documented: `INDEX.md` (a view over packets),
`schemas/` (machine-readable specifications referenced by
the convention), `.mathcodingrc` (project configuration for
external-project mode), `agents/rigor-tools.md` and similar
reference documents, and integration files (CI workflows,
IDE config). External projects that adopt math-coding are
governed by the same rule: their packets directory follows
the packet structure, while the rest of the project keeps
its own conventions.

## Consequences

- The repository is fully described by the convention. Removing
  the convention would make the repository meaningless.
- Adding a new file requires opening a packet or documenting
  it as an exception via a new ADR.
- The structural verifier can (and should) check directory
  contents to enforce this rule.
- External projects adopting math-coding get a clear
  separation: code lives in native structure, packets live
  in `specs/` or `math/`, the bridge is `refinement.md` +
  `traceability.json`.

## Alternatives considered

- **Allow arbitrary files**: leads to drift, violates ADR-0001.
- **Force every file in external projects to be a packet**:
  impractical, breaks language conventions, kills adoption.