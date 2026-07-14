# Deprecation and Supersession (A5)

Supersession is a binary relation ⊥ between packets. It is
a strict partial order:

  Irreflexive   ¬(P ⊥ P)
  Asymmetric    P₁ ⊥ P₂ ⇒ ¬(P₂ ⊥ P₁)
  Transitive    P₁ ⊥ P₂ ∧ P₂ ⊥ P₃ ⇒ P₁ ⊥ P₃

In math-coding, supersession is declared in `packet.yaml`
under a `supersession:` block, present only when
`lifecycle: superseded`. The block names the successor.

The supersession DAG of math-coding is finite, acyclic, and
extending it does not require rebuilding the convention —
only the successor's `applications[]` block.

See math/05-accounting/.