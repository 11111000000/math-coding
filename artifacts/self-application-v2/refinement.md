# Refinement: self-application-v2

## State mapping

- Spec → `core/core.md:§Structural invariants`
- Implementation → `examples/self-application/verify-consistency.sh`
- Refinement map → each `check_*` shell function

## Operation mapping

- `check_packet` → reads packet.yaml, applies invariants
- `check_task_md` → reads task.md, checks sections and content
- `check_assumptions` → reads assumptions.yaml, validates enum
- `check_refinement` → reads refinement.md, checks 5 sections
- `check_traceability` → reads traceability.json, checks links
- `check_dependencies` → validates depends_on resolution

## Invariant preservation

- For each invariant in `core/core.md:§Structural invariants`,
  there is a corresponding shell check
- The verifier is **idempotent** on packet state: re-running
  on the same packets produces the same verdict
- The verifier writes provenance fields to verifier-output.yaml

## Test obligation mapping

- Each invariant has a counterexample test
- For each forbidden FSM transition, a test packet attempts it
  and fails

## Runtime-check mapping

- Run from repository root: `sh examples/self-application/verify-consistency.sh`
- Exit 0 iff all checks pass
- Writes `examples/self-application/verifier-output.yaml`

## Connection

This packet is the **concrete realization** of the convention.
It demonstrates that the convention can be applied to itself
without external tools.