# math-coding v0.618

A convention for mathematically grounded software artifacts.
Plain text + git. No external dependencies. No frameworks.

## Why

Vibe-coding optimizes for local plausibility. The code looks
fine in the moment, breaks the first time a user clicks
twice, a request arrives out of order, or a deployment
scales past one node. math-coding replaces this: every
decision becomes a packet, every packet is mechanically
verifiable, the chat is not the spec, the code is not
the first artifact.

## What

Every directory in `math/` is a packet. Each packet has
exactly 5 files:
- `packet.yaml` — manifest (task_id, lifecycle, decision: made)
- `decision.md` — thesis / antithesis / synthesis
- `task.md` — problem / desired outcome / constraints
- `assumptions.yaml` — explicit assumptions with epistemic markers
- `refinement.md` — how the convention extends or supersedes itself

## How

Read `math/math-coding-birth/` to see the first packet. Then
read `agents.md` for the protocol. After commit 2, every key
decision about the convention lives as its own packet in
`math/`.

## What this is NOT

This is not a framework. There is no library to install,
no API to call, no runtime to embed. The convention is the
set of rules; the artifacts are the substance. The recursive
property ("the convention applies to itself") is an assumption
with evidence (A4 in `math-coding-birth`), not an axiom.
