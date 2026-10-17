# Math-coding 3.3 — ROADMAP

> **Status (2026-10-14, post version-bump):** bootstrap protocol **expired**
> (commit `8fa7fcf`). The 3.3 kernel checks this repository and its
> conformance corpus via `mathc self-check`, which is a **blocking** CI
> step per `constitution.md` Invariant 14. The attestation store at
> `attestations/` is populated (591 files committed after the 2026-10-14
> parallel-fix-batch added 118 review-class attestations and the
> deep-audit-fix commit removed 53 duplicates from H's batch). CLI
> surface: `validate`,
> `context`, `explain`, `explain-diagnostic`, `assess`, `attest`,
> `attest-batch`, `gate`,
> `session-start`, `record`, `stats`, `time-estimate`, `self-check`,
> `version`, `render`, `packages`, `mode`, `rebuttals`, `re-evaluate`,
> `re-evaluate-decisions`, `migrate`, `counters`, `init`, `import-adr`,
> `adopt`, `new-decision`, `telemetry`, `doctor`, `forge-verify`, `find`,
> `precommit`, `graph`, `decision-state`, `update` — 34 subcommands.
>
> **Algebra 3.2-ideal**: accepted via `decisions/algebra-3.2.yaml`;
> normative spec at `spec/algebra-3.2.md` (31 sections, §0–§30). Implementation
> tracked in Tier 3.5 below.
>
> **Author:** Petr Kosov &lt;p.b.kosov@yandex.ru&gt;
> **License:** Apache-2.0 (see `LICENSE`, `NOTICE`)
> **Active policy:** `bootstrap-v3@3` (see `decisions/decision.yaml`)

This document is the **single source of truth** for what math-coding 3.3
is doing, what it is not yet doing, and in what order the remaining
work should land. It supersedes ad-hoc "critical analysis" reports and
inline AGENTS.md priority lists; AGENTS.md defers to this file.

## Working chain (recap)

```text
intent -> decision -> obligation -> change -> attestation -> revision
```

Every commit on `main` must close at least one obligation. No obligation
closes without a positive + negative fixture. No kernel change ships
without a `decisions/*.yaml` decision under the active policy.

## Priority queue (highest leverage first)

### Tier 0 — bootstrap: closed

| # | Task | Decision | Status |
|---|---|---|---|
| ~~1~~ | `gate-attestation-store-fill` | `gate-attestation-store-fill@1` | **closed** in commit `ed42290` |
| ~~2~~ | `mathc self-check` | `mathc-self-check-subcommand@2` | **closed** in commit `758f340`; blocking CI in `8fa7fcf` |
| ~~A~~ | `mathc explain` dispatcher | `mathc-explain-subcommand@1` | **closed** in commit `6e922d3` (broken promise from `omitted[].expansion` resolved) |
| ~~B~~ | D1/D2 (YAML block-scalars + front-matter) | `yaml-block-scalars@3` | **closed** in commit `79d138b` (v3.0.0.19) |
| ~~C~~ | D4 (SHA-256 RFC vectors) | `kernel-conformance-runner@1` | **closed** in commit `d77624b` |

### Tier 1 — process hardening: closed

| # | Task | Decision | Status |
|---|---|---|---|
| ~~1~~ | `scripts/dev close-branches` | `process-principles-close-branches@3` | **closed** at v3.0.0.20 — D10 stale-worktree accumulation |
| ~~2~~ | Decision-fixture co-commit pre-commit hook | `process-principles-close-branches@3` | **closed** at v3.0.0.20 — `.githooks/pre-commit` enforces P1 + P2 at commit time |
| ~~3~~ | Site deploy (`.github/workflows/site.yml`) | `site-deploy@5` | **closed** at v3.0.0.20 |
| ~~4~~ | `mathc packages` subcommand | `mathc-packages-subcommand@3` | **closed** at v3.0.0.20 |
| ~~5~~ | `mathc render` (site generator) | `site-deploy@5` | **closed** at v3.0.0.20 |
| ~~6~~ | `scripts/sync-version.sh` (Phase 1 install-tooling W1) | `version-sync-2026-10@1` | **closed** in commit `bf96bc1` |
| ~~7~~ | `scripts/install-tooling/install.sh` (Phase 1 install-tooling W2) | `install-tooling-2026-10@1` | **closed** in commit `60f5edf` |

### Tier 1.5 — install-tooling follow-up (Phase 2/3)

Three Phase-2/3 deferral records live in `decisions/` with
`state: active` and `reversal.signal:` blocks. They do not
block further work; they record that the implementation is
sequenced after the install-tooling-2026-10 surface lands.

| # | Deferral | Phase | Reversal signal | Decision |
|---|---|---|---|---|
| 1 | MCP server (`lib/mcp/` + `bin/mathc_mcp.ml`) | Phase 2 | `mcp-server-impl-pending-resolved` | `mcp-server-impl-pending@1` |
| 2 | `Dockerfile.alpine` (depends on `mathc-linux-x86_64-musl` as release asset) | Phase 3 | `docker-alpine-impl-pending-resolved` | `docker-alpine-impl-pending@1` |
| 3 | Auto-update per-user skill (silent mutation prevention) | Phase 3+ | `auto-update-per-user-skill-impl-pending-resolved` | `auto-update-per-user-skill-impl-pending@1` |

### Tier 2 — close specific audit deficits

| # | Deficit | Status | Notes |
|---|---|---|---|
| 6 | D6 (bootstrap-v3 manual-only verifiers) | **closed** in v3.0.0.20 | `mathc self-check` is blocking; manual-only verifiers move to machine-checked |
| 7 | D5 (stale `bin/mathc_main.ml`) | **closed** in commit `191d1af` | |
| 8 | D7 (adapters decision covers two obligations) | **closed** in commit `be5c4bd` | |
| 9 | D3 (priority-drift detector) | **closed** in commit `4855a57` | |
| 10 | D4 (spec-cli-catalog) | **closed** in commit `2c2a032` | |
| 11 | D8 (`mathc validate` coarse diagnostics) | open | tracked for 3.0-beta |

### Tier 2.5 — onboarding-fixes-2026-10 (closed in this branch)

| # | Task | Decision | Status |
|---|---|---|---|
| 1 | install-tooling default tag edge | `install-tooling-default-tag-edge-2026-10` | closed in commit `65c2270` |
| 2 | install.sh --user-skill tarball path sync | `install-tooling-2026-10@1` (rev) | closed in commit `9d6dc64` |
| 3 | release.yml drop 404 rawgithub URL | `install-tooling-2026-10@1` | closed in commit `70b0719` |
| 4 | print_usage adopt/migrate/telemetry | `print-usage-complete-2026-10` | closed in commit `2ac9b41` |
| 5 | adoption/SKILL.md sync to install.sh --user-skill | `ux-3-adoption-doc-freshen-2026-10@2` (rev) | closed in commit `d6acff8` |
| 6 | mathc new-decision <id> subcommand | `ux-3-new-decision-subcommand-2026-10` | closed in commit `465ec3c` |
| 7 | templates/ci.yml blocking-CI workflow | `install-tooling-2026-10` | closed in commit `1b70fb2` |
| 8 | mcp-server-impl-pending retired | `mcp-server-impl-pending@2` (rev) | closed in commit `5260bd9` |
| 9 | MCP integration docs in adoption/SKILL.md | `mcp-agent-auto-connect-2026-10` | closed in commit `87a2dde` |
| 10 | init-release-binary-noop-skill documentation | `ux-3-init-release-binary-noop-skill-2026-10` | closed in commit `63dd8df` |

### Tier 2.6 — design recorded, OCaml impl deferred (this branch)

| # | Task | Decision | Status |
|---|---|---|---|
| 1 | mathc update-check / auto-update per-user skill | `update-check-notify-2026-10` | design recorded (deferred; OCaml impl needs dune) |
| 2 | mathc init auto-wire templates/ci.yml | `ux-3-init-copies-ci-workflow-2026-10` | design recorded (deferred; OCaml impl needs dune) |

### Tier 3 — kernel enrichment (after Tier 1)

- OCaml types to replace `lib/domain.ml` strings (`id` phantom types)
- Decision validation against schema (currently parser-only)
- Multi-policy hierarchy (activation boundary per `spec/semantics.md` §"Protected Policy Transition")
- **D5: body-vs-wrapper canonicalization in `spec/algebra-3.2.md` §7** (2026-10-05 audit). **RESOLVED** by `decisions/d5-body-vs-wrapper-canonical-2026-10.yaml` (rev 1, 2026-10-13). The new `spec/algebra-3.2.md` §7.1 sub-section names the placeholder-substitution algorithm in OCaml (`lib/decision.ml::body_canonical_sha256`); the kernel's `tests/body_canonical_test.ml` pins four properties (stability, sensitivity, insensitivity-to-placeholder, CRLF-equals-LF); the kernel's `lib/decision.ml:1-20` comment block references the decision id and §7.1. The dual-authored case (algebra §6 sibling YAML) is formally DEFERRED to a follow-up decision `d5-dual-authored-canonical-2026-XX` with `reversal.signal: first-dual-authored-decision-drafted`. A3-protected transition (human review recorded in `attestations/d5-body-vs-wrapper-canonical-2026-10-a3-protected-transition.json`). 5/5 obligations closed; `mathc self-check` verdict on the new subject is `pass`.
- **`mathc migrate` declarative migration mechanism** (LANDED in v3.2.0-alpha, commit `81afd39` via `decisions/migration-mechanism-2026-10.yaml`). Pure `lib/migrate.ml` parses a `decisions/migrations/<from>-to-<to>.yaml` manifest with a four-kind vocabulary (`rename-field`, `add-field`, `bump-schema-string`, `manual-review`) and emits a per-file plan; the kernel never mutates YAML. First manifest `decisions/migrations/3.2-to-3.2.1.yaml` ships empty (proof-of-mechanism). Outstanding follow-ups still tracked here, NOT in `decisions/migration-mechanism-2026-10.yaml`, because each is itself a separate workstream:
  - **`--write` mode** that emits a sibling `<file>.migrated.yaml` (preserves the agent-review gate but provides a one-step assist); variant B from the original A/B/C analysis.
  - **Bump schema-string in all live decisions** from `math-coding/3.0-alpha` to `math-coding/3.2` — A3-protected transition (`schemas/decision.json` enum tightens; each live decision's `body_sha` + `yaml_sha` recompute; one new migration manifest becomes non-trivial). **LANDED in v3.2.0-alpha** via `decisions/schema-string-bump-3.0-alpha-to-3.2-2026-10.yaml`; 72 decisions bumped; 6 decisions back-filled with `body_sha`/`yaml_sha` (pre-v3.0.0.19 were missing those fields); no remaining follow-ups on the 3.0-alpha → 3.2 schema-string.
  
  **Follow-up: 3.0-alpha → 3.3 schema-string bump is in progress** via
  `decisions/schema-string-bump-3.0-alpha-to-3.3-2026-10.yaml` (state:
  active) and the migration manifest
  `decisions/migrations/3.0-alpha-to-3.3.yaml`. At HEAD 929bbc4 only 8
  decision files declare `schema: math-coding/3.3`; ~111 still declare
  `schema: math-coding/3.2`; the legacy `3.0-alpha` family is fully
  retired. Bump cadence is incremental — each new decision is
  authored at `3.3`; existing `3.2` decisions are migrated on
  touch, not in a single bulk pass. This is the residual work the
  "no remaining follow-ups" line previously elided.

### Tier 3.5 — math-coding 3.2-ideal implementation

**Status**: ✅ LANDED between `ff9e738` and `fd7ea8b` (13/13 tasks).
Schema extensions preserve backward compat (v3.0.0.20 → v3.1.0 alpha).

`mathc self-check` verdict at the time 3.5 landed: `pass`
(47 subjects, 47 pass / 0 unknown). The current live verdict
at HEAD ed069f7 is `unknown` with 57 pass / 1 unknown out of 58
subjects; the 1 unknown is `audit-0.0.21-fixes::self-check-verdict-is-pass`
(structurally inconclusive per `decisions/waivers/audit-0.0.21-fixes-self-check-waiver-2026-10.yaml`).

Runtime kernel behaviour is backward compatible: the existing
`mathc validate`, `mathc gate`, `mathc packages`, `mathc explain`,
`mathc self-check` keep working unchanged.

| # | Task | Decision | Status |
|---|---|---|---|
| 1 | Schema extensions: decision.json (+state, +body_sha, +yaml_sha, +axiom_link), attestation.json (+substrate_digest, +env_class_level), obligation.json (+phase, +obligation_domain) | `algebra-3.2@1` | ✅ done |
| 2 | lib/domain.ml: new fields, 5 epistemic markers, 3 obligation phases, 8 relations enum | `algebra-3.2@1` | ✅ done |
| 3 | lib/canonical.ml: risk function overhaul (impact × probability × irreversibility, exhaustive taxonomy, mode_floor) | `algebra-3.2@1` | ✅ done (`lib/risk.ml` NEW) |
| 4 | lib/decision.ml: parser extensions + sha-match validation | `algebra-3.2@1` | ✅ done |
| 5 | lib/policy.ml (NEW): per-path policy parser, union+transitive composition | `algebra-3.2@1` | ✅ done |
| 6 | lib/gate.ml: `apply()` function for kernel rules; gate_merge / gate_release / post_release_monitor | `algebra-3.2@1` | ✅ done |
| 7 | lib/rebuttal.ml (NEW): rebuttals/<sha>.yaml parser + walker; forge mirror adapter | `algebra-3.2@1` | ✅ done |
| 8 | lib/re_evaluation.ml (NEW): re_evaluate(d, A_new) oracle with Compatible \| StaleClaim \| Inconclusive | `algebra-3.2@1` | ✅ done |
| 9 | lib/attestations.ml: substrate_fingerprint, env_class_level, multi-CI aggregation | `algebra-3.2@1` | ✅ done |
| 10 | Cram fixtures: rebuttal.t, multi-policy.t, axiom-change.t, applic.t, trailer-formats.t | `algebra-3.2@1` | ⚠️ partial: 3 new (schema-extensions-3.2, migration-3.2-fields, applicability-envelope). Pre-existing self-check-{pass,unknown}.t expect 23 (pre-v3.0.0.20 snapshot). Snapshot regen deferred. |
| 11 | Migration: state=active on 28 existing decisions; body_sha/yaml_sha stubs | `algebra-3.2@1` | ✅ done (`scripts/migrate-decisions-3.2.py`) |
| 12 | ROADMAP.md, PACKAGES.md, CHANGELOG.md, USAGE.md sync (applicability envelope, two-tier model) | `algebra-3.2@1` | ✅ done |
| 13 | Portable binary build (anti-property fix in §30): musl-based or static-link, no nix-store paths | `algebra-3.2@1` | ✅ done (rev 4, 2026-10-07) |

### Tier 4 — v3.4 minimal pollution (2026-10-16)

Lands the kernel and docs changes that shrink the brownfield
artifact tree from three top-level directories (`decisions/`,
`attestations/`, `schemas/`) to one (`.math-coding/`), exposes
env-var overrides for hermetic testing, and adds the `attest-batch`
subcommand. Source plan: `/tmp/mathc-experiment/PLAN.md` §0–§6.

| # | Task | Decision | Status |
|---|---|---|---|
| 1 | P1 — `MATH_CODING_DECISIONS_DIR` / `MATH_CODING_ATTESTATIONS_DIR` / `MATH_CODING_POLICY` resolvers in `lib/path_config.ml`; embed JSON Schemas and templates into the kernel so `schemas/` is no longer required on disk | `ux-3-minimal-pollution-2026-10` | ✅ landed in commit `87a2e0a` (paths-defaults-2026-10) |
| 2 | P2 — counterexample pre-check (MC-COUNTEREXAMPLE-MISSING); `body_sha` / `yaml_sha` pattern enforcement (MC-BODY-SHA-PATTERN-VIOLATION); real `verifier` extraction in `mathc packages`; `materials_digest` required for `kind_ ∈ {test, build, observation}`; `revision: <int>` round-trip in memory entries | `kernel-bugs-v3.4-2026-10` | ✅ landed in commit `16e618a` (kernel-bugs-2026-10) |
| 3 | P3 — `mathc attest-batch [--manifest=PATH] [--from=decisions] [--out=DIR] [--kind=...] [--producer=ID] [--result=pass|fail] [--dry-run]` subcommand; pure logic in `lib/attestations/batch.ml`; cram fixtures `attest-batch-positive.t` / `attest-batch-malformed.t` | `ux-3-attest-batch-subcommand-2026-10` | ✅ landed in commit `7c503d8` (attest-batch-2026-10) |
| 4 | P4 — docs sync: `adoption/SKILL.md` (env-vars section, backward-compat section, bulk `attest-batch` section, step-3 template now contains `axiom_link` + `counterexample`, files-you-touch notes that `schemas/` is no longer required), `USAGE.md` (Greenfield / AI-agents), `README.md` (CLI table + badge), this Tier 4 entry | (no new decision; covered by the three above) | in this branch `docs-pollution-2026-10` |
| 5 | P5 — hermetic cram fixtures for the new behaviour: `init-defaults.t`, `init-legacy.t`, `path-config-fallback.t`, `embedded-schemas.t`, `counterexample-required.t`, `body-sha-pattern.t`, `packages-verifier-real.t`. Tracked separately, parallel to P4 | (no new decision; covered by the three above) | not in this branch |

Backward compatibility: every pre-3.4 project with
`decisions/` + `attestations/` + `decisions/decision.yaml` at the
repo root continues to validate without configuration changes —
the resolver falls back to the legacy layout whenever
`.math-coding/` is absent.

Deferred to v3.5 (not blocking 3.4):

- `MATH_CODING_HOME` system-wide templates and schemas directory
  (the variable is documented for forward compatibility but not yet
  consulted at runtime; `lib/path_config.ml` only resolves the
  three project-relative variables).
- `--layout=legacy|modern` explicit flag for `mathc init`
  (env-var override is the v3.4 mechanism).

### Tier 5 — install-tooling deferred work (Phase 2/3)

Three Phase-2/3 deferral decisions live in `decisions/` with
`state: active` and `reversal.signal:` blocks. They do not
block Tier 1 work; they record that the implementation is
sequenced after the install-tooling-2026-10 surface lands.
See `PACKAGES.md` §"Bootstrap packages (by file)" for status.

| # | Deferral | Phase | Reversal signal | Decision |
|---|---|---|---|---|
| 1 | MCP server (`lib/mcp/` + `bin/mathc_mcp.ml`) | Phase 2 | `mcp-server-impl-pending-resolved` | `mcp-server-impl-pending@1` |
| 2 | `Dockerfile.alpine` (depends on `mathc-linux-x86_64-musl` as release asset) | Phase 3 | `docker-alpine-impl-pending-resolved` | `docker-alpine-impl-pending@1` |
| 3 | Auto-update per-user skill (silent mutation prevention) | Phase 3+ | `auto-update-per-user-skill-impl-pending-resolved` | `auto-update-per-user-skill-impl-pending@1` |

All three decisions carry `kind_: review, producer: human:maintainer`
attestations under `attestations/<id>-deferral-recorded.json`
(verifier: `this-decision-file-present`). The deferrals are
bounded, not open-ended; future agents see when to re-engage.

### Remaining for v3.1.0 stabilisation

- **Cram snapshot regeneration**: as of HEAD `4ef31f7`, the
  cram snapshots in `tests/cli/self-check-pass.t:17` and
  `tests/cli/self-check-unknown.t:16` already read `28`
  (`subjects_len:28`, `total_subjects:28`, `pass_count:28`,
  `unknown_count:28`). The "snapshots say 23" claim in
  AUDIT-0.0.20.md is stale and does not match the tree.
  **Status**: closed at this sync (verified by
  `grep -n 'subjects_len\|total_subjects\|pass_count' tests/cli/self-check-*.t`,
  2026-10-04). **Reopened and re-closed at the 2026-10-07
  integrity cycle**: the live kernel reports 47 subjects with
  47 pass / 0 unknown (`mathc self-check`); the cram snapshots
  lag the live state until regenerated. The current fix path
  is `dune promote` after a clean `dune build` on a host
  with a working toolchain.
- **Portable binary build** (Tier 3.5+ #13): **RESOLVED** at
  rev 4 of `decisions/portable-linux-musl.yaml`
  (state: active, 2026-10-07). CI run #129
  (https://github.com/11111000000/math-coding/actions/runs/
  37696302997) is the first end-to-end green Alpine/musl
  build. Root cause of the 6 prior failures (#81, #83, #84,
  #85, #125, #126, #127, #128): `container: alpine:3.20`
  under `strategy.matrix.include` is silently ignored by
  GitHub Actions (only honored at the job level), so shell
  steps ran on the Ubuntu runner. OCaml-Best-Practices
  §11.26 documents the trap. Fix: explicit `docker run
  alpine:3.20 …` invocation in release.yml line ~122 with
  `apk add build-base musl-dev opam bash`, `opam update`,
  and an OCaml-5.4.0-from-source build. Closure: artifact
  `mathc-linux-x86_64-musl` is 4.99 MB, ELF with
  interpreter `/lib/ld-musl-x86_64.so.1` and NEEDED
  `libc.musl-x86_64.so.1` (no `libc.so.6`). Remaining
  follow-ups (not blocking §30 closure): the musl artifact
  is currently uploaded as a CI artifact but NOT in the
  GitHub release `files:` list — wired separately once main
  receives the fix-alpine-musl-2026-10 branch. The glibc
  pipeline (`mathc-linux-x86_64`, `mathc-linux-aarch64`,
  `mathc-darwin-*`, `mathc-windows-x86_64.exe`) is unaffected
  and continues to publish every release.

**Out of scope for 3.2** (deferred to 3.2.1 or 3.3):
- Axiom-as-decision (P5 from earlier plan; separate feature)
- Phantom types for IDs
- Per-path policies for non-default services

**Reference**: `spec/algebra-3.2.md` is the normative spec.

## Process principles (binding on all agents)

These are derived from the dialectical analyses accumulated across
2026-09-27 sessions. Each principle cites the failure mode it
prevents.

### P1. Decisions before kernel changes

A change to `lib/*.ml`, `spec/*.md`, `schemas/*.json`, or `bin/Mathc.ml`
ships with a `decisions/*.yaml` decision under the active policy.
**Rationale:** AGENTS.md self-application requires it; the T4/T6
session showed the cost of retrofit (2 retroactive decisions for what
should have been 2 forward decisions).

### P2. Decisions paired with fixtures

Every decision records its obligations, and every obligation has a
fixture that closes it (positive + negative). An untracked fixture file
(`tests/fixtures/*.sh`) is a deficit, not a draft. **Rationale:** the
yaml-block-scalars session showed a fixture appearing untracked because
the decision was bumped without the implementation.

### P3. Time-box on detailed work

If a single change exceeds 10 minutes without a passing build, switch
to **WIP commit + decision-record + next task**. **Rationale:** the
yaml-block-scalars session showed 15 minutes lost on OCaml type-inference
for code that was not Tier-1 priority. The OCaml build is a precision
tool, not a fast iteration loop.

### P4. Merge order: time → budget → kernel

When multiple parallel agents commit, integrate in this order:

1. **Decisions** (decisions/*.yaml) — never conflict
2. **Tests/fixtures** — additive, low conflict
3. **lib/ pure helpers** — additive at the type level
4. **bin/Mathc.ml** — touches dispatcher; merge last
5. **OCaml build fixes** (build artifacts, lockfiles) — own commit

### P5. Cram lives in `tests/cli/`; OLD `tests/cram/` and shell fixtures retired

`tests/cram/*.t` was removed in `dc78bcd` (v3-alpha-0.0.10). The
`tests/fixtures/cli-<sub>.sh` convention was retired at
v3-alpha-0.0.16 when all CLI shell fixtures were migrated to
`dune cram` in `tests/cli/*.t` (35 files at HEAD). Cram now lives in
`tests/cli/*.t`, asserting CLI stdout/stderr snapshots via dune 3.23
cram stanzas. The `tests/fixtures/` directory persists only as a
host for `scripts/dev verify` aggregator wrappers, not per-CLI
fixtures. **Rationale:** dune cram exposes `bin/mathc.exe` via
`(deps %{bin:mathc})` in the cram stanza combined with
`(public_name mathc)` in `bin/dune`; shell fixtures could not do
this portably. The enforced test at
`tests/process_principles.ml:332-348` checks only the OLD
`tests/cram/` directory is absent; the live cram is in `tests/cli/`.

**Correction (2026-10-04, refresh 2026-10-05, 2026-10-07):** `OCAML_BEST_PRACTICES.md` §11
trap log has 39 entries (§11.1–§11.39, verified by
`grep -c '^### 11\.' OCAML_BEST_PRACTICES.md`); the earlier
"§11 has only its header" claim was stale. §11.22 (`nix develop`
builds a non-portable `mathc` that fails) was added in `Unreleased`
(CHANGELOG:22) after the portable-musl reversal signal. New traps
should be appended following the §11.22 pattern (Symptom / Fix /
Referenced from / Trigger).

### P6. Pre-commit verification

Before `git commit`, run `scripts/dev verify`. It runs:
1. `pkill` stale `dune`/`nix develop` (cleans `_build/.lock`)
2. `dune build`
3. `dune test`
4. `scripts/fmt-check.sh`
5. `scripts/check.sh`

Each step independent so a fail in step 3 doesn't skip 4. ~30-60 s total.

### P7. Honesty in fixture assertions

A passing fixture must assert SOMETHING meaningful. `cram.out` matching
captured failure output is not a passing fixture; it's a self-referential
lie (see OCAML_BEST_PRACTICES §11.20 RETIRED). Fixtures assert positive
and negative cases; otherwise they don't test the obligation.

## What math-coding 3.3 is NOT

To prevent scope creep and clarify the protocol's stance:

- **Not** a CI runner or build orchestrator (use `scripts/dev`)
- **Not** a code-review tool (use `paseo` agents / GitHub PR review)
- **Not** a documentation generator (the spec is normative; tooling
  reads it)
- **Not** a runtime monitor (kernel runs offline; attestations are
  produced out-of-band)

The protocol's job is the **assurance loop**: every commitment has a
path to an observation, every observation has a known source class,
every source class is bounded by subject/inputs/time.

## See also

- `AGENTS.md` — agent conduct (defer to this file for priorities)
- `OCAML_BEST_PRACTICES.md` — OCaml traps and conventions
- `decisions/decision.yaml` — the active policy
- `doc/AUDIT-0.0.11.md` — the open/closed audit chain
