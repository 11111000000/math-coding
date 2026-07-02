# Refinement: theory-11-confidence-information

## State mapping

- Confidence value $c \in [0, 1]$ → numeric field in
  `assumptions.yaml`
- Shannon information $I(P) = H(c)$ → derived quantity, not
  stored, but used by agents to calibrate effort
- Epistemic markers → partition of $[0, 1]$ into
  $\{0, 1\}$ (boundary, `fact`/`judgment`), $(0, 1)$
  (interior, `hypothesis`), $\{0\}$ (no information, `unknown`)
- Belief update rule $B'(P, a) = B(P, a) \cdot (1 + \alpha e)$
  → operation defined in theory-07, closure property stated
  here

## Operation mapping

- **Set confidence** → write $c \in [0, 1]$ in YAML entry
- **Compute $I(P)$** → apply $H(c)$ formula (no storage)
- **Update confidence** → apply update rule with
  $\alpha = 0.2$, $e \in [0, 1]$
- **Calibrate effort** → spend $O(I(P))$ work, not $O(|1 - c|)$

## Invariant preservation

- Confidence is always in $[0, 1]$ after belief updates
  (closure property).
- The information content $I(P)$ is symmetric: $H(c) = H(1 - c)$.
  Direction of belief is encoded by the marker, not by
  confidence.
- A `fact` entry has $c \in \{0, 1\}$ and $I(P) = 0$. The
  agent has full information.
- A `hypothesis` entry has $c \in (0, 1)$ and $I(P) > 0$.
  The agent has partial information.

## Test obligation mapping

- For each `hypothesis` entry, an agent's response should be
  proportional to $I(P)$. A hypothesis with $c = 0.95$ may
  justify a single verification check; a hypothesis with
  $c = 0.5$ may justify a thorough search.
- The convention does not enforce this proportionality
  mechanically — it is a recommendation in `agents/agents.md`
  for agents that read the theory.

## Runtime-check mapping

- The structural verifier checks that `confidence` is in
  $[0, 1]$ if present (schema-level validation).
- The verifier does not compute $I(P)$ — this is a reasoning
  aid for agents, not a structural check.
- Future versions may add an "uncertainty budget" report:
  sum of $I(P)$ across all `hypothesis` entries, used as a
  rough estimate of total missing information in the packet.

## Connection to verifier

This packet's content maps to `core/core.md:§Epistemics` and
to `schemas/assumptions.schema.json` (the schema-level
validation of the `confidence` field). The information-theoretic
view is **complementary** to the belief-update view of
theory-07: theory-07 says *how* confidence changes, this
theory says *what confidence means* in absolute terms.