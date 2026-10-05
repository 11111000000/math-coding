# math-coding CHANGELOG

> Single-source-of-truth for releases. Mirrors the `v3.x.y` git
> tags. The current release is highlighted.

## Unreleased — v3.2.0-alpha (in development)

**Status:** §30 closure attempted; reversal signal fired on the
Alpine build leg. The musl-linux binary does NOT ship in this
release; the glibc pipeline is unchanged. See
`decisions/portable-linux-musl.yaml` rev 2 for the reversal chain.

### Added

- `tests/repo_structure.ml` — new `portable-linux-musl` test
  group with four cases (matrix entry, no Unix.fork in kernel,
  USAGE + adoption mention musl, decision in active or retired).
  The decision-in-state test accepts both `active` (in-flight)
  and `retired` (after reversal) — never `draft` on main.
- §11.22 — `ldd` reveals `_build/install/default/bin/mathc`
  is not portable when built under `nix develop .#test`. CI is
  the only honest portability check; local builds via nix-store
  glibc are a red herring.
- CI fixes (parallel to commit 4b623c2 in site.yml):
  - `ci.yml`: disable `cachix/cachix-action@v15` step
    (`fail-on-cache-miss` is no longer a valid input).
  - `release.yml`: hardened PATH search, switch-name trial, and
    default-switch use for the Alpine container; reverted in
    the same change set after 4 CI attempts.

### Reverted

- `feat(portable-linux-musl): mathc-linux-x86_64-musl` —
  attempted via Alpine container build in `release.yml`. The
  matrix entry is commented out (rev 2 of the decision).
  Reasons CI runs #81/#83/#84/#85 all failed at the
  'Init opam (Alpine musl container)' step:
  - #81 (alpine-3.20-ocaml-5.4): exit 127 (opam not on PATH).
  - #83 (alpine-3.24-ocaml-5.4): exit 1 (opam env --switch=5.4.0
    failed because the image uses an opaque default switch name).
  - #84 (multi-switch trial): exit 1 (no trial matched).
  - #85 (opam env without --switch): exit 1 (opam env itself
    returned non-zero under root in container).
  Per the `alpine-ci-build-fails` reversal signal in
  `decisions/portable-linux-musl.yaml`, the matrix entry is
  commented out. glibc pipeline unchanged.

### CI infrastructure (not portable-musl)

- `CI` workflow has been failing on every commit since
  `cee8179d` (pre-existing): scripts/dev verify returns exit 1
  on the cachix-runner. Fix in this release at `f016a4d`
  (cachix step disabled).

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

### Implemented in this batch (between ff9e738 and fd7ea8b)

All 13 Tier 3.5 tasks are landed on `main`:

- `feat(schema): extend for 3.2-ideal algebra` —
  `schemas/decision.json` adds `state`, `mode_floor_used`,
  `body_sha`, `yaml_sha`, `axiom_link`, and an 8-kind
  `relation_kind` enum on `relations`. `attestation.json`
  adds `substrate_digest`, `environment_class_level`,
  `environment_class_label`, `ci_run_id`,
  `substrate_fingerprint`. `obligation.json` adds `phase`
  and `obligation_domain`. New file `schemas/policy.json`
  declares the per-path policy record.
- `feat(domain-ml): extend types for 3.2-ideal algebra` —
  new polymorphic variants `epistemic_marker` (5 levels:
  `fact | hypothesis | judgment | unknown | proven`,
  restored from v0.854), `phase` (3 levels),
  `mode` (5 levels), `environment_class_label` (5 levels);
  new fields on `decision`, `assumption`, `obligation`,
  `attestation`.
- `feat(risk): implement algebra §2 risk function` — new
  module `lib/risk.ml` (`classify`, `impact`, `probability`,
  `irreversibility`, `mode_floor`, `risk`, `mode`).
- `feat(decision-ml): sha-match + epistemic + 8 relations` —
  `Decision.sha_match_check`, `Decision.parse_relations`,
  `axiom_link` extraction.
