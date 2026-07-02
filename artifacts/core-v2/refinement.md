# Refinement: core-v2

## State mapping

- Spec $\text{Spec}_{\text{core}}$ → `core/core.md:§Structural invariants`
- Implementation $\text{Impl}_{\text{core}}$ → shell code in
  `examples/self-application/verify-consistency.sh`
- Refinement map $R$ → `check_packet()` and related shell
  functions

## Operation mapping

- `Open packet` → `cp templates/* <dir>/`
- `Verify packet` → `sh verify-consistency.sh`
- `Promote lifecycle` → edit `packet.yaml.lifecycle`, run verifier
- `Deprecate packet` → set `lifecycle`, `deprecated_at`, `supersession`

## Invariant preservation

- Every invariant in `core/core.md:§Structural invariants` has
  a corresponding shell check
- If verifier reports VERIFIED, all checked invariants hold
- Liveness and fairness are declared in FSM but not checked
  mechanically

## Test obligation mapping

- For each invariant, a counterexample packet exists and
  fails verification
- For each forbidden FSM transition, a packet attempting it
  fails
- For each `UNVERIFIABLE:*` subtype, a test packet exists that
  produces it

## Runtime-check mapping

- Verifier runs `check_packet()` for every packet
- Each branch in `check_packet` corresponds to an invariant
- `check_assumptions()` enforces epistemic enum
- `check_dependencies()` enforces `depends_on` resolution

## Connection

`core-v2` is the **bridge** between the 8 theory documents and
the concrete `core/core.md`. Each section of `core/core.md`
cites the relevant theory document. The verifier implements
the structural checks; the theory documents explain why those
checks are correct.