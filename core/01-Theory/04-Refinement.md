# Theory 04 — Refinement

## Formal definition

A **refinement** between two FSMs $\mathcal{M}_{\text{spec}}$ and
$\mathcal{M}_{\text{impl}}$ is a function:

$$R : S_{\text{impl}} \to S_{\text{spec}}$$

such that for every transition $s_{\text{impl}} \xrightarrow{a_{\text{impl}}} s'_{\text{impl}}$:

$$\exists \sigma : R(s_{\text{impl}}) \xrightarrow{\sigma} R(s'_{\text{impl}})$$

where $\sigma$ is a (possibly empty) sequence of spec transitions.
This says: every implementation step corresponds to a sequence
of spec steps. The implementation may perform multiple
spec-level transitions as one atomic action (a **stuttering
step**).

A refinement **preserves safety** iff for every reachable
implementation state $s_{\text{impl}}$:

$$I_{\text{spec}}(R(s_{\text{impl}})) = \text{true}$$

That is, the refinement map carries implementation states to
spec states that satisfy the spec's invariant.

A refinement **preserves liveness** iff for every infinite
implementation trace $\tau_{\text{impl}}$, there exists an
infinite spec trace $\tau_{\text{spec}}$ such that:

$$R(\tau_{\text{impl}}) = \tau_{\text{spec}} \quad \text{(after stuttering reduction)}$$

This is **stuttering equivalence**: the two traces differ only
in stuttering steps. Both reach the same set of "stable"
states, ignoring stuttering.

## Connection to math-coding

In each math-coding packet, `refinement.md` describes how the
packet's model is realized in code:

| Section | Maps to |
|---------|---------|
| State mapping | $R : S_{\text{impl}} \to S_{\text{spec}}$ |
| Operation mapping | Each spec action → one or more impl actions |
| Invariant preservation | Proof that $I_{\text{spec}} \circ R \Rightarrow I_{\text{impl}}$ |
| Test obligation mapping | Test cases for each invariant |
| Runtime-check mapping | Code that asserts invariants at runtime |

The verifier `examples/self-application/verify-consistency.sh`
is itself a refinement: it takes a `packet.yaml` (an
"implementation" state) and checks structural invariants
(spec-level predicates). The shell code is a function:

$$V : \text{PacketImpl} \to \{\text{VERIFIED}, \text{NEEDS\_REVISION}\}$$

The verifier is **sound**: if it returns VERIFIED, the
packet's structural invariants hold (in the limit of what the
shell can check). It is **incomplete**: some invariants
require deeper analysis (TLAPS proofs, property-based tests).

## Example

For the packet lifecycle FSM $\mathcal{M}_{\text{packet}}$, the
refinement map to verifier-level state is:

$$R(\text{packet}) = \begin{cases}
\text{"sketch"} & \text{if lifecycle} = \text{"sketch"} \\
\text{"working"} & \text{if lifecycle} = \text{"working"} \\
\text{"verified"} & \text{if lifecycle} = \text{"verified"} \land \text{verdict} = \text{"VERIFIED"} \\
\text{"needs-revision"} & \text{otherwise}
\end{cases}$$

The verifier checks: for every packet, does $R$ return
"verified" iff the structural invariants hold? If yes, the
packet is correctly refined.

A counterexample is a packet with `lifecycle: verified` but
no verdict record. Here, $R$ returns "needs-revision" but the
packet claims to be verified. The verifier reports this as a
violation, demonstrating that $R$ is correctly applied.

## References

- Abadi & Lamport, "The Existence of Refinement Mappings" (1988)
- Lamport, "Specifying Systems" (2002), §5 (Refinement)
- Back & von Wright, "Refinement Calculus" (1998)
- Morgan, "Programming from Specifications" (1990)