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