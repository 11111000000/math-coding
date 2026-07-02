# Decision: 0001 — Fractal Property

## Status

Accepted.

## Context

A methodology that does not apply to itself cannot be trusted.
Without the fractal property, the convention is documentation
that lives separately from the code it describes. Modifications
to core.md would be silently applied; the verifier would have
no way to know its own rules changed.

## Decision

The math-coding methodology applies to itself. Every file in
the repository is a packet, part of a packet, or serves a packet.
The convention document `core/core.md` lives inside the
`core/` packet. The verifier `examples/self-application/verify-consistency.sh`
lives inside the `examples/self-application/` packet.

## Consequences

- Adding a new rule requires opening a packet (with `problem.md`,
  `assumptions.yaml`, `verify.sh`) rather than editing
  `core.md` directly.
- The convention is verified by the self-application packet.
- Self-application is **complete**: refinement.md and
  traceability.json are present in self-application, not just
  the verifier.
- The convention must remain small enough that self-application
  is feasible. If the convention grows, this decision should
  be revisited.

## Alternatives considered

- **Linear convention-as-documentation**: rejected. The
  convention would not apply to its own development.
- **Convention as code**: rejected. Implementation is too
  domain-specific.