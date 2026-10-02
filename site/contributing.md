# Contributing

> **The protocol applies to itself.** Pull requests that
> touch the kernel, constitution, schemas, or authority
> rules follow `AGENTS.md` §Self-application. Pull
> requests that touch anything else follow the working
> chain.

## The working chain

```text
intent -> decision -> obligation -> change -> attestation -> revision
```

Every commit on `main` closes at least one obligation. No
obligation closes without a positive + negative fixture.
No kernel change ships without a `decisions/*.yaml`
decision under the active policy.

## Branching

- **Tier 1+**: feature branch off `main`, named
  `<group>/<slug>` (e.g. `site/tufte-redesign`,
  `mc/packages-html`).
- **Tier 3+**: split across multiple PRs per `OCAML_BEST_PRACTICES.md`
  §P4 merge order: decisions first, fixtures second,
  pure kernel helpers third, `bin/Mathc.ml` last.
- **Worktree first**: every change happens in a git
  worktree (see `worktree-first` skill).

## Pre-commit checks

Run `scripts/dev verify` before `git commit`. It runs:

1. `pkill` stale `dune`/`nix develop` (cleans `_build/.lock`)
2. `dune build`
3. `dune test`
4. `scripts/fmt-check.sh`
5. `scripts/check.sh`

Each step is independent so a fail in step 3 doesn't
skip step 4. ~30-60 s total.

## Protected policy transitions

Changes to the constitution, kernel, gate rules, authority
rules, or waiver rules require **all** of the following
(per `AGENTS.md` §Self-application):

1. a decision under the currently active rules;
2. a strongest practical countercase;
3. positive and negative conformance fixtures;
4. a migration and recovery path;
5. authorization by the previous active policy;
6. an explicit list of changed verdicts.

Candidate rules cannot authorize their own adoption.

## Conventional Commits prefix

Use `Conventional Commits` for the commit subject (≤72
chars):

```
feat(scope): summary
fix(scope): summary
refactor(scope): summary
docs(scope): summary
chore(scope): summary
attestations: ...
ci: ...
```

PR titles follow the same convention. The scope should
name the package or kernel module affected
(`mc-self-check`, `lib/render`, `bin/Mathc`,
`decisions/site-deploy`, etc.).

## Time-honest commits

Every commit message that mentions duration is followed by a
parens clause naming the scale and reference class:

```text
feat(kernel): add risk classifier (kernel-change p95≈150min,
  ref: SWE-bench-V 2025-Q4)
```

Anti-patterns (which the maintainer will reject):

- "Spent two days on this." — wall-clock-minutes claim
  without a session-start.
- "Quick fix, a few minutes." — duration claim without
  a recorded value.
- "A week of careful thinking." — mixes wall-clock with
  subjective attention.

## Trivial reminders

- All decisions must include frontmatter
  (`schema`, `id`, `revision`); see
  `decisions/decision.yaml` for the format.
- All obligations must declare a verifier; see the
  `acceptance:` block conventions in
  `OCAML_BEST_PRACTICES.md` §2.4.
- All cram fixtures live under `tests/cli/*.t`; never
  re-create `tests/cram/`.
- All time estimates cite a reference class from
  `bin/data/time-distribution.yaml` via `mc time-estimate`.

## When you get stuck

The OCaml trap log is at `OCAML_BEST_PRACTICES.md` §11.
Read it before adding any. If the next bug is not there, fix
the root cause and append a new trap entry before merging.

## See also

- [README](readme.html) — the project pitch.
- [Workflow](workflow.html) — the six-step loop.
- [FAQ](faq.html) — the questions we hear most.
- `AGENTS.md` §Self-application — the protected-policy checklist.
- `OCAML_BEST_PRACTICES.md` — the OCaml convention.