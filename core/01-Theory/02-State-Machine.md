# Theory 02 — State Machine

## Formal definition

A **finite state machine** (FSM) is a tuple:

$$\mathcal{M} = \langle S, s_0, A, \to, I \rangle$$

where:

- $S$ is a finite, non-empty set of **states**
- $s_0 \in S$ is the **initial state**
- $A$ is a finite set of **actions** (or events)
- $\to \subseteq S \times A \times S$ is the **transition relation**,
  written $s \xrightarrow{a} s'$
- $I : S \to \mathbb{B}$ is the **invariant predicate**

A state $s$ is **reachable** from $s_0$ if there exists a
sequence of actions $a_1, a_2, \ldots, a_n$ and intermediate
states $s_1, s_2, \ldots, s_{n-1}$ such that:

$$s_0 \xrightarrow{a_1} s_1 \xrightarrow{a_2} s_2 \cdots \xrightarrow{a_n} s_n = s$$

The set of reachable states is the smallest fixed-point of the
operator:

$$F(X) = \{s_0\} \cup \{s' : \exists s \in X, a \in A : s \xrightarrow{a} s'\}$$

starting from $X = \emptyset$. This is well-defined because $S$
is finite and $F$ is monotone.

## Connection to math-coding

The packet lifecycle FSM is:

$$\mathcal{M}_{\text{packet}} = \langle S, s_0, A, \to, I \rangle$$

where:

- $S = \{\text{sketch}, \text{working}, \text{verified}, \text{deprecated}, \text{archived}\}$
- $s_0 = \text{sketch}$ (every packet starts as a hypothesis)
- $A = \{\text{formalize}, \text{verify}, \text{deprecate}, \text{archive}, \text{reopen}\}$
- $\to$ is the transition relation defined in `core/core.md:§State machine`
- $I$ is the structural invariant that every packet's
  `packet.yaml` must satisfy

**Forbidding transitions** is a constraint on $\to$: certain
state pairs $(s, s')$ cannot have any action $a$ such that
$s \xrightarrow{a} s'$. For example, $\text{sketch} \xrightarrow{a} \text{verified}$
is forbidden because no action can move a packet directly from
hypothesis to verified.

**Liveness** (see theory-03) extends this with temporal
constraints: certain states must eventually be reached.

## Example

A three-state FSM for "commit lifecycle" in a hypothetical
project:

$$\mathcal{M}_{\text{commit}} = \langle \{\text{draft}, \text{review}, \text{merged}\}, \text{draft}, \{\text{submit}, \text{approve}, \text{reject}\}, \to, I \rangle$$

with transitions:

| from | action | to |
|------|--------|----|
| draft | submit | review |
| review | approve | merged |
| review | reject | draft |

Invariant: $I(s) = (s \neq \text{merged}) \lor (\text{verdict present})$.

Safety claim: $\forall s \in \text{Reachable}(\text{draft}) : I(s)$.
This can be checked by enumerating reachable states:

$\text{Reachable}(\text{draft}) = \{\text{draft}, \text{review}, \text{merged}\}$

$I(\text{draft}) = \text{true}$ (no merged yet).
$I(\text{review}) = \text{true}$ (no merged yet).
$I(\text{merged}) = \text{requires verdict present}$, which is
the verifier's job.

If a `merged` commit has no `verdict`, the verifier reports a
violation. The FSM safety check passes iff the verdict is
present.

## References

- Hopcroft & Ullman, "Introduction to Automata Theory" (1979)
- Lamport, "Specifying Systems" (2002), §2.2 (State Machines)
- Milner, "A Calculus of Communicating Systems" (1980)
- Tretmans, "Model Based Testing with Labelled Transition Systems" (2008)