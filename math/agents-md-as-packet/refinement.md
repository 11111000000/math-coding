# Refinement: agents-md-as-packet

## State

- **pre**: agents.md exists at root but no packet authorizes it
- **post**: agents.md is authorized as convention-OS by this packet

## Operation

- This packet records the decision to have an agents.md
- It does NOT modify agents.md
- It references core-as-packet (which authorizes core/)

## Invariant

- agents.md exists at repo root
- agents.md line count ≤ 50 (math-coding-birth invariant)
- This packet has 5 files (matching convention)
- agents.md is OS, not in math/, not in core/

## Convention axes affected

- **Brownfield mode (refinement.md §14):** agents.md
  establishes what agents do in projects where most files
  are OS, not packets.
- **Edit protocol (refinement.md §15):** agents.md
  states when direct edits are OK vs when supersession
  is required.

## OS files authorized (1)

1. `agents.md` at repo root — agent protocol

## Test obligation

- `wc -l agents.md` ≤ 50
- This packet is in math/agents-md-as-packet/ with 5 files
- `git log --oneline | head` shows birth → core-as-packet → agents-md-as-packet

## Runtime check

- None required yet