- `feat(policy-ml): multi-policy union + transitive` —
  new module `lib/policy.ml` with `policy_of`, `policies_of`,
  `compose`, `data_flow_targets`, `mode_floor_of`.
- `feat(rebuttal-ml): hybrid rebuttal mechanism` —
  new module `lib/rebuttal.ml` (sibling artifact + forge
  mirror + trust binding).
- `feat(re-evaluation-ml): re_evaluate oracle` — new module
  `lib/re_evaluation.ml` with `re_evaluate` returning
  `Compatible | Inconclusive | StaleClaim`.
- `feat(attestations-ml): substrate + multi-CI` —
  `compute_substrate_digest`, `parse_environment_class_level`,
  `aggregate_obligation`, `current_at`, `decisive_for`.
- `feat(gate-ml): apply() + phase-aware gates` —
  `kernel_rule`, `apply_rule`, `gate_v32`,
  `gate_release_v32`, `post_release_monitor`.
- `feat(migration): state + body_sha + yaml_sha on 28
  decisions` — `scripts/migrate-decisions-3.2.py` with
  text-based editing to preserve comments.
- `feat(cram): 3.2-ideal fixtures` — 3 new cram files:
  `schema-extensions-3.2.t`, `migration-3.2-fields.t`,
  `applicability-envelope.t`.
- `attestations: generate batch for algebra-3.2` — 7 new
  attestations covering `spec-file-exists`,
  `cross-references-correct`, `applicability-documented`,
  `kernel-conformance-baseline`, `adoption-path-documented`,
  `backward-compat-test`, `implementation-roadmap`. With
  these, `mathc self-check` verdict flips from `unknown` to
  `pass` (28/28 subjects green).

### Remaining for v3.1.0 stabilisation

- Cram snapshot regeneration: closed at HEAD `4ef31f7` (sync
  refresh 2026-10-04). `tests/cli/self-check-pass.t:17` and
  `tests/cli/self-check-unknown.t:16` already read `28`
  (`subjects_len:28`, `total_subjects:28`, `pass_count:28`,
  `unknown_count:28`); the "snapshots say 23" claim was stale
  and did not match the tree.
- `feat(portable-binary): static-link or musl build` —
  fixes §30 anti-property (nix-store glibc in shipped
  binary); tracked separately.

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

- `mathc packages [--format=text|json|html]` — single-pane view of
  every decision-obligation-verdict pair in the repository.
- `mathc render [--out DIR]` — static site generator; writes `dist/`
  with `index.html`, `axioms.html`, `methodology.html`,
  `bootstrap-gate.html`, `packages.html`, per-decision pages,
  per-axiom pages, and a JSON search index.
- `.github/workflows/site.yml` — nix-based GitHub Pages deploy on
  every push to main. Pinned to `ubuntu-22.04` (matches `ci.yml`;
  setup-ocaml/v2 needs darcs, unavailable on 24.04).
- `scripts/render.sh` — local site-build pipeline: builds mathc,
  runs `mathc render`, copies assets, verifies the output allowlist,
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
  every page that documents a feature references `mathc packages`).
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

- `mathc explain` dispatcher was a broken promise in
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
  `mathc packages`, `mathc render`, `site-deploy`.
- `PACKAGES.md` — D1, D2, D4, D6, D10 marked closed; new
  decisions registered.
- `spec/semantics.md` — added `mathc packages` and `mathc render`
  subcommand rows.
- `bin/Mathc.ml` — added `do_packages` and `do_render`; the
  `--out` long-flag is now accepted for `mathc render`.
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
m3/mathc-explain
m3/mathc-self-check
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
chain: closes D1, D2, D4. Ships `mathc explain`, `mathc self-check`
dispatcher, attestation store (75 files populated), `mathc gate`
real verdict against the store. CI step `mathc self-check` becomes
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