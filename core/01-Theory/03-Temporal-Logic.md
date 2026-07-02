# Theory 03 — Temporal Logic

## Formal definition

**Linear-time temporal logic** (LTL) is a modal logic over
infinite sequences of states $\sigma = s_0, s_1, s_2, \ldots$.
A property is a formula $P$ that evaluates over $\sigma$.

The core LTL operators:

| Operator | Reading | Meaning |
|----------|---------|---------|
| `[]P` | "always P" | $P$ holds in every state of $\sigma$ |
| `<>P` | "eventually P" | $P$ holds in some state of $\sigma$ |
| `P ~> Q` | "P leads to Q" | whenever $P$ holds, $Q$ holds eventually after |
| `WF_a(A)` | "weak fairness on a" | if $A$ is always enabled, it eventually fires |
| `SF_a(A)` | "strong fairness on a" | if $A$ is infinitely often enabled, it eventually fires |

Formal semantics:

- $\sigma \models []P$ iff $\forall i \geq 0 : \sigma[i] \models P$
- $\sigma \models <>P$ iff $\exists i \geq 0 : \sigma[i] \models P$
- $\sigma \models P \sim> Q$ iff $\forall i : (\sigma[i] \models P) \Rightarrow (\exists j \geq i : \sigma[j] \models Q)$
- $\sigma \models WF_a(A)$ iff $(\forall i : \sigma[i] \models \text{ENABLED}(A)) \Rightarrow (\exists j : \sigma[j] \models A)$
- $\sigma \models SF_a(A)$ iff $(\forall^\infty i : \sigma[i] \models \text{ENABLED}(A)) \Rightarrow (\exists j : \sigma[j] \models A)$

The difference between WF and SF is critical: WF requires the
action to be **always** enabled, SF allows it to be **eventually**
enabled repeatedly.

## Connection to math-coding

Each property in `core/core.md` can be expressed in LTL:

**Safety property: structural invariants hold always.**

$$[](\text{packet.yaml has required fields})$$

This is a state-level invariant; the verifier checks it at
each reachable state.

**Liveness property: every verified packet can be deprecated.**

$$(\text{lifecycle} = \text{"verified"}) \sim> (\text{lifecycle} = \text{"deprecated"} \lor \text{lifecycle} = \text{"archived"})$$

This says: once verified, a packet eventually reaches a terminal
state. The verifier does not enforce liveness directly — it
checks structural properties. But the **state machine definition**
in `core/core.md:§State machine` declares which transitions exist,
and liveness follows from the structure.

**Liveness property: a packet does not stay in `working` forever.**

$$WF_{\text{verify}}(\text{lifecycle} = \text{"working"} \Rightarrow \text{lifecycle} = \text{"verified"} \lor \text{lifecycle} = \text{"sketch"})$$

This is a fairness condition. The verifier does not check it
mechanically — but a packet with `lifecycle: working` and no
verifier output is suspicious. A linter could flag such packets
("stale in working").

## Example

A typical math-coding packet follows the lifecycle:

$$\text{sketch} \xrightarrow{\text{formalize}} \text{working} \xrightarrow{\text{verify}} \text{verified} \xrightarrow{\text{deprecate}} \text{deprecated} \xrightarrow{\text{archive}} \text{archived}$$

The desired liveness property:

$$\text{started} \sim> \text{terminal}$$

where $\text{started} = (\text{lifecycle} \neq \text{"sketch"})$
and $\text{terminal} = (\text{lifecycle} \in \{\text{"verified"}, \text{"deprecated"}, \text{"archived"}\})$.

This is true **if** every transition can fire (no deadlocks).
The base verifier does not check for deadlocks; it checks that
each state is **valid** when reached.

For stronger liveness guarantees, model checking with TLC is
required. See `core/01-Theory/06-Verdict.md` for how verdicts
encode model-checker outputs.

## References

- Pnueli, "The Temporal Logic of Programs" (1977)
- Lamport, "Specifying Systems" (2002), §3 (Temporal Logic)
- Emerson, "Temporal and Modal Logic" (1990)
- Baier & Katoen, "Principles of Model Checking" (2008), §6