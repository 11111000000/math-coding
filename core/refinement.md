# Refinement: core

## State mapping

- Spec → `core.md` content
- Implementation → `examples/self-application/verify-consistency.sh`
- Refinement map → verifier function in shell

## Operation mapping

- `Open packet` → create directory with required files
- `Verify packet` → run verifier, write verdict
- `Deprecate packet` → set lifecycle, write `supersession.yaml`

## Invariant preservation

- Each invariant in core.md has a corresponding shell check
- Verifier reports VERIFIED iff all checks pass

## Test obligation mapping

- Counterexample tests for each invariant
- Each forbidden transition must be prevented by the verifier

## Runtime-check mapping

- Verifier runs in CI on every commit
- Verifier writes `verifier-output.yaml` with timestamp, scope,
  tool, evidence

## Connection

This packet **is** the convention. Every other packet's
`refinement.md` cites this one for structural rules. The
verifier implements the rules. The theory documents justify
them.