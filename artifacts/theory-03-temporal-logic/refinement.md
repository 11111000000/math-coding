# Refinement: theory-03-temporal-logic

## State mapping

- LTL sequence $\sigma$ → packet lifecycle history (if
  `lifecycle_history` field is present)
- Operator `[]` → structural invariants checked at every state
- Operator `<>` → "eventually verified" — checked when `lifecycle == "verified"`
- Operator `~>` → "if X, then eventually Y" — encoded in transition
  relations
- `WF_a` / `SF_a` → optional fairness annotations in packet metadata

## Operation mapping

- **Check `[]I`**: verifier runs every time, treats each packet
  as a single state in $\sigma$
- **Check `<>P`**: verifier checks at least one packet has
  $P$ (where $P$ is a property like `lifecycle = verified`)
- **Check `P ~> Q`**: requires dependency graph (B depends on A);
  if A → Q then B must eventually → Q

## Invariant preservation

- Safety invariants `[]I` are preserved by every commit
- Liveness invariants `P ~> Q` are preserved iff the transition
  graph has the required edges
- Fairness `WF_a` is preserved iff the action `a` is always enabled

## Test obligation mapping

- For each `[]I` in `core/core.md`, the verifier checks $I$
- For each `P ~> Q`, a test asserts that the transition exists
- For `WF_a`, the verifier checks that $a$ is always enabled

## Runtime-check mapping

- Safety: `check_packet()` runs $I$ for every packet
- Liveness: not checked at runtime; documented as a property of
  the FSM
- Fairness: optional; can be added to FSM as additional constraint

## Connection

This packet's temporal operators extend `theory-02-state-machine`
with liveness. The combined FSM + LTL view is the basis for
`theory-06-verdict` (which encodes model-checker results).