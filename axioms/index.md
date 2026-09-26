# Axiom index

> Author: Petr Kosov <p.b.kosov@yandex.ru>
> Status: normative foundations of math-coding 3.0-alpha
> License: Apache-2.0 (these texts are normative documentation, not code)

The axioms below are the philosophical and mathematical foundations
the kernel, schemas, conformance corpus and agent protocol are derived
from. Every non-trivial change in the repository must reference at
least one axiom.

The axioms do not constrain implementation; they constrain what the
implementation must achieve. A correct implementation may add
features; it cannot violate an axiom. A wrong implementation may
appear to work; it is wrong.

## The axioms

| ID | Title | File |
|---|---|---|
| A0 | Separation | [separation.md](separation.md) |
| A1 | Feedback | [feedback.md](feedback.md) |
| A2 | Invariants and Recovery | [invariants.md](invariants.md) |
| A3 | Self-application | [self-application.md](self-application.md) |
| A4 | Care | [care.md](care.md) |

## How axioms relate to the kernel

| Axiom | Kernel property |
|---|---|
| A0 — Separation | Variants over records for sealed kinds. Closed `additionalProperties` in schemas. Per-kind digest prefixes. |
| A1 — Feedback | `result` enum includes `Inconclusive` and `InfrastructureError`. Waivers require `expires_at`. Operational outcomes allow `absence_means: inconclusive`. |
| A2 — Invariants and Recovery | `gate` variant includes `Blocked` with `remedies`. Diagnostics carry `next_actions`. Exit codes 0/1/2/3. |
| A3 — Self-application | `bootstrap/decision.yaml` references this index. Constituent changes require migration + conformance. Old policy authorizes new policy. |
| A4 — Care | `decision.risk.owner`, `obligation.decision`, `assumption.owner`, `waiver.issuer` are required, not optional. |

## How axioms relate to the agent

The agent protocol (`AGENTS.md`) requires reading these axioms before
any non-trivial change. Each axiom ends with a section titled
*What an agent must do when the axiom seems to fail*; the agent must
follow that section.

The agent MUST record its reasoning as a `Decision` whose `relations`
field names the axioms that justify or constrain the change. A change
without axioms is a deficit.

## Versioning

These axioms are versioned with the kernel. Any change to an axiom is
itself a protected-policy transition (A3):

- the change must be recorded as a `Decision` with `supersedes`
  pointing at the prior axiom version;
- the change must include positive and negative conformance fixtures
  that demonstrate the new axiom still applies;
- the change must include a migration path that preserves the spirit of
  the old axiom.

The first version of these axioms is dated 2026-09-26 and corresponds
to the math-coding 3.0-alpha-0.0.1 bootstrap. The `revision` of each
axiom is its `id`; subsequent versions increment a trailing suffix
(`A0.1`, `A1.1`, etc.).
