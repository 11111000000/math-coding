# spec-consolidation-v0992

## Thesis

  docs/ dies. core/spec/ becomes the single home for normative content (axioms, fsm, packet-schema, extensions). meta/ holds dev tooling. No duplication.

## Antithesis

  Moving axioms.md adds historical-commits noise and obscures git blame. Theories/fsm.md is genuinely theory (axiom Process), not spec — moving it loses that mapping.

## Synthesis

  History is preserved by git. fsm.md is moved because it defines the FSM contract (what), not because of axis Process (why). Axiom A4 explains why FSM matters via theories/refinement.md and theories/predicate.md.
