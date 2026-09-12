---
proposition: "The opencode skill for math-coding is one file (`SKILL.md`, 117 lines). This is too long for an entry point: every LLM agent reads it on load. The skill is split into one entry file (≤50 lines, with the seven axioms) and four reference "
antithesis: "A single-file skill is simple. The agent reads one file and is done. Splitting it into five files requires the agent to navigate, which is friction. "
synthesis: "`SKILL.md` is the entry point: 7 axioms, 5 files, 3 modes, 6 lifecycle states, 8 commands. ~50 lines. `references/axioms.md` — full axiom statements (loaded "
axiom: 
substrate: none
---

# opencode-skill-restructure

## Thesis

The opencode skill for math-coding is one file (`SKILL.md`,
117 lines). This is too long for an entry point: every LLM
agent reads it on load. The skill is split into one entry
file (≤50 lines, with the seven axioms) and four reference
files (axioms, theories, lifecycle, spec examples). The
agent reads SKILL.md to learn the protocol; the agent reads
references/ on demand.

## Antithesis

A single-file skill is simple. The agent reads one file
and is done. Splitting it into five files requires the
agent to navigate, which is friction.

But the agent pays this friction **every time** it reads
the skill. A 117-line file uses ~2,500 context tokens at
load. A 50-line entry uses ~1,000 tokens. The split is
**cheaper** in the common case, and the references are
**loaded on demand**, when the agent has a question.

## Synthesis

`SKILL.md` is the entry point: 7 axioms, 5 files, 3 modes,
6 lifecycle states, 8 commands. ~50 lines.

`references/axioms.md` — full axiom statements (loaded
when the agent cites an axiom).

`references/theories.md` — eight theories (loaded when the
agent asks about a theory).

`references/lifecycle.md` — FSM states, transitions, when to
use which state (loaded when the agent changes a packet's
lifecycle).

`examples/cache-ttl-spec.yaml` — full example spec for the
cache-ttl example. Shows how the seven axioms appear in a
real spec. (Loaded when the agent creates a new packet.)

The skill is **discoverable**: SKILL.md says "see references/X
for X" at each relevant point.

## Worked example

An agent wants to create a new packet for "add caching":

1. Reads `SKILL.md` (50 lines, 1,000 tokens).
2. SKILL.md says: "use `create --from -` with a spec".
3. Agent produces a spec.
4. Agent invokes `sh math-coding create my-caching --from -` with the spec.
5. Five files appear in `math/my-caching/`.
6. Agent reads `references/lifecycle.md` to set `lifecycle: working`.
7. Agent reads `references/examples/cache-ttl-spec.yaml` to see a full example.

The agent **does not** read all 117 lines. The agent reads
what it needs, when it needs it.

## Surface impact

touches: `extensions/agents/opencode/SKILL.md` (split
into entry + references), `extensions/agents/opencode/references/*.md`
(new), `extensions/agents/opencode/examples/*.yaml` (new)

## Proof

`SKILL.md` after the split is ≤50 lines. The references
are loaded only on demand. The convention's axiom A6 (axiom
Self-Application) still holds: the split skill still describes
the same convention; `sh math-coding probe` still exits 0.
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