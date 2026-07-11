# Refinement: core-as-packet

## State

- **pre**: math-coding has 12 OS files in core/ but no packet
  authorizes them
- **post**: core/ is authorized by core-as-packet

## Operation

- This packet exists as the decision-record for core/
- It does NOT modify any file in core/
- The 12 OS files remain unchanged after this commit

## Invariant

- core/ has exactly 12 OS files (1 schema + 11 theories)
- This packet is in math/, not core/
- This packet has 5 files (matching convention)
- This packet has depends_on: [math-coding-birth] (recursive)

## OS files authorized (12)

1. `core/packet-schema.md` — packet field schema
2-12. `core/theories/{predicate,fsm,ltl,refinement,assumption,
verdict,epistemic,deprecation,curry-howard,modal,confidence}.md`

## Convention axes affected

- **OS rule (refinement.md §14):** "outside math/ files are OS,
  must be authorized by a packet" — this packet authorizes
  core/. Future OS files (like LICENSE added in commit 1.5)
  will need their own authorization.

## Test obligation

- `find core/ -name packet.yaml` returns empty (no packets in core/)
- `find core/ -type f | wc -l` returns 12
- This packet is in math/core-as-packet/ with 5 files

## Runtime check

- None required yet (no code to verify)
