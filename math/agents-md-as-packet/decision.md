# agents-md-as-packet — protocol for AI agents

## Thesis

AI coding agents (Claude, GPT-4, opencode) routinely read and
write files. math-coding must have a contract for how agents
interact with the convention — what they read first, what they
write, what they never modify. Without such a contract, agents
will improvise based on incomplete README.md, producing
inconsistent results.

## Antithesis

A long agent protocol becomes a maintenance burden. Each rule
becomes a debate. Each version change requires protocol
review. The protocol becomes its own convention-without-fractal-
property. The opposite failure mode: too rigid, agents
spend their time interpreting the protocol rather than working.

## Synthesis

A short protocol (< 50 lines) at the repo root, named
agents.md. The protocol tells the agent what to read, what to
write, and what never to edit. The protocol grows only when
needed — adding a rule requires a decision-packet that
supersedes this one.

## What this packet commits to

- agents.md exists at repo root with < 50 lines
- It documents: read order, write protocol, brownfield mode,
  assumption fields, edit rules
- This packet authorizes agents.md as convention-OS

## What this packet does NOT commit to

- A long agent manual (this is not a handbook)
- Encoding of all possible agent behaviors
- External scripts (those go in tools/ when needed)
