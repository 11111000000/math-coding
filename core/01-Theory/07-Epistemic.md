# Theory 07 — Epistemic State

## Formal definition

A **belief state** of an agent $a$ over propositions $P$ is
a graded function:

$$B : \text{Prop} \times \text{Agent} \to [0, 1]$$

- $B(P, a) = 1$: $a$ fully believes $P$ (certainty)
- $B(P, a) = 0$: $a$ has no belief about $P$ (uncertainty)
- $B(P, a) \in (0, 1)$: $a$ partially believes $P$ (graded)

Belief updates on evidence:

$$B'(P, a) = \begin{cases}
B(P, a) \cdot (1 + \alpha \cdot e) & \text{if evidence supports } P \\
B(P, a) \cdot (1 - \alpha \cdot e) & \text{if evidence contradicts } P \\
B(P, a) & \text{otherwise (no change)}
\end{cases}$$

where $e \in [0, 1]$ is evidence weight, $\alpha \in [0, 1]$ is
learning rate. The convention uses $\alpha = 0.2$ by default.

The four epistemic markers map to belief intervals:

| Epistemology | Belief interval | Update protocol |
|--------------|------------------|------------------|
| `fact` | $B(P, a) = 1.0$ | trust without proof; update only on counter-evidence |
| `hypothesis` | $B(P, a) \in (0, 1)$ | search for evidence; update on find |
| `judgment` | $B(P, a) \in \{0, 1\}$ discrete | respect; do not update from agent |
| `unknown` | $B(P, a) = 0$ | ask user; do not proceed |

## Connection to math-coding

Each `assumptions.yaml` entry carries:

- `id`: identifier
- `statement`: proposition $P$
- `epistemology`: one of `fact`, `hypothesis`, `judgment`, `unknown`
- `confidence`: numeric $B(P, a)$ (optional but encouraged)
- `status`: one of `user-confirmed`, `agent-inferred`, `open`

The **action protocol** for an agent reading an assumption:

```
When you read an assumption:

1. If epistemology == "judgment":
   DO NOT challenge. Treat as design decision.
   DO NOT propose alternatives without explicit user request.

2. If epistemology == "unknown":
   DO NOT proceed without asking user.
   Mark status as "open" if not already.

3. If epistemology == "fact":
   Verify if possible (read source, run check).
   If cannot verify: downgrade to "hypothesis" with low confidence.

4. If epistemology == "hypothesis":
   Search for evidence (tool, doc, prior packet).
   If found: upgrade to "fact" with high confidence.
   If not found: keep as "hypothesis" with current confidence.
   If contradicted: downgrade to "unknown" and ask user.

5. Always record: source of evidence, confidence level, timestamp.
```

This protocol is **not optional**. Without it, epistemic
markers are merely cosmetic.

## Example

A `assumptions.yaml` entry:

```yaml
- id: A3
  statement: TypeScript compile will succeed without errors.
  status: agent-inferred
  epistemology: hypothesis
  confidence: 0.7
```

Agent reads: "hypothesis with confidence 0.7". Following the
protocol:

1. Search for evidence: run `tsc --noEmit`.
2. If no errors: upgrade to `fact` with `confidence: 0.95`,
   update the entry.
3. If errors: keep as `hypothesis` with current confidence,
   add evidence (count of errors).
4. If unexpected errors: downgrade to `unknown` with low
   confidence, ask user.

The agent **records** the action in the entry's `evidence`
field (if present) or in a comment in the file. Without
recording, the change is invisible.

## Two-layer scheme

The convention distinguishes between:

**Layer 1 — Mandatory marks (human or explicit decision):**

- `judgment`: design decision, requires human input
- `unknown`: open question, requires human input

These cannot be auto-inferred. If an agent encounters a packet
where these are missing, the agent must ask the user.

**Layer 2 — Auto-inferred marks (agent may set):**

- `fact`: agent sets when confident (e.g., reads source and
  confirms)
- `hypothesis`: agent sets when uncertain (default)

This two-layer scheme prevents the epistemic-marker field from
becoming garbage: humans decide what matters, agents fill in
the rest.

## References

- Fagin & Halpern, "Belief, Awareness, and Limited Reasoning" (1988)
- Meyer, "Epistemic Logic for AI" (2015)
- Hintikka, "Knowledge and Belief" (1962)