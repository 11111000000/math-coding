# math-coding — opencode Integration

This file tells opencode how to handle math-coding tasks
in this repository. opencode reads this file when invoked.

## Reference

When the user mentions math-coding, packets, lifecycle, FSM,
TLA+, or any convention-specific term, read:

- `core/core.md` — canonical convention
- `agents/agents.md` — agent instructions
- The relevant theory from `core/01-Theory/`
- `examples/hello/` — minimal packet template

## Commands

The following slash commands are available:

- `/mathpacket <id> [title]` — create a new packet
- `/verify` — run the structural verifier

## Workflow

When asked to make a non-trivial change:

1. Open a packet (use `/mathpacket`)
2. Fill in task.md, assumptions.yaml, packet.yaml
3. Apply the epistemic protocol (judgment / unknown / fact / hypothesis)
4. Run `/verify`
5. Promote lifecycle only if verifier passed
6. Write refinement.md and traceability.json for verified packets

## When NOT to use math-coding

If the user asks for a trivial change (rename, typo, one-line
fix), do it directly. The decision gate is 4+ implicit assumptions
(ADR-0002). Override is allowed with judgment documented in
`# Adaptations`.

## Mathematical grounding

The convention cites 8 mathematical theories. When reasoning
about a packet's correctness, you may reference these theories
for the formal definitions. This is what makes math-coding
different from a generic convention: it's grounded in formal
mathematics, not in arbitrary rules.