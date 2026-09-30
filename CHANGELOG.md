# math-coding CHANGELOG

> Single-source-of-truth for releases. Mirrors the `v3.x.y` git
> tags. The current release is highlighted.

## v3.0.0.20 — 2026-09-30 — current

**Status:** bootstrap gate expired at v3.0.0.19; v3.0.0.20 ships
post-bootstrap hardening.

### Added

- `mc packages [--format=text|json|html]` — single-pane view of
  every decision-obligation-verdict pair in the repository.
- `mc render [--out DIR]` — static site generator; writes `dist/`
  with `index.html`, `axioms.html`, `methodology.html`,
  `bootstrap-gate.html`, `packages.html`, per-decision pages,
  per-axiom pages, and a JSON search index.
- `.github/workflows/site.yml` — nix-based GitHub Pages deploy on
  every push to main. Pinned to `ubuntu-22.04` (matches `ci.yml`;
  setup-ocaml/v2 needs darcs, unavailable on 24.04).
- `scripts/render.sh` — local site-build pipeline: builds mathc,
  runs `mc render`, copies assets, verifies the output allowlist,
  exits non-zero on any missing file (self-attestation).
- `scripts/dev close-branches [--yes]` — branch-hygiene utility
  per ROADMAP Tier-2 #4. Refuses to delete `main`, `HEAD`,
  `release/*`, or any branch with unpushed commits.
- `scripts/dev init-hooks` — one-time `git config core.hooksPath
  .githooks`.
- `.githooks/pre-commit` — local fast-path enforcement of P1
  (decisions before kernel changes) + P2 (decision paired with
  fixture) at commit time. Opt-in via `init-hooks`.
- `site/methodology.md`, `site/bootstrap-gate.md`,
  `site/packages.md`, `site/axioms.md` — four articles. The
  site **demonstrates** the methodology (built by the kernel,
  every page that documents a feature references `mc packages`).
- `assets/style.css`, `assets/site.js` — dark monospace theme,
  navigation toggle.
- `USAGE.md` — adoption runbook (install → adopt → author first
  decision → review-time questions → common kernel refusals).
- `tests/cli/packages.t`, `tests/cli/render.t` — cram fixtures
  for the two new subcommands.
- `tests/fixtures/close-branches-runs.sh`,
  `tests/fixtures/pre-commit-hook-installed.sh` — verifier
  fixtures for the close-branches + pre-commit-hook obligations.
- 10 new attestations (`scripts/generate-attestations-v3.0.0.20.sh`)
  covering the 4 new decisions; store now contains 80 files.

### Fixed

- `mc explain` dispatcher was a broken promise in
  `spec/semantics.md §`explain` ``omitted[].expansion``. Closed
  in v3.0.0.19 by commit `6e922d3`.
- `find_project_root` fallback chain (DUNE_SOURCEROOT +
  Sys.executable_name) closes the "kernel can't find its own
  repo" bug for cargo-style installs.

### Changed

- `AGENTS.md §Bootstrap gate` — bootstrap protocol expired at
  commit `8fa7fcf`; the eight manual checks remain as additive
  obligations on protected policy transitions.
- `ROADMAP.md` — Tier-1 marked closed; new Tier-1 entries:
  `mc packages`, `mc render`, `site-deploy`.
- `PACKAGES.md` — D1, D2, D4, D6, D10 marked closed; new
  decisions registered.
- `spec/semantics.md` — added `mc packages` and `mc render`
  subcommand rows.
- `bin/Mathc.ml` — added `do_packages` and `do_render`; the
  `--out` long-flag is now accepted for `mc render`.
- `lib/packages.ml` — pure kernel walker that joins decisions
  against the attestation store; renders JSON / text / HTML.
- `lib/render.ml` — pure site generator with a Markdown subset
  (headings, paragraphs, lists, code blocks, inline code).
- `tests/repo_structure.ml` — `site.yml` is allowed to
  reference `scripts/render.sh` (added in this release).
- `tests/process_principles.ml` — extended manual verifier
  prefixes (`bash`, `gh`, `grep`, `scripts/`, `dist/`, `git`,
  `jq`).

### Audit chain

- D1 (YAML block scalars) — closed at v3.0.0.19.
- D2 (YAML front-matter) — closed at v3.0.0.19.
- D4 (SHA-256 RFC vectors) — closed at v3.0.0.19.
- D6 (manual-only verifiers) — closed at v3.0.0.20.
- D10 (stale-worktree accumulation) — closed at v3.0.0.20.

### Branch cleanup

19 stale branches removed (local + remote where applicable):

```
ci/release-all-platforms
ci/release-binaries
ci/scripts-dev-verify
cram-cli-tests-v1
integration-tip
m3-foundation
m3/attestation-store-fill
m3/d4-sha256-fix
m3/gate-attestation-store
m3/mc-explain
m3/mc-self-check
m3/pre-existing-fixes
m3/traplog-restore
setup-site-and-ci
t-priority-drift
time-honesty
v0.0.10-format-baseline
v3-alpha-0.0.4-dev
v3-alpha-conformance-runner
yaml-block-scalars/v0.0.13
```

`setup-cicd-pages-releases` is intentionally retained (pre-bootstrap
history; not in scope).

## v3.0.0.19 — 2026-09-29 — bootstrap-gate expiry

**Status:** last release under the bootstrap protocol. Audit
chain: closes D1, D2, D4. Ships `mc explain`, `mc self-check`
dispatcher, attestation store (75 files populated), `mc gate`
real verdict against the store. CI step `mc self-check` becomes
blocking (`continue-on-error: false`).

## v3.0.0.18 and earlier

Pre-bootstrap alpha-tag chain. See
`git tag --list | grep v3-alpha` and the corresponding audit
documents in `doc/AUDIT-*.md`. The kernel had no automated
guarantee; assessment was a manual declaration per AGENTS.md.

## v2.1-final

Historical v2.1 implementation source, preserved by the
`v2.1-final` git tag. Not in the active tree; reachable via
`git switch v2.1-final`.