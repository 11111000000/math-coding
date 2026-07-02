# Refinement: theory-02-state-machine

## State mapping

- Model state $S$ (packet lifecycle states) → `packet.yaml.lifecycle` value
- Initial state $s_0 = \text{sketch}$ → enforced by verifier (every new
  packet starts with `lifecycle: sketch`)
- Action $a \in A$ → atomic change to `packet.yaml.lifecycle`
- Transition $s \xrightarrow{a} s'$ → commit that changes lifecycle
- Invariant $I$ → structural invariants in `core/core.md`

## Operation mapping

- `formalize(packet)` (sketch → working): add `Model.tla` or `verify.sh`
- `verify(packet)` (working → verified): run verifier, get `VERIFIED`
- `deprecate(packet)` (* → deprecated): set lifecycle + `deprecated_at`
- `archive(packet)` (deprecated → archived): set lifecycle + `archived_at`
- `reopen(packet)` (verified → working): verifier returned non-VERIFIED

## Invariant preservation

- Every packet has a valid `lifecycle` field (enum check)
- A packet with `lifecycle: verified` has a `verifier-output.yaml` with
  `verdict: VERIFIED`
- A packet with `lifecycle: archived` has an `archived_at` date

## Test obligation mapping

- For each transition in the FSM, the verifier should be able to express
  it as an invariant check
- Counterexample tests: a packet that violates `I` should fail

## Runtime-check mapping

- `check_packet()` in verifier reads `lifecycle` and applies per-state
  rules
- `lifecycle_history` field (when present) records all past transitions
- Forbidder transitions are encoded as "impossible values" of the
  transition function; the verifier checks for them

## Connection

This packet's FSM definition is **the basis** for `core/core.md:§Lifecycle`.
Any change to the lifecycle FSM must be reflected here, and vice versa.
The traceability link ensures both are updated together.