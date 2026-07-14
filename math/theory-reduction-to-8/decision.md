# theory-reduction-to-8

## Thesis

math-coding v0.618 has 12 theories. Four of them duplicate
content from foundational theories and create dependence
cycles that obscure the core pattern:

- `ltl` re-states `fsm` lifecycle trajectories.
- `modal` re-states `fsm` branching-time properties.
- `assumption` is a special case of `predicate` (a set of
  predicates in context Γ).
- `confidence` is a function over `epistemic` markers.

## Antithesis

Twelve theories cover edge cases: a researcher may need
LTL for reactive systems, modal logic for branching
properties. Removing them narrows the convention's
expressiveness.

## Synthesis

Reduce to 8 theories — 4 foundational + 4 applied:

Foundational (F-source-of-truth):

1. `curry-howard` — proposition ↔ type.
2. `predicate` — every check is a predicate over state.
3. `fsm` — lifecycle is a finite state machine.
4. `refinement` — packet = spec, code = impl.

Applied (F-instantiations):

5. `verdict` — verifier outcomes.
6. `epistemic` — 5 markers + confidence.
7. `deprecation` — supersession partial order.
8. `agent` — LLM as runtime substrate.

The four removed theories (ltl, modal, assumption, confidence)
are *subsumed* — their content reappears as paragraphs in
the remaining foundational theories, not as separate files.

## What this packet commits to

- Remove `core/theories/{ltl,modal,assumption,confidence}.md`.
- Update `core/packet-schema.md` if it lists theories.
- The remaining 8 theory files stay unchanged (content
  may grow by absorbing dropped material).

## What this packet does NOT commit to

- No new theories.
- No change to FSM (lifecycle states stay: sketch,
  working, verified, deprecated, archived, superseded).