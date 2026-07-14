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

## What NOT to add (KISS-discipline)

math-coding follows **KISS in measure** (KISS in меру).
Before adding a new file or packet, ask:

1. **Does axiom Self-Application require it?**
   If the convention works without it, **do not add it**.
   axiom A6 is the gatekeeper: it must hold after your
   change.

2. **Does it duplicate existing content?**
   If `math/examples-cache-ttl/` is needed, the cache example
   in `AGENTS.md` is already there. **No duplication.**

3. **Is it part of the convention's core or an extension?**
   Core is `core/`, `theories/`, `math/`, `docs/`,
   `extensions/` (optional). If your file is none of
   these, **find a better home or don't add it**.

4. **Does it introduce a new axiom?**
   If yes, the axiom must be added to `docs/axioms.md`,
   named, with a packet. Without all three, it's incomplete.

5. **Is it a test?**
   Tests live in `tests/run.sh` as Cases. New tests must
   be hermetic (no host-repo state) and pass axiom A6.

If a proposed file or packet does not pass all five
questions, **reconsider** or **propose in an issue first**.

## Removed (KISS-violations, do not re-add)

- `math/examples-cache-ttl/` — duplicated AGENTS.md content.
- `extensions/tla/README.md` — deferred until TLA+ is used.
- `math/extension-tla-guide/` — placeholder, never filled.

These were removed as KISS-violations. If you have a strong
reason to re-add them, **discuss in an issue first**.

## Community norms

- Be specific. The packet's `decision.md:thesis` is the
  claim. If the claim is vague, the packet is vague.
- Be honest. The packet's `assumptions.yaml:epistemology`
  is the marker. If you mark `fact`, you must have evidence.
- Be concise. The packet has five files; each file has a
  role. Anything that does not serve the role does not
  belong.
- Be KISS. Every file or packet must answer "what breaks
  if I remove this?" If the answer is "nothing", remove it.