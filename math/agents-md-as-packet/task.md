# agents-md-as-packet — task

## Problem

AI coding agents need a contract to interact consistently with
math-coding repositories. Without one, agents improvise based on
incomplete README.md, producing inconsistent work across
different agent runs and different agents.

## Desired outcome

A short protocol (under 50 lines) at the repo root that tells
the agent: (1) what to read first, (2) when to create a packet,
(3) when to create a new packet vs edit existing, (4) what
fields to fill in, (5) what NOT to modify.

## Constraints

- Plain text, no scripts in the protocol itself
- Protocol grows only when needed (new rules → supersession)
- agents.md lives at repo root (not in math/, not in core/)
- This packet authorizes agents.md as convention-OS
