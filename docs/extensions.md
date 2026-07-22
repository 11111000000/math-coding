# Extensions

math-coding v0.992 is a complete convention. Extensions are
**optional** artefacts that extend the convention without
modifying it.

## When to extend

An extension is justified when:

1. The convention's seven axioms do not cover a need.
2. The need is concrete and recurring.
3. The extension can be implemented without changes to
   `core/`, `theories/`, or `docs/`.

If the need requires touching one of these, write a
`standard` or `strict` packet and submit it for review.

## How to extend

1. Create a directory under `extensions/<name>/`.
2. Add your tools, substrates, or adaptors there.
3. Reference the extension from a packet under `math/` if
   it implements an axiom-related capability.

## What goes in extensions/

  substrates/      TLA+, Coq, Alloy, BPMN, PRISM adapters
  agents/          AI agent adaptors (opencode, claude-code, cursor)
  ci/              CI workflows
  examples/        brownfield install examples

## What does NOT go in extensions/

  anything that modifies one of the seven axioms — that requires a new
  convention version
  anything that lives inside core/, theories/, or docs/ —
  those are the convention itself
  anything that hides axiom Self-Application — the
  convention must remain self-verifying

## Current extensions

  agents/opencode/SKILL.md   OpenCode skill loader
  ci/github-actions-tdd.yml  GitHub Actions workflow template

## Open extensions (planned, not yet implemented)

  tla/    optional TLA+ substrate for safety-critical packets
  coq/    optional Coq substrate for cryptographic packets
  bpmn/   optional BPMN substrate for workflow packets
