# Theory: Finite State Machine

**Rigor:** any

A FSM is a tuple M = ⟨S, s₀, A, →, I⟩ where:
- S is a finite set of states
- s₀ ∈ S is the initial state
- A is a set of actions
- → ⊆ S × A × S is the transition relation
- I: S → B is the invariant

**Used in:** packet.yaml:lifecycle (6 states, transitions
between them). See refinement.md of any packet for the
specific transitions.

**Example:** packet lifecycle has states {sketch, working,
verified, deprecated, archived} with transitions:
- sketch → working (when code exists)
- working → verified (when verifier returns VERIFIED)
- verified → deprecated (when superseded by another packet)
