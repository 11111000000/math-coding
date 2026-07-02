# Theory 10 — Modal Logic for Lifecycle

## Formal definition

**Modal logic** extends classical logic with two operators,
$\square$ (necessity) and $\Diamond$ (possibility):

$$\varphi ::= p \mid \neg\varphi \mid \varphi \wedge \varphi \mid \square\varphi \mid \Diamond\varphi$$

where:

- $\square\varphi$ reads "$\varphi$ is necessarily true" — it
  holds in every reachable state and every continuation.
- $\Diamond\varphi$ reads "$\varphi$ is possibly true" — there
  exists at least one reachable state where it holds.

The two operators are dual:

$$\square\varphi \equiv \neg\Diamond\neg\varphi$$

For a packet lifecycle FSM, the state space $S$ is the set of
five lifecycle values. The semantics is given by a **Kripke
structure** $\mathcal{K} = \langle W, R, V \rangle$ where:

- $W$ is the set of "worlds" — in our case, the states of
  `packet.yaml` over time
- $R \subseteq W \times W$ is the accessibility relation — the
  transition relation $\to$ of the FSM
- $V : W \to \mathcal{P}(\text{Prop})$ is the valuation — which
  propositions (lifecycle, presence of verdict, etc.) hold at
  each world

The **temporal operators** of theory-03 are reinterpreted
modally:

- $[]P \equiv \square P$ over the temporal successor relation
- $<>P \equiv \Diamond P$ over the temporal successor relation

The **distinct modal operators** add reachability over
**non-temporal** relations. In math-coding, the relevant
non-temporal relation is the **dependency relation** between
packets: a packet $P$ is reachable from $Q$ in the dependency
graph iff $Q \in \text{depends\_on}(P)$.

## Connection to math-coding

Modal logic lets us express properties of the lifecycle that
classical LTL cannot:

| Property | LTL (theory-03) | Modal (this theory) |
|----------|-----------------|---------------------|
| Packet is verified *now* | $P$ | $P$ |
| Packet is verified *at some reachable lifecycle* | $<>P$ | $\Diamond P$ |
| Packet *must* be verified for all reachable lifecycle | $[]P$ | $\square P$ |
| Packet is verified *in some successor world* | $P \sim> Q$ | $\Diamond Q$ after $P$ |
| Packet *necessarily* cannot be archived before verified | $\square(\text{verified} \vee \text{before})$ | $\square \neg(\text{archived} \wedge \text{before verified})$ |

The **cascading deprecation** rule (ADR-0010, theory-08) is
modal: if $P \perp P'$ and $Q$ depends on $P$, then $Q$ is
**necessarily** affected:

$$\square(P \perp P' \Rightarrow \Diamond(Q \text{ must re-verify}))$$

This is a statement about the **dependency relation**, not the
temporal succession. Pure LTL cannot express it without
reifying the dependency graph into the temporal trace.

### Forbidden transitions, modally

A forbidden transition `sketch → verified` is:

$$\square(\text{lifecycle} = \text{"sketch"} \Rightarrow \neg\Diamond(\text{lifecycle} = \text{"verified"}))$$

That is, in any world where lifecycle is `sketch`, the
property `lifecycle = verified` is **not possible** in any
successor world. The transition relation $\to$ does not
contain this edge.

### Triggers, modally

The triggered transitions of ADR-0010 are **reactive
modalities**:

- **Dependency cascade**: when packet $P$ is superseded
  ($\square P \perp P'$), every packet $Q$ with
  $P \in \text{depends\_on}(Q)$ has a new obligation:
  $\Diamond(Q \text{ re-verified})$.
- **Convention version**: when `convention_version` changes,
  every `verified` packet has a new obligation:
  $\square(Q.\text{lifecycle} \neq \text{"verified"} \vee
  \Diamond(Q \text{ re-verified}))$.

These are **modal obligations**, not temporal guarantees. The
difference matters: a packet can satisfy the modal obligation
immediately (re-verify now) or eventually (re-verify later),
as long as the eventual path exists.

## Example

Consider packet $P$ (`modal-dialog`) and $Q$ (`docs-integration`)
with $Q \in \text{depends\_on}(P)$.

Today: $P$ is `verified`, $Q$ is `working`. The Kripke
structure has worlds $w_1 = (P=\text{verified}, Q=\text{working})$
and accessibility through FSM transitions.

If $P$ is deprecated tomorrow ($\square P \perp P'$), the modal
obligation on $Q$ becomes:

$$\square(P.\text{lifecycle} = \text{"deprecated"} \Rightarrow \Diamond(Q.\text{lifecycle} \in \{\text{"verified"}, \text{"deprecated"}\}))$$

In words: as long as $P$ is deprecated, $Q$ must **possibly**
reach a terminal lifecycle. This can happen via two paths:
$Q$ re-verifies (working → verified) or $Q$ is itself
deprecated (working → deprecated). The modal operator
$\Diamond$ does not say *when* — it says *that a path exists*.

If the user refuses to do either, $Q$ violates the modal
obligation, but the structural verifier cannot detect this
(no state change). This is why ADR-0010 calls cascading
deprecation a **human responsibility** documented in
`task.md`.

## Why this matters

Modal logic is the natural language for **two questions** that
LTL cannot answer cleanly:

1. **What must be true across all reachable packet states?**
   — $\square$
2. **What is possible given the dependency graph?**
   — $\Diamond$ over the dependency relation

The convention uses both. The first governs structural
invariants; the second governs cascading obligations. Without
the modal layer, cascading deprecation is a convention-level
rule that the verifier cannot express and humans may forget.

## References

- Hughes & Cresswell, "A New Introduction to Modal Logic"
  (1996)
- Blackburn, de Rijke & Venema, "Modal Logic" (2001)
- Harel, Kozen & Tiuryn, "Dynamic Logic" (2000)
- Fitting & Mendelsohn, "First-Order Modal Logic" (1998)
- van Benthem, "Modal Logic for Open Minds" (2010)