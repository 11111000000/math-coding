# Contributing to math-coding

math-coding is a convention for AI coding agents. Contributions
are packets. Every change to the convention itself is a packet
under `math/`.

## Modes

  light    — commit message only
  standard — full 5-file packet (most changes)
  strict   — packet + theory link (architectural changes)

## Pull request

Every PR includes:

  Intent      one sentence (one goal)
  Pressure    bug | feature | debt | ops
  Mode        light | standard | strict
  Surface     touches: <element> [FROZEN|FLUID]
  Proof       which tests/verifier proves the change

If the change touches a [FROZEN] element, include a
Migration note (impact, strategy, window, rollback).

## Decision gate

The convention's own rules apply to PR review:

1. The packet is filed under `math/`.
2. The verifier (`sh math-coding verify`) passes.
3. axiom Self-Application (`sh math-coding probe`) holds.
4. The lifecycle transitions are documented in
   `applications[]` SHA.

## What changes need a packet

Any change to `core/`, `theories/`, `docs/`, or `math/`
needs a packet.

Any change to `extensions/` needs a packet that names the
extension.

A change to `LICENSE`, `AGENTS.md`, `README.md`,
`CONTRIBUTING.md`, `CHANGELOG.md`, `.gitignore`, or
`math-coding` (dispatcher) needs at minimum a `light`
commit with a rationale in the commit message.

## What changes do not need a packet

Typo fixes. Doc clarification. Renaming in a non-loaded
file. Any change that does not touch convention structure.

## Communication

Issues: open for clarification or proposal.
PRs: name the packet in the title (`my-feature: short
description`). Reference the axiom packet if the change
implements an axiom.

## Community norms

- Be specific. The packet's `decision.md:thesis` is the
  claim. If the claim is vague, the packet is vague.
- Be honest. The packet's `assumptions.yaml:epistemology`
  is the marker. If you mark `fact`, you must have evidence.
- Be concise. The packet has five files; each file has a
  role. Anything that does not serve the role does not
  belong.