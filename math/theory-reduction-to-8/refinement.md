# Refinement: theory-reduction-to-8

## State

- pre: `core/theories/` has 12 files:
  curry-howard, predicate, fsm, refinement, verdict,
  epistemic, deprecation, assumption, confidence, ltl,
  modal, agent.
- post: `core/theories/` has 8 files:
  curry-howard, predicate, fsm, refinement, verdict,
  epistemic, deprecation, agent.

## Operation

`rm core/theories/{ltl,modal,assumption,confidence}.md`

## Mapping

| Removed theory | Folds into |
|----------------|-------------|
| ltl | fsm (lifecycle trajectories) |
| modal | fsm (branching properties) |
| assumption | predicate (Σ as predicate set) |
| confidence | epistemic (I(c) formula) |

## Invariant preservation

- 4 foundational theories unchanged.
- 4 applied theories unchanged.
- Reference theories (the ones cited from packet.yaml's
  `evidence:`) remain valid.

## Test obligation

- `ls core/theories/*.md | wc -l` returns 8.
- `git ls-tree -r HEAD core/theories/ | wc -l` returns 8.

## Runtime check

None.