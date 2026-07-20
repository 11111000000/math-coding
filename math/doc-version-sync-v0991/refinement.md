# Refinement: doc-version-sync-v0991

## State

- pre: README.md and AGENTS.md claim v0.854 and list stale
  commands (`init`, `sketch → verified`).
- post: README.md and AGENTS.md claim v0.991 and list current
  commands and lifecycle states.

## Operation

1. Create this standard packet under
   `math/doc-version-sync-v0991/`.
2. Rewrite README.md:
   - header version to v0.991
   - command list to match `math-coding help`
   - quick start to use `create --from spec.yaml`
   - lifecycle to `draft → applied → retired` with
     `abandoned`/`archived`/`superseded` as side states
3. Rewrite AGENTS.md analogously.
4. Leave all code, theories, and axiom packets untouched.

## Mapping

- spec: README/AGENTS describe the v0.991 interface
- impl: the two markdown files are edited; no script changes

## Invariant preservation

axiom Self-Application still holds after the documentation
change: `sh math-coding probe` exits 0 and
`sh tests/run.sh` remains 44 PASS / 0 FAIL.

## Test obligation

1. `sh math-coding verify` reports 0 errors, 0 warnings.
2. `sh math-coding probe` reports PROVEN.
3. `sh tests/run.sh` reports 44 PASS, 0 FAIL.

## Runtime check

After the packet is applied, periodically re-run
`sh math-coding probe` in CI or pre-commit to catch future
drift between documentation and code.
