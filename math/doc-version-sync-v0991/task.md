# doc-version-sync-v0991

## Problem

README.md and AGENTS.md identify the project as v0.854 and
reference commands and lifecycle states that no longer match
the v0.991 dispatcher. A new reader sees `init`,
`sketch → verified`, and a six-state lifecycle that the code
no longer implements.

## Desired outcome

README.md and AGENTS.md describe the current interface:
- project version v0.991
- packets created via `create --from spec.yaml`
- lifecycle `draft → applied → retired` with `abandoned` and
  `archived` as terminal side states
- dispatcher commands including `apply`, `review`, `abandon`,
  `lifecycle`, `config`, `install-skill`, and `stable`

## Constraints

- No code, theories, or axiom packets may change.
- axiom Self-Application must remain PROVEN after the edits.
- `sh tests/run.sh` must remain 44 PASS / 0 FAIL.
