# references/theories.md

The eight theories that ground the axioms (v0.992). Load this
when the agent asks about a theory or needs to know which
theory to cite.

For canonical theory statements, see `theories/*.md`. If this
file disagrees, `theories/*.md` wins.

| Theory | Axiom | Statement |
|--------|-------|-----------|
| curry-howard | A2 | Types ⇔ Propositions, Programs ⇔ Proofs, Type-check ⇔ Proof verification |
| predicate | A4 | I : S → Bool, every check is a predicate |
| fsm | A4 | M = ⟨ S, s₀, A, →, I ⟩, four-state lifecycle |
| refinement | A4 | R ⊆ S_impl × S_spec, packet ↔ implementation |
| verdict | A5 | Spec ⊨ P, five outcomes |
| epistemic | A5 | B : Prop × Agent → [0, 1], five markers |
| deprecation | A5 | ⊥ strict partial order, supersession DAG |
| agent | A6 | S = (chat_history, files_read, files_written, mode, role, installation) |

The five-file packet is the **canonical projection** of a
typed lambda-term (Curry-Howard). The lifecycle is a
**finite state machine** (FSM). Every check is a **predicate**.
The proof obligation is **Spec ⊨ P**. The convention's
witness is a **git SHA** in `applications[]`. The
supersession is a **strict partial order**. The agent is a
**stateful function** over chat, files, mode, role, and
installation.