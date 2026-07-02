# Theory 01 — Predicate and Invariant

## Formal definition

A **predicate** over a state space $S$ is a total function:

$$I : S \to \mathbb{B}$$

A state $s \in S$ *satisfies* $I$ iff $I(s) = \text{true}$. An
**invariant** is a predicate that is intended to hold for all
states that the system can reach.

Let $\text{Reachable}(s_0)$ be the set of states reachable from
an initial state $s_0$ via the system's transition relation.
**Safety** of the system with respect to $I$ is:

$$\text{Safety}(I) \triangleq \forall s \in \text{Reachable}(s_0) : I(s) = \text{true}$$

A system is *unsafe* with respect to $I$ iff there exists a
reachable $s$ with $I(s) = \text{false}$. Such an $s$ is a
**counterexample** — proof that $I$ is not actually an invariant.

## Connection to math-coding

In a math-coding packet, the state space $S$ is the set of all
possible values of `packet.yaml`. Each structural invariant
listed in `core/core.md` defines a predicate $I_i$ over this
state. The base verifier `examples/self-application/verify-consistency.sh`
checks $I_i(\text{current packet})$ explicitly for every packet
in the repository.

The verifier does not enumerate all reachable states — that
would require generating every possible `packet.yaml`. Instead,
the verifier checks $I$ **at one point**: the current packet.
This is sound when the state space is small and the predicates
are cheap. For larger state spaces, model checking (TLC) or
property-based testing (hypothesis) is used.

The epistemic status of an invariant:

| Status | Meaning |
|--------|---------|
| `fact` | Invariant is mathematically proved (TLAPS, paper proof). |
| `hypothesis` | Invariant is checked by verifier but not proved. |
| `judgment` | Invariant is a design decision, not derived from evidence. |
| `unknown` | Invariant is open; verification has not run. |

## Example

For `packet.yaml`, one invariant is:

$$I_{\text{required}}(\text{packet}) = (\text{task\_id present}) \land (\text{title present}) \land (\text{lifecycle} \in \text{Allowed})$$

The verifier checks this by reading the YAML and applying
$I_{\text{required}}$ explicitly. If $I_{\text{required}}(\text{packet}) = \text{false}$,
the packet is reported as a violation. A counterexample is
any packet that satisfies the false branch — for example,
a packet missing `task_id`.

A second invariant captures the FSM constraint that
`lifecycle = "verified"` requires a verdict:

$$I_{\text{verdict}}(\text{packet}) = \text{lifecycle} \neq \text{"verified"} \lor \exists v : v.\text{verdict} = \text{VERIFIED}$$

The verifier evaluates $I_{\text{verdict}}$ for every packet.
This is a **derived invariant** — it is implied by the lifecycle
FSM definition in `core/core.md`, not a primitive one. Both
kinds are checked.

## References

- Lamport, "Specifying Systems" (2002), §2.3 (Invariants)
- Hoare, "An Axiomatic Basis for Computer Programming" (1969)
- Alpern & Schneider, "Defining Liveness" (1985)
- Jackson, "Software Abstractions" (2006), §3 (Predicates)