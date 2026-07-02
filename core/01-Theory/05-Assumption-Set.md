# Theory 05 — Assumption Set as Axioms

## Formal definition

Let $\Sigma = \{a_1, a_2, \ldots, a_n\}$ be a finite set of
**assumptions** in some first-order language over program
state. Each assumption $a_i$ is a closed formula:

$$a_i : \text{State} \to \mathbb{B}$$

(read: $a_i$ is true in a state iff it evaluates to $\text{true}$).

A **specification** is a pair $(\text{Pre}, \text{Post})$ where:

- $\text{Pre}$ is a precondition: a predicate over the input state
- $\text{Post}$ is a postcondition: a predicate over the output state

A program $P$ **satisfies** its specification under $\Sigma$ iff
for every initial state $s$ satisfying $\text{Pre}$, the output
state $P(s)$ satisfies $\text{Post}$, **under the assumptions
$\Sigma$**:

$$\forall s : \text{Pre}(s) \Rightarrow \left(\bigwedge_{a \in \Sigma} a(s)\right) \Rightarrow \text{Post}(P(s))$$

This is written:

$$\Sigma \vdash_P \text{Pre} \Rightarrow \text{Post}$$

or simply $\Sigma \vdash \text{Spec}$ when $P$ is clear from
context.

The epistemic markers in `assumptions.yaml` correspond to
different proof obligations:

| Epistemology | Proof role | Required action |
|--------------|------------|------------------|
| `fact` | $a \in \Sigma$ is an **axiom**, trust without proof | None, $a$ is treated as true |
| `hypothesis` | $a$ is a **conjecture**, $\Sigma \vdash \text{Spec}$ assumes $a$ | Verify $a$ before relying on it |
| `judgment` | $a$ is a **design decision**, no proof obligation | Respect, do not challenge |
| `unknown` | $a$ is **undecided**, $\Sigma \vdash \text{Spec}$ is unprovable | Ask user before proceeding |

## Connection to math-coding

In math-coding, $\Sigma$ is the entries of `assumptions.yaml`.
When the verifier reports `VERIFIED`, it has checked that the
packet's structure (under the assumptions in $\Sigma$) meets the
convention's invariants. The proof is implicit — the verifier
implements the structural argument.

A packet is **safe to ship** iff:

$$\text{lifecycle} = \text{"verified"} \land \forall a \in \Sigma : \text{epistemology}(a) \neq \text{"unknown"} \land \text{status}(a) \neq \text{"open"}$$

Unknown or open assumptions mean $\Sigma$ is incomplete; the
shipped code rests on assumptions that were never verified
or accepted.

## Example

A typical `assumptions.yaml`:

```yaml
assumptions:
  - id: A1
    statement: The state machine has 5 states.
    status: agent-inferred
    epistemology: fact
  - id: A2
    statement: State transitions are deterministic.
    status: agent-inferred
    epistemology: hypothesis
  - id: A3
    statement: We choose to forbid sketch->verified transition.
    status: user-confirmed
    epistemology: judgment
  - id: A4
    statement: Whether archived packets are immutable.
    status: open
    epistemology: unknown
```

Here $\Sigma = \{a_1, a_2, a_3\}$ (excluding $a_4$ which is
unknown/open). The verifier proves
$\Sigma \vdash \text{Structural Invariants}$ mechanically.

If $a_4$ is closed (e.g., agent asks user, user says "yes,
archived packets are immutable"), the new $\Sigma' = \Sigma \cup
\{a_4\}$ extends the proof but adds no new structural invariant.

If $a_4$ is left open, the proof is incomplete and the packet
should not be promoted to `verified` until it is resolved.

## References

- Hoare, "An Axiomatic Basis for Computer Programming" (1969)
- Dijkstra, "A Discipline of Programming" (1976)
- Winskel, "The Formal Semantics of Programming Languages" (1993)
- Curry & Howard, "Correspondence" (1958–1980)