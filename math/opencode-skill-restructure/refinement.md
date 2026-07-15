# Refinement: opencode-skill-restructure

## State

- pre: SKILL.md is 117 lines. Every agent reads all of it.
- post: SKILL.md is ≤50 lines. References/ has 4 files.
  Examples/ has 1 example spec. The agent reads what it needs.

## Operation

`SKILL.md`:
- 7 axioms (1-2 lines each)
- 5 files (1 line each)
- 3 modes (1 line each)
- 6 lifecycle states (1 line each)
- 8 commands (1 line each)
- ~10 lines of context

`references/axioms.md`:
- Full axiom statements (~10-20 lines each)
- Axiom-by-axiom definitions

`references/theories.md`:
- 8 theories (~10-15 lines each)
- Theory-to-axiom mapping

`references/lifecycle.md`:
- FSM (states, transitions, I(s) for each state)
- When to use which state
- How to transition

`examples/cache-ttl-spec.yaml`:
- Full YAML spec for a cache-ttl packet
- Demonstrates: thesis, antithesis, synthesis,
  surface_impact, proof, problem, outcome, constraints,
  assumptions, state, operation, mapping, invariant,
  test_obligation, runtime_check

## Mapping

| reference | loaded when agent |
|-----------|---------------------|
| `references/axioms.md` | cites an axiom (e.g. "this implements axiom Process") |
| `references/theories.md` | asks about a theory (e.g. "what is Curry-Howard?") |
| `references/lifecycle.md` | changes a packet's lifecycle (sketch → working → verified) |
| `examples/cache-ttl-spec.yaml` | creates a new packet from a spec |

## Invariant preservation

- The convention is unchanged. axiom A6 still holds.
- The skill is plain text (axiom Material Basis).
- The skill is loadable by opencode.

## Test obligation

Manual test: the skill loads successfully in opencode.
The entry file is ≤50 lines. The references are present.
`sh math-coding probe` still exits 0.

## Runtime check

None. The skill is loaded at agent-start time.