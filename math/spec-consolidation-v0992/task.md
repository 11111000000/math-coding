# spec-consolidation-v0992

## Problem

  docs/ dies. core/spec/ becomes the single home for normative content (axioms, fsm, packet-schema, extensions). meta/ holds dev tooling. No duplication.

## Desired outcome

  One source of truth per fact. Each axiom or FSM state lives in exactly one file under core/spec/. Generated SKILL.md rebuilds automatically.

## Constraints

- proposition must remain true
- invariant must hold across all transitions
