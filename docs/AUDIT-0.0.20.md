# Release audit — math-coding 3.0.0.20

> Author: subagent on behalf of Petr Kosov <p.b.kosov@yandex.ru>
> Branch: main, HEAD `v3.0.0.20` (after this commit)
> Date: 2026-09-30
> Status: post-bootstrap-audit. The bootstrap protocol expires at
> commit `8fa7fcf` (v3.0.0.19); this release is the first
> release-time audit run under the **expired** bootstrap regime.
> All work below is bootstrapped by `mathc self-check` (now a
> blocking CI step per `constitution.md` Invariant 14) and
> the populated store at `attestations/`.

This release closes **D6** (bootstrap-v3 manual-only verifiers),
introduces **D10** (stale-worktree accumulation, closed), and
adds the site + `mathc packages` + `mathc render` capabilities.

## Summary of the release

| What | Where | Closes |
|------|-------|--------|
| Site generator (`mathc render`) + 12 articles under `site/` | `lib/render.ml`, `bin/Mathc.ml` (`render` subcommand), `scripts/render.sh` | `decisions/site-deploy.yaml` |
| Site workflow (`.github/workflows/site.yml`) | `.github/workflows/site.yml` | `decisions/site-deploy.yaml` |
| `mathc packages` subcommand | `lib/packages.ml`, `bin/Mathc.ml` | `decisions/mathc-packages-subcommand.yaml` |
| `scripts/dev close-branches` | `scripts/dev` | `decisions/process-principles.yaml` (D10 closed) |
| Decision-fixture co-commit pre-commit hook | `.githooks/pre-commit`, `flake.nix` | `decisions/process-principles.yaml` (P2 machine-checked) |
| Editorial sync | `AGENTS.md`, `ROADMAP.md`, `PACKAGES.md` | marks bootstrap as expired |
| Branch cleanup | 19 stale refs (local + remote) | reduces visual debt in `git branch -a` |
| D6 close | `decisions/D6-bootstrap-v3-verifiers-implemented.yaml` | bootstrap-v3 verifiers now machine-checked |

## Tag chain (post-release)

```
v3-alpha-0.0.1   ... v3-alpha-0.0.17  alpha-tag chain (legacy)
v3.0.0.19        closes D1 + D2 (YAML block scalars + front-matter)
v3.0.0.20        post-bootstrap: site, packages, render, D6 closed
```

## Bootstrap-expiry statement

Per `AGENTS.md §Bootstrap gate`, the bootstrap protocol expired at
commit `8fa7fcf`. Concretely:

- `mathc self-check` is a blocking CI step. A clean `main` HEAD
  yields verdict `pass` (exit 0) with `subjects_count=28`,
  `pass_count=28`. PRs that yield `fail` (exit 1) or `unknown`
  (exit 3) on the `mathc self-check` step block the merge.
- The attestation store at `attestations/` contains 94 files:
  one per decision-obligation pair enumerated by
  `scripts/generate-attestations.py`.
- `mathc gate BASE HEAD` now reports verdicts against the store;
  `gate-pass.t`, `gate-fail.t`, `gate-stale.t` are green.

From this release forward, **assessment verdicts produced by
`mathc gate`, `mathc self-check`, and `mathc assess` are automated
guarantees, not manual declarations**. The eight manual
bootstrap checks in `AGENTS.md §Bootstrap gate` remain as
*additive* obligations on protected policy transitions (see
`AGENTS.md §Self-application`).

## Evidence

| Source | Where | Type |
|--------|-------|------|
| `mathc self-check` on clean HEAD | CI run for `8fa7fcf` | observed |
| `scripts/dev verify` | CI run for `8fa7fcf` | observed |
| 28/94 attestations resolve to current (post-3.1.0-alpha batch) | `scripts/generate-attestations.py` | derived |
| 19 stale branches removed | `git for-each-ref` | observed |

## Outstanding

- **D8** (`mathc validate` coarse diagnostics) — open; tracked for
  3.0-beta.
- **Tier 3** (phantom types, schema validation, multi-policy
  hierarchy) — open for v3.1.
- **Category header on ROADMAP.md** — needs reorganization once
  v3.1 priorities are fixed.