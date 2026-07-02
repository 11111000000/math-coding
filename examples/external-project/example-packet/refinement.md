# Refinement: example-external-packet

## State mapping

- Spec → this packet's `task.md` (Problem, Desired outcome, Constraints)
- Implementation → project source code in `src/` (not in this packet)
- Bridge → `refinement.md` describes the mapping; `traceability.json`
  records concrete file paths

## Operation mapping

- "Open a packet" → run `sh .opencode/commands/mathpacket <id>`
  from project root (uses `.mathcodingrc` for `packets_dir`)
- "Refine" → fill `refinement.md` with state mapping,
  operation mapping, etc.
- "Verify" → run `sh specs/verify-consistency.sh`

## Invariant preservation

- The packet directory in `specs/` follows `core/core.md` structure
- The project source code in `src/` follows project conventions
- The two are kept separate; the bridge is explicit

## Test obligation mapping

- The structural verifier (light rigor) checks this packet's
  structure
- Project tests check the code in `src/`
- The packet and the tests verify **different things**: the
  packet verifies intent and structure; tests verify behavior

## Runtime-check mapping

- `sh specs/verify-consistency.sh` runs the structural verifier
- Project CI runs project tests
- Both run on every commit; both must pass

## Connection

This packet is a placeholder demonstrating external-project
mode. In a real project, this packet would describe a
specific feature (e.g., "payment handler validation rules"),
and `refinement.md` would point to actual `src/` files.