# math-coding CHANGELOG

> Single-source-of-truth for releases. Mirrors the `v3.x.y` git
> tags. The current release is highlighted.

## v3.1.0-alpha — 2026-09-30 — current

**Status:** algebra 3.2-ideal adopted as forward-looking formal
spec. The runtime kernel is unchanged (still v3.0.0.20); the
algebra is a normative supplement that future kernel releases
will implement.

### Added

- `spec/algebra-3.2.md` — formal mathematical specification
  (30 sections) of the 3.2-ideal kernel. Normative alongside
  `constitution.md`, `domain.md`, and `semantics.md`.
- `decisions/algebra-3.2.yaml` — bootstrap decision adopting
  the algebra as the authoritative formal spec for the
  3.2-ideal kernel.
- Applicability envelope (§28) — explicit decision tree for
  "when to use math-coding": projects evaluate
  `applicability(P, 𝒫)` and choose Path A (full 3.2) or
  Path C (no math-coding) on documented rationale.
- Two-tier cognitive model (§29) — separates the user-facing
  surface (~1100 lines of prose docs) from the kernel-developer
  surface (~3600 lines of normative spec); adoption friction
  scales with role.
- Binary distribution as architectural property (§30) — kernel
  ships as portable binaries for 5 target platforms; users do
  not need OCaml, nix, or dune on the host. Recorded as a
  known anti-property in current builds (nix-store glibc
  linkage); static-link or musl fix tracked separately in
  ROADMAP Tier 3.

### Spec changes

- `spec/algebra-3.2.md` published alongside `constitution.md`,
  `domain.md`, and `semantics.md`. The algebra is additive;
  the existing prose specs remain as historical context.
- 14 constitution invariants I1–I14 preserved verbatim.
- 5 axioms A0–A4 preserved verbatim.

### Implementation roadmap

ROADMAP.md Tier 3.5 enumerates the 13 implementation tasks
required to realize the 3.2 algebra on top of the 3.0.0.20
kernel:

- Schema extensions: `decision.json`, `attestation.json`,
  `obligation.json`, new `policy.json` (4 files).
- New kernel modules: `lib/policy.ml`, `lib/rebuttal.ml`,
  `lib/re_evaluation.ml` (3 new files).
- Multi-CI composition (§23) and rebuttal artifacts (§27)
  wired through the gate.
- Applicability envelope adoption guidance folded into
  `USAGE.md`.
- Binary distribution fix (§30 anti-property): static-link
  or musl-based build pipeline.

Out of scope for Tier 3.5: axiom-as-decision (tracked as a
separate feature). The algebra preserves A0–A4 as immutable
per A3 Self-Application; no decision may adopt or modify an
axiom.

### Backward compatibility

All 28 existing decisions in `decisions/*.yaml` remain valid
under the extended schema. New fields (decision `state`,
`sha`, epistemic markers; attestation freshness; obligation
phases) are optional with sensible defaults. No existing
decision requires modification. Migration is implicit; the
algebra adoption does not regress v3.0.0.20 conformance.

## v3.0.0.20 — 2026-09-30

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