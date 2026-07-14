# Refinement: extract-packet-reverse

## State

- pre: 5 files of a packet exist (math/<name>/).
- post: 1 YAML spec on stdout, ready to be ingested by
  create-packet.sh or any other tool.

## Operation

`sh math-coding extract <name>` reads:
  - packet.yaml  → name, mode, lifecycle, etc.
  - decision.md  → Thesis, Antithesis, Synthesis, Surface,
                    Proof (parsed by section header)
  - task.md      → Problem, Desired outcome, Constraints
  - assumptions.yaml → assumptions (parsed as YAML)
  - refinement.md → State pre/post, Operation, Mapping,
                    Invariant, Test, Runtime

Emits to stdout in the same shape as `create-packet.sh`
input.

## Mapping

| source file          | spec field          |
|----------------------|---------------------|
| packet.yaml:task_id  | name                |
| decision.md:## Thesis | thesis              |
| decision.md:## Antithesis | antithesis       |
| decision.md:## Synthesis | synthesis         |
| decision.md:## Surface impact | surface_impact |
| decision.md:## Proof | proof                |
| task.md:## Problem   | problem              |
| task.md:## Desired outcome | outcome         |
| task.md:## Constraints (list) | constraints |
| assumptions.yaml (list) | assumptions       |
| refinement.md:## State pre | state.pre        |
| refinement.md:## State post | state.post      |
| refinement.md:## Operation | operation        |
| refinement.md:## Mapping | mapping            |
| refinement.md:## Invariant preservation | invariant |
| refinement.md:## Test obligation | test_obligation |
| refinement.md:## Runtime check | runtime_check |

## Invariant preservation

- Every field in the 5 files appears in the spec.
- Round-trip (extract → create) produces the same 5 files
  with the same content.
- axiom Self-Application holds for the original and
  re-created packets.

## Test obligation

`tests/run.sh` adds a case: extract a packet, re-create it
with `create-packet.sh`, compare file lists, compare
content hashes, assert equality. Exit 0 iff round-trip is
lossless.

## Runtime check

None. extract is a tool, not a runtime concern.