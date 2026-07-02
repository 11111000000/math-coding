# Decision: 0008 — Epistemic Protocol

## Status

Accepted.

## Context

Epistemic markers (fact, hypothesis, judgment, unknown) in
v1 were cosmetic fields. Agents reading them had no protocol
for what to do, so the markers degraded into ignored metadata.

## Decision

Epistemic markers drive agent behavior via an action protocol
documented in `agents/agents.md:§Epistemics as Action Protocol`.

The protocol distinguishes:

- **Mandatory markers** (judgment, unknown): require human or
  explicit decision. Agents must not override these.
- **Auto-inferred markers** (fact, hypothesis): agents may set
  based on evidence.

Each marker triggers a specific behavior:

| Marker | Behavior |
|--------|----------|
| judgment | respect, do not challenge |
| unknown | ask user, do not proceed |
| fact | verify if possible |
| hypothesis | search for evidence |

## Consequences

- Markers are no longer cosmetic.
- Agents follow a defined protocol per marker.
- Belief updates are recorded with timestamp and source.
- The convention explicitly requires human input for
  design decisions.

## Alternatives considered

- **Free-form markers**: too easy to ignore, no protocol.
- **No markers**: no epistemic rigor, loses reason for
  `assumptions.yaml` to exist.