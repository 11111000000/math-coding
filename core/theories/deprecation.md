# Theory: Deprecation (Supersession)

**Rigor:** any

A deprecation is a relation P_old ⊥ P_new where P_new
supersedes P_old. Three properties:
- Irreflexive: ¬(P ⊥ P)
- Asymmetric: P₁ ⊥ P₂ ⇒ ¬(P₂ ⊥ P₁)
- Transitive: P₁ ⊥ P₂ ∧ P₂ ⊥ P₃ ⇒ P₁ ⊥ P₃

These make ⊥ a strict partial order. Packets form a DAG.

**Used in:** packet.yaml:supersession (when lifecycle is
superseded). The next packet in the chain is the superseder.

**Example:** packet-minimum ⊥ packet-minimum-v2 (replaced).
When packet-minimum-v2 ships, packet-minimum's lifecycle
becomes superseded and it gets a supersession block pointing
to packet-minimum-v2.
