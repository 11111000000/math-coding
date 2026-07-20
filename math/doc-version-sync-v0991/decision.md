# doc-version-sync-v0991

## Thesis

  README.md and AGENTS.md accurately describe the v0.991
  dispatcher, packet lifecycle, and available commands.

## Antithesis

  Documentation version drift is harmless; users who need the
  real interface can read math-coding dispatcher source or run
  help. Updating README/AGENTS.md is cosmetic and risks
  introducing new inconsistencies.

## Synthesis

README.md and AGENTS.md are the first-contact surface for
humans and agents. Drift between these files and the code
produces real friction: README mentions `init` and
`sketch → verified`, while the dispatcher only supports
`create` and `draft → applied → retired`. Synchronizing the
documents with v0.991 reduces onboarding errors without
changing any behavior. The existing test suite is the witness.

## Surface impact

- touches: README.md (public landing page)
- touches: AGENTS.md (agent runtime hint)
- touches: 5 epistemic markers (assumptions.yaml)
- does not touch: core/, theories/, math/ axiom packets

## Proof

The evidence is `tests/run.sh`, which runs 44 self-tests
against the convention's own state. After the documentation
edit, `sh tests/run.sh` reports 44 PASS / 0 FAIL and
`sh math-coding probe` exits 0 with "axiom Self-Application
(definitional): PROVEN".
