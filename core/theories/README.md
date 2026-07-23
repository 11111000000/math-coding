# Theories (eight)

Eight mathematical theories ground math-coding v0.992.
Each theory is a compact runtime spec for an LLM agent.
Each axiom packet applies one or more theories to the
convention itself.

```dataview
TABLE
  file.link AS "theory",
  axiom AS "axiom"
FROM "theories"
WHERE file.name != "README"
SORT file.name ASC
```

| Theory | Axiom | Statement |
|--------|-------|-----------|
| [curry-howard](curry-howard.md) | A2 | `Types ⇔ Propositions`, `Programs ⇔ Proofs`, `Type-check ⇔ Proof verification` |
| [predicate](predicate.md) | A4 | `I : S → B`, every check is a predicate |
| [fsm](fsm.md) | A4 | `M = ⟨ S, s₀, A, →, I ⟩`, six-state lifecycle |
| [refinement](refinement.md) | A4 | `R ⊆ S_impl × S_spec`, packet ↔ implementation |
| [verdict](verdict.md) | A5 | `Spec ⊨ P`, five outcomes |
| [epistemic](epistemic.md) | A5 | `B : Prop × Agent → [0, 1]`, five markers |
| [deprecation](deprecation.md) | A5 | `⊥` strict partial order, supersession DAG |
| [agent](agent.md) | A6 | `S = (chat, files, mode, role)` |

## Why eight

axiom Difference is ontological and stands above the
eight. axiom Self-Application is meta and stands below.
The eight theories between them are the mathematical
machinery the convention uses to verify itself.

Four **foundational**: curry-howard, predicate, fsm,
refinement. These define the structural backbone.

Four **applied**: verdict, epistemic, deprecation, agent.
These instantiate the foundational theories in concrete
machinery — the verifier, the markers, the DAG, the
runtime.