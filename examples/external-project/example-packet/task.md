# Example external packet

## Problem

Demonstrates how a packet lives in a production project's
`specs/` directory and bridges to the project's source code
through `refinement.md` and `traceability.json`.

## Desired outcome

- One packet directory in `specs/example-external-packet/`
- Source code referenced from `refinement.md` lives in
  `src/payment/` (typical for a real project)
- `traceability.json` records the links from packet sections
  to source files

## Constraints

- Project code stays in its native structure (`src/`, `tests/`)
- must Packet structure follows `core/core.md`
- must `.mathcodingrc` declares `packets_dir: specs`
