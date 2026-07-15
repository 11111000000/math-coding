# opencode-skill-restructure

## Problem

The opencode skill is one 117-line file. Every LLM agent
that loads the skill pays 2,500 context tokens. Most of the
content is reference material that the agent reads on
demand, not on load.

## Desired outcome

A split skill: one entry file (~50 lines) and four
reference files (loaded on demand). The agent reads what it
needs, when it needs it.

## Constraints

- POSIX shell only (axiom Material Basis).
- The split skill still satisfies axiom A6 (Self-Application):
  the convention must still be self-verifying.
- No new dependencies: the skill is plain text in
  `extensions/agents/opencode/`.