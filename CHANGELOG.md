# math-coding CHANGELOG

> Single-source-of-truth for releases. Mirrors the `v3.x.y` git
> tags. The current release is highlighted.

## v3.3.3 — 2026-10-18 — current

Release-prep + F11/F12 cleanup + Batch B + Batch C + MCP
pipe-deadlock fix. Closes the 9 recommendations from
`docs/plans/plan-2026-11-validation-cleanup-2026-10.yaml`
(16 body_sha format fixes + axiom_link for audit-cleanup-2026-10
+ 2 malformed-acceptance fixes), 14 from
`plan-2026-12-validation-followup-2026-10.yaml` (8 counterexample
soft-warns + 6 hard-rejects restructure with parser
byte-counting edge case work-around), 3 sub-decisions from
`plan-2026-11-adoption-fixes-2026-10.yaml` Batch B (B1
import-junit-rename, B2 scripts-env-var-audit, B3
attestation-namespace-meta), 6 from Batch C (C1+C2 process-principles
P8.5/P9, C3 attest-handshake-rescue, C4 release-cadence +
release-pending CI gate + MC_VERSION_DEFAULT="3.3.3" + AGENTS.md note,
C5 verifier-scheme-convention, C6 experiment-doctor-instrumentation),
plus fix-mcp-pipe-deadlock-2026-10 (the F15 lesson: select-based
drain in lib/mcp/dispatch.ml::run_with_args to end the 64 KiB
pipe-buffer deadlock). Self-check 191/0/pass; 0 rejects; dune
build green; fmt clean; sync-version drift clean.
Pre-existing baseline failures (not introduced by this cycle,
to be addressed in plan-2026-12-test-hardening):
portable-linux-musl (Unix.fork in bin/Mathc.ml from B1
verify-sandbox violates fork-not-used), process_principles P2 +
fixture_coverage (123 shell-command verifiers unrecognized),
render_kernel bilingual_drift/dashboard (site not rendered
in test-env), adopt_test madr_files/adrtools_files (adopt
detection bug).

## v3.3.2 — 2026-10-17

Adoption-fixes release. Closes the 9 recommendations from
`docs/experiments/adoption-2026-10.md` §13 (the 2026-10-17
brownfield experiment on 5 external projects) plus the
audit-cleanup work from `docs/plans/audit-cleanup-2026-10.md`.
Combined under one tag because the audit-cleanup work landed
in `main` between v3.3.1 and the experiment results, and the
adoption-fixes work was authored as a single 10-sub-decision
plan (`decisions/plan-2026-10-adoption-fixes-2026-10.yaml`).

3 of the 10 adoption sub-decisions (A1, A3, C3) duplicate work
already shipped in v3.3.1 or in `main` between v3.3.1 and this
release; the corresponding decision files remain in the tree
as historical records of the experimental finding.

### Added (from plan-2026-10-adoption-fixes)

- **`mathc verify FILE`** subcommand (`bin/Mathc.ml::do_verify`):
  walks `acceptance.all[*].verifier` strings in a decision
  YAML and executes them in a sandbox (subprocess,
  env-stripped to `PATH`/`HOME`/`LANG`, 60s timeout, cwd =
  decision's repo root). Returns per-obligation
  `pass | fail | skipped`. The verdict distinguishes
  *validated* (parse-ok) from *verified* (per-obligation
  verifier execution result). Decision:
  `add-verify-subcommand-2026-10`.
- **`mathc attest-batch`** is now in the `dispatch` table with
  help text (was already implemented in v3.3.1 but not
  dispatched). The subcommand is the canonical bulk-attest
  path; the `kind_: test` and `kind_: review` producers are
  both supported. Cram fixture `tests/cli/attest-batch.t` is
  the acceptance crate. Decision: `ship-attest-batch-2026-10`.
- **`MATH_CODING_DECISIONS_DIR` / `MATH_CODING_ATTESTATIONS_DIR`
  env-var honor** across all tree-walking subcommands
  (`self-check`, `packages`, `find`, `counters`, `migrate`,
  `re-evaluate`, `new-decision --write`). The v3.4 resolver
  (`lib/path_config.ml`) existed in v3.3.1; this commit
  wires every subcommand through it. Brownfield projects can
  now keep math-coding artifacts out of their top-level
  `decisions/` and `attestations/` directories. Decision:
  `fix-env-var-resolver-2026-10`.
- **YAML 1.2 inline-sequence parser** (`lib/codec.ml`): the
  custom parser now correctly handles `key: - foo` followed by
  same-indent `- bar` continuations without consuming the
  next top-level key. Fixes a parser-induced false positive
  on `MC-COUNTEREXAMPLE-MISSING` for any decision with a
  multi-line `risk.declared_triggers` list followed by a
  `counterexample:` block. Decision: `fix-yaml-parser-2026-10`.
- **`mathc new-decision` axiom-link soft-warn** (`lib/new_decision`,
  `lib/diagnostic.ml`): when a freshly scaffolded decision
  lacks `axiom_link`, the new-decision command emits
  `deficit/MC-AXIOM-LINK-INFERENCE-EMPTY` naming the top-3
  candidate axioms based on `scope.paths`. Inference is
  suggest-only — the field is never auto-filled. Mapping:
  `lib/**→A0,A1`, `tests/**→A1`, `decisions/**→A0,A4`,
  `spec/**→A0,A3`, fallback `A0`. Decision:
  `axiom-link-inference-2026-10`.
- **`scripts/generate-attestations.py` env-var support**:
  the Python attest-batch helper now honours
  `MATH_CODING_DECISIONS_DIR` and
  `MATH_CODING_ATTESTATIONS_DIR` (matching the OCaml binary's
  resolver). Adds `--help`. Decision:
  `fix-generate-attestations-env-2026-10`.

### Changed

- **`mathc validate` verdict renamed**: `verdict: accept` →
  `verdict: parse-ok` (text and JSON). The rename removes the
  semantic load that previously conflated shape-correctness
  with verification. 14 cram fixtures under `tests/cli/`
  updated to assert on the new verdict string. A grep for
  `"verdict":"accept"` across `tests/cli/` returns zero hits.
  Backwards-compatibility note: downstream scripts that
  greppped for `accept` must update to `parse-ok`. Decision:
  `add-verify-subcommand-2026-10`.
- **`MC-COUNTEREXAMPLE-MISSING` diagnostic docstring tightened**
  (`lib/diagnostic.ml`): the diagnostic now names
  `fix-yaml-parser-2026-10` (commit `3f14b76`) and
  `tests/cli/yaml-parser.t` as regression pins, and
  `tests/cli/counterexample-warn.t` as the new acceptance
  crate. The diagnostic emission itself is unchanged — it
  still fires when `counterexample:` is genuinely absent;
  the parser fix (A2) ensures it does not fire on a
  present-but-parser-ignored field. Decision:
  `tighten-counterexample-warn-2026-10`.
- **Friction-event taxonomy in `docs/experiments/adoption-2026-10.md` §7**
  collapsed from 8 overlapping categories to 4 mutually
  exclusive: F-INSTALL, F-SCHEMA, F-WORKFLOW, F-SEMANTIC. All
  55 events in the 5 per-project reports re-classified;
  counts still sum to 55. Decision: `revise-friction-taxonomy-2026-10`.

### Test surface

- `tests/cli/verify.t` (new) — `mathc verify` smoke + the
  parse-ok verdict rename
- `tests/cli/env-var-resolver.t` (new) — env-var honor for
  every tree-walking subcommand
- `tests/cli/yaml-parser.t` (new) — YAML 1.2 inline-seq cases
- `tests/cli/counterexample-warn.t` (new) — tightened
  diagnostic
- `tests/cli/attest-batch.t` (new) — `attest-batch` smoke
- `tests/cli/new-decision-axiom-warn.t` (new) — axiom-link
  inference soft-warn
- `tests/scripts/generate-attestations-env.t` (new) —
  Python script env-var honor
- 14 existing cram fixtures updated to assert on
  `verdict: parse-ok`

### Documentation

- `docs/experiments/adoption-2026-10.md` §7, §10.4, §10.5,
  §11.2, §13 re-classified under the new 4-category taxonomy
- `docs/experiments/brownfield-experiment-v2-2026-10.md`
  (new) — design for the v2 brownfield experiment on
  projects that ship ADRs in-tree (5 verified candidates:
  `adr/madr`, `JabRef/jabref`, `theupdateframework/tuf`,
  `home-assistant/architecture`,
  `kubernetes-sigs/cluster-api-provider-aws`)

### Audit-cleanup (from main between v3.3.1 and v3.3.2)

Eight low-hanging audit deficits closed under
`docs/plans/audit-cleanup-2026-10.md`. Highlights: three
telemetry-marker `tracked:` acknowledgements on the same
line as their `ack`; docstring drift on `USAGE.md`,
`QUICKSTART.md`, `adoption/SKILL.md`; `MARKDOWN-LINT` tightened
for the 8 decisions with risk_blocks. Decision:
`audit-cleanup-2026-10`.

## v3.3.1 — 2026-10-16

Patch release. Five streams landed behind the v3.4 workstream and
ship under a minor tag bump rather than a feature bump because the
additive surface area is small relative to the existing 3.3
contract.

### Added

- **`mathc attest-batch`** subcommand (`bin/Mathc.ml`,
  `lib/attestations/batch.ml`): generates attestation JSONs from
  a TSV manifest (`--manifest=PATH`) or by walking
  `MATH_CODING_DECISIONS_DIR` (`--from=decisions`). `--dry-run`
  prints JSON to stdout; `--out=DIR` overrides the output path.
  Port of `scripts/generate-attestations.py` to OCaml; the SHA-256
  computation matches the Python implementation byte-for-byte.
  Decision: `ux-3-attest-batch-subcommand-2026-10`.
- **New env-vars** for kernel path resolution (`lib/path_config.ml`):
  - `MATH_CODING_DECISIONS_DIR` (default `.math-coding/decisions`)
  - `MATH_CODING_ATTESTATIONS_DIR` (default `.math-coding/attestations`)
  - `MATH_CODING_POLICY` (default `.math-coding/policy.yaml`)
  - `MATH_CODING_HOME` (default `$XDG_DATA_HOME/math-coding/<version>`;
    v3.5 work)

### Changed

- **`mathc init` default layout**: now creates `.math-coding/`
  instead of `decisions/` + `attestations/`. Brownfield projects
  with the legacy layout continue to work via the resolver's
  fallback chain. Decision: `ux-3-minimal-pollution-2026-10`.
- **Embedded schemas and templates** in the OCaml binary
  (`lib/schema_embedded.ml`, `lib/templates_embedded.ml`):
  `schemas/*.json`, `templates/ci.yml`, `templates/README.md`
  are now `{|...|}` string constants. Brownfield projects no
  longer need to copy `schemas/` into the working tree.
- **Master policy template** (`lib/init/init.ml`): scaffolded
  `decisions/decision.yaml` (now `.math-coding/policy.yaml`) now
  carries `axiom_link: [A0, A3]` and a `counterexample:` block,
  so it validates with `mathc validate` immediately after init.

### Fixed

- **`MC-MISSING-INTENT` false positive**: when a decision lacks
  `counterexample:` and `mode >= standard`, the kernel now
  surfaces `MC-COUNTEREXAMPLE-MISSING` (Block) instead of the
  misleading `MC-MISSING-INTENT`. `MC-MISSING-INTENT` is now
  reserved for the genuine case where the `intent:` field is
  absent.
- **`body_sha` / `yaml_sha` pattern enforcement**:
  `MC-BODY-SHA-PATTERN-VIOLATION` (Block) is now emitted when
  either field is present and does not match
  `^sha256:[0-9a-f]{64}$`. Previously only equality between the
  two fields was checked.
- **`materials_digest` semantics**: attestations with
  `kind_ ∈ {test, build, observation}` and `materials_digest: ""`
  are now rejected with `MC-MATERIALS-DIGEST-EMPTY` (Block).
  `kind_: review` remains exempt.
- **Verifier extraction in `mathc packages --format=json`**:
  the `verifier` field of each obligation is now read from the
  decision YAML via `Memory.decision_entry.verifier_per_obligation`
  and reflects the actual verification target (e.g.
  `pytest tests/test_api.py -q`), not the obligation id.
- **Decision: `kernel-bugs-v3.4-2026-10`** records the full
  A3-protected closure of the 6 kernel bugs fixed in this
  release.

### Test surface

- 7 new hermetic cram fixtures
  (`tests/cli/{init-defaults,init-legacy,path-config-fallback,
  embedded-schemas,counterexample-required,body-sha-pattern,
  packages-verifier-real}.t`)
- 4 attest-batch cram fixtures (positive, malformed, dry-run,
  from-decisions) — moved to hermetic env-var control
- `tests/process_principles.ml::axiom_link-default-validates`
  regression pin for the master-template fix
- Cram count: 81 → 88

## v3.3.0 — 2026-10-15

**Brand:** math-coding 3.3. **VERSION file** + `math-coding.opam`
bumped from `3.1.0-alpha-final` to `3.3.0-alpha` (semver `3.3.0`).
Header of ROADMAP, PACKAGES, README, AGENTS, USAGE, OCAML_BEST_PRACTICES,
axioms/index.md, and `bin/data/time-distribution.yaml` all renamed to
`3.3`. `mathc version` now prints `math-coding 3.3.0-alpha: bootstrap`.
This is the published brand for the algebra-3.2-ideal kernel
(`spec/algebra-3.2.md`); the spec filename is preserved (it is the
version of the *spec*, not the project).

**Continuing on from v3.2.0-alpha (which was not separately
released):** §30 closure recovered on 2026-10-07. CI run #129
on branch `fix-alpine-musl-2026-10` is the first end-to-end
green Alpine/musl build; `mathc-linux-x86_64-musl` is a 4.99 MB
musl-linked ELF (`/lib/ld-musl-x86_64.so.1`, NEEDED
`libc.musl-x86_64.so.1`). `decisions/portable-linux-musl.yaml`
now at rev 4 / state: active. The musl artifact is uploaded
to GitHub Actions artifacts but is not yet in the published
release `files:` list — that wiring lands with the merge to
main. See ROADMAP §"Remaining for v3.1.0 stabilisation" and
OCAML_BEST_PRACTICES §11.26.

**Status (2026-10-12):** Phase 1 of the install-tooling-2026-10
work landed on `add/deferral-records-phase-2-3-2026-10`. The
release now ships `install.sh`, `SHA256SUMS`, and `install.sh`
as release assets; `ghcr.io/11111000000/mathc:<VERSION>` is
built by `.github/workflows/docker.yml`; `flake.nix` exposes
`apps.default` for `nix run`; `scripts/sync-version.sh`
keeps the install script and the skill in sync with `VERSION`.
Three impl-pending decisions (mcp-server, docker-alpine,
auto-update-per-user-skill) record Phase 2/3 deferrals with
machine-readable reversal signals.

### Added

- `decisions/migration-mechanism-2026-10.yaml` (rev 1) —
  declarative, kernel-observed migration mechanism. New
  `mathc migrate --from=X --to=Y [--root=DIR]
  [--format=text|json] [--explain] [--manifest=PATH]`
  subcommand backed by pure `lib/migrate.ml`. The kernel
  never mutates decision files; it reads a migration manifest
  under `decisions/migrations/<from>-to-<to>.yaml` and prints
  a per-file plan listing the auto-translatable transforms
  (rename-field, add-field, bump-schema-string) plus any
  manual-review items. First manifest shipped:
  `decisions/migrations/3.2-to-3.2.1.yaml` (empty list, a
  no-op proof of the mechanism against the future schema-string
  bump). Cram fixtures: `tests/cli/migrate-{dry-run,
  no-changes,malformed}.t` plus the synthetic tree at
  `tests/cli/fixtures/migrate/`. Removes
  `scripts/migrate-decisions-3.2.py` and
  `scripts/migrate-decisions-3.2-phase2.py`; their git history
  at `a215ef9` / `e21fdf0` is the audit trail.
- `decisions/schema-string-bump-3.0-alpha-to-3.2-2026-10.yaml`
  (rev 1) — A3-protected transition that bumps the
  `schema:` field on every live decision from
  `math-coding/3.0-alpha` to `math-coding/3.2` (matches the
  field set `spec/algebra-3.2.md` already formalises). 72
  decision YAML files bulk-bumped; 6 of those were missing
  `body_sha`/`yaml_sha` because they predate the v3.0.0.19
  schema tightening, and now carry freshly-computed values
  per algebra §7. `schemas/decision.json`'s `schema` enum
  now accepts both forms for one cycle (soft-deprecated
  `3.0-alpha` form is read-accepted so archived decisions
  still validate; a future `archive-3.0-alpha-form`
  decision will move them to `decisions/legacy/`). First
  non-trivial migration cycle of `lib/migrate.ml` is
  `decisions/migrations/3.0-alpha-to-3.2.yaml` (a single
  `bump-schema-string` action); fixture
  `tests/cli/migrate-bump-replay.t` exercises the replay
  against a synthetic legacy tree and asserts a no-op
  plan against the live post-bump tree.
- `decisions/migration-mechanism-2026-10.yaml` (rev 2) —
  adds `mathc migrate --write [--dry-run]`. `--write`
  applies auto-translatable actions to a sibling
  `<file>.migrated.yaml` next to each input (the original
  is NEVER overwritten); `--dry-run` paired with `--write`
  prints the per-file JSON summary without touching the
  disk. Implementation lives in
  `lib/migrate.ml::apply_actions` and `bin/Mathc.ml`'s
  ~30 LOC addition. Fixture `tests/cli/migrate-write.t`
  covers both the apply path and the dry-run property.
  `process_principles.ml::P2` whitelist extended with
  `json-schema-` and `Diagnostic.` prefixes to accept
  verifier strings agents naturally write (e.g.,
  `json-schema-validation passes`,
  `Diagnostic.explain "MC-POLICY-CYCLE" = Some _body`)
  without rejecting them as malformed.
- `decisions/install-tooling-2026-10.yaml` — A3-protected
  meta-decision that introduces the four install channels
  (release binary / docker image / nix run / source build)
  and the per-user skill pipeline. 10 obligations; 3
  assumptions; 11 outcomes.
- `scripts/install-tooling/install.sh` — POSIX-sh installer
  (~300 lines) with `--user-skill`, `--upgrade`,
  `--with-docker`, `--print-nix-command`, `--version=<X>`,
  `--check`, `--help`; exits 0/1/2/124 per the documented
  contract.
- `scripts/install-tooling/templates/active-policy.yaml` —
  bootstrap policy that new projects copy into their
  `decisions/decision.yaml`; passes `mathc validate`.
- `Dockerfile.debian-slim` — multi-stage build (nix build →
  debian:bookworm-slim runtime); ENTRYPOINT `["mathc"]`;
  ~80 MB.
- `.github/workflows/docker.yml` — publishes
  `ghcr.io/11111000000/mathc:<VERSION>` on every push to
  main, every tag, and on workflow_dispatch. Respects
  `OCAML_BEST_PRACTICES` §11.26 (job-level `container:`).
- `flake.nix` — `apps.<system>.default` enables `nix run
  github:11111000000/math-coding -- <args>`.
- `decisions/version-sync-2026-10.yaml` — `VERSION` is the
  single source of truth; `scripts/sync-version.sh
  --check|--write` keeps `adoption/SKILL.md` and
  `scripts/install-tooling/install.sh` derived version
  strings in sync with `VERSION`. Closes the follow-up
  announced at `site-version-from-file-2026-10.yaml:76-81`.
- `decisions/mcp-server-impl-pending.yaml`,
  `decisions/docker-alpine-impl-pending.yaml`,
  `decisions/auto-update-per-user-skill-impl-pending.yaml`
  — three Phase 2/3 deferral records with machine-readable
  reversal signals and `state: active`. The MCP server
  (Phase 2), the Alpine Docker image (Phase 3, blocked on
  musl release asset), and per-user skill auto-update
  (Phase 3+, blocked on agent-platform version-pinning
  protocol) are sequenced after `install-tooling-2026-10`
  lands.
- `site/install.md` (en+ru) — long-form install guide:
  four-channel decision tree, per-repo vs per-user skill
  paths, version-pin contract, NixOS/glibc trap notes.
  Rendered to `dist/install.html` and `.ru.html`; verified
  by the `scripts/render.sh` allowlist.
- `OCAML_BEST_PRACTICES.md` §11.27 (`VERSION drift between
  skill and binary`), §11.28 (`curl | sh install script
  needs -fSL`), §11.29 (`Dockerfile COPY cannot reach
  outside the build context`).
- `tests/fixtures/impl-pending-files-present.sh` —
  positive + negative (file-missing, state-retired) fixture
  for the three Phase 2/3 deferral records.
- `tests/fixtures/sync-version-clean-passes.sh` /
  `sync-version-stale-fails.sh` — fixtures for the
  `version-sync-2026-10` obligations; both reentrant.
- `tests/cli/install.t` — cram fixture covering install.sh
  `--help`, `--with-docker`, `--print-nix-command`,
  `--check`, `--bogus-flag`, `--user-skill --upgrade`.

### Changed

- `USAGE.md` §"Install" — replaced "Two ways to get mathc"
  with the four-channel table; added concrete shell
  snippets and a pointer to `site/install.md`.
- `.github/workflows/release.yml` — adds `SHA256SUMS` and
  `install.sh` to the `files:` list (existing
  `dist-adoption.tar.gz` already present).
- `bin/Mathc.ml` — `articles` list (the `mathc render`
  page registry) gains `install.md` between
  `bootstrap-gate.md` and `packages.md`.
- `scripts/render.sh` — allowlist gains `dist/install.html`.
- `OCAML_BEST_PRACTICES.md` trap-log grows to 30 entries.

### Verification

`mathc self-check`: 62 pass / 1 unknown
(`audit-0.0.21-fixes` pre-existing waiver). No new
unknowns introduced by this batch.

- `tests/repo_structure.ml` — new `portable-linux-musl` test
  group with four cases (matrix entry, no Unix.fork in kernel,
  USAGE + adoption mention musl, decision in active or retired).
  The decision-in-state test accepts both `active` (in-flight)
  and `retired` (after reversal) — never `draft` on main.
- §11.22 — `ldd` reveals `_build/install/default/bin/mathc`
  is not portable when built under `nix develop .#test`. CI is
  the only honest portability check; local builds via nix-store
  glibc are a red herring.
- §11.26 — `container:` under `strategy.matrix.include` is
  silently ignored by GitHub Actions (only honored at the
  job level). Trap added after 7 CI attempts (#81, #83, #84,
  #85, #125, #126, #127, #128) on the alpine-musl pipeline
  hit `command not found` / `No such file or directory` on the
  Ubuntu host instead of inside alpine. The fix: explicit
  `docker run alpine:3.20 …` from the runner.
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

### Onboarding fixes (this branch)

#### P0 (closes first-touch 404)
* `install-tooling-default-tag-edge` (commit `65c2270`): `MC_VERSION_DEFAULT="edge"` so the
  single-line install URL resolves to a published release.
* `install.sh --user-skill` tarball path (commit `9d6dc64`): `tar -xzOf dist-adoption.tar.gz`
  now extracts `adoption/opencode/SKILL.md` (not `dist/adoption/.../SKILL.md`).
* `release.yml` drop 404 rawgithub URL (commit `70b0719`): prerelease body now points at
  `/releases/download/edge/install.sh`.

#### P1 (UX hardening)
* `print_usage` (commit `2ac9b41`): `mathc --help` now names `adopt`, `migrate`, `telemetry`.
* `adoption/SKILL.md` sync (commit `d6acff8`): Step 1 uses `curl | sh --user-skill`,
  rev-bumps `ux-3-adoption-doc-freshen-2026-10` from @1 to @2.
* `mathc new-decision` (commit `465ec3c`): new subcommand scaffolds `decisions/<id>.yaml`.
* `init-release-binary-noop-skill` (commit `63dd8df`): documents the release-binary vs
  in-source-build split for `--agent opencode`.
* `MCP integration docs` (commit `87a2dde`): `adoption/SKILL.md` §"MCP integration"
  describes the JSON-RPC stdio protocol and 11 method names.
* `templates/ci.yml` (commit `1b70fb2`): blocking-CI workflow for adopter repos.

#### Meta cleanup
* `mcp-server-impl-pending` retired (commit `5260bd9`): `state: active` → `state: retired`;
  MCP server already landed via `mcp-server-impl-2026-10@1` + `ux-3-mcp-read-write-2026-10@1`.

#### Deferred (design recorded only; OCaml impl needs dune)
* `update-check-notify` (commit `57481bf`): opt-in version notification design.
* `init-copies-ci-workflow` (commit `ec9464e`): `mathc init` auto-wire templates/ci.yml.

## v3.1.0-alpha — 2026-09-30

**Status:** algebra 3.2-ideal adopted as forward-looking formal
spec. The runtime kernel is unchanged (still v3.0.0.20); the
algebra is a normative supplement that future kernel releases
will implement.

### Added

- `spec/algebra-3.2.md` — formal mathematical specification
  (31 sections, §0–§30) of the 3.2-ideal kernel. Normative alongside
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
