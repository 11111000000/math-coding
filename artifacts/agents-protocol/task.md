# Agents Protocol v2

## Problem

v1 of `agents.md` describes epistemic markers as **fields**
to be filled. Agents that read them have no protocol for how
to **react**. As a result, epistemic markers become cosmetic
fields without meaning.

## Desired outcome

`agents/agents.md` defines an **action protocol**: for each
epistemic marker, the agent knows exactly what to do. The
protocol is grounded in [theory-07-epistemic](../core/01-Theory/07-Epistemic.md).

The protocol distinguishes:

- **Mandatory markers** (judgment, unknown): human or explicit
  decision required.
- **Auto-inferred markers** (fact, hypothesis): agent may set.

## Constraints

- The protocol must be implementable: an agent following it
  produces verifiable behavior.
- The protocol is a **table**, not a paragraph — easy to
  reference.

# Adaptations

(none)