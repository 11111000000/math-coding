# Refinement: 02-curry-howard

## State

- pre: a packet is whatever the author chose — a paragraph,
  a checklist, a folder of files.
- post: a packet is exactly five files with fixed roles.
  Verifier can check structure mechanically.

## Operation

Whenever a packet is created, generate five files from
`init-packet.sh`. Each file has one role. The verifier
checks that every role is filled.

## Mapping

| proof-term part | packet file |
|-----------------|-------------|
| type signature  | packet.yaml |
| proposition    | decision.md |
| goal           | task.md     |
| context Γ      | assumptions.yaml |
| elaboration    | refinement.md |

## Invariant preservation

- The five roles are preserved under refactoring.
- Removing a file breaks the proof; verifier exits non-zero.

## Test obligation

- `sh core/check/verify.sh` exits 0 on a well-formed packet.

## Runtime check

- axiom Self-Application — convention verifies its own packets.