# Refinement: core

## State mapping

- Spec → `core.md` content
- Implementation → files in this repository (schemas, verifier, examples)
- Refinement map → each invariant in `core.md` has a corresponding check in `examples/self-application/verify-consistency.sh`

## Operation mapping

- Open packet → create directory with `packet.yaml`, `task.md`, `assumptions.yaml`
- Verify packet → run verifier, write `verifier-output.yaml` with verdict
- Deprecate packet → set `lifecycle: deprecated` and write `supersession.yaml`

## Invariant preservation

- Each invariant in `core.md` has a corresponding shell check
- Verifier reports VERIFIED iff all checks pass
- Verifier is idempotent: same input → same verdict

## Test obligation mapping

- For each invariant in `core.md`, a counterexample test exists (either explicit test packet or negative test in shell)
- Each forbidden FSM transition must be prevented by the verifier
- The verifier checks itself via `examples/self-application/`

## Runtime-check mapping

- Verifier runs in CI on every commit (`.github/workflows/verify.yml`)
- Verifier writes `examples/self-application/verifier-output.yaml` with `verified_at`, `scope`, `tool`, `evidence`
- Each packet's `verifier-output.yaml` is updated by its own verifier script

## Connection

This packet is the convention. Every other packet's
`refinement.md` cites `core.md` for structural rules. The
verifier implements the rules. The theory documents in
`core/01-Theory/` justify the rules.