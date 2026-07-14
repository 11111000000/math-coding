# Theories (eight)

Eight mathematical theories ground math-coding v0.854.

Each theory is a compact runtime spec for an LLM agent.
Each axiom packet applies one or more theories to the
convention itself.

| Theory | Axiom(s) | Used by |
|--------|----------|---------|
| [curry-howard](curry-howard.md) | A2 | packet structure, verifier |
| [predicate](predicate.md) | A4 | every check is a predicate |
| [fsm](fsm.md) | A4 | lifecycle FSM |
| [refinement](refinement.md) | A4 | packet ↔ implementation |
| [verdict](verdict.md) | A5 | five outcomes of verification |
| [epistemic](epistemic.md) | A5 | five epistemic markers |
| [deprecation](deprecation.md) | A5 | supersession DAG |
| [agent](agent.md) | A6 | LLM as runtime substrate |

Order reflects axiom dependency. axiom A0 (Difference) is
ontological; it stands above these eight. axiom A6
(Self-Application) is meta; it stands below.