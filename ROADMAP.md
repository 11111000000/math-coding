# Math-coding 3.7.4 — ROADMAP

> **Status (2026-10-29):** bootstrap protocol **expired**
> (commit `8fa7fcf`). The kernel checks this repository and its
> conformance corpus via `mathc self-check`, which is a **blocking** CI
> step per `spec/constitution.md` Invariant 14. The attestation store at
> `attestations/` is populated by the live pipeline; the live
> committed count is emitted by `mathc counters --format=json`
> (single source of truth — this file deliberately does not re-state
> the per-checkout number because every `attestations/*.json`
> commit would invalidate it). The CLI surface is normative in
> `spec/semantics.md §CLI subcommands`; the dispatcher answers 39
> subcommands (`mathc counters --format=json` reports
> `cli.subcommand_count`).
>
> **Algebra 3.2-ideal**: accepted via `decisions/algebra-3.2.yaml`;
> normative spec at `spec/algebra-3.2.md` (31 sections, §0–§30).
> Implementation history: the closed-tier history below.
>
> **Author:** Petr Kosov &lt;p.b.kosov@yandex.ru&gt;
> **License:** Apache-2.0 (see `LICENSE`, `NOTICE`)
> **Active policy:** `bootstrap-v3@3` (see `decisions/decision.yaml`)

This document is the **single source of truth** for what math-coding 3.7.4
is doing, what it is not yet doing, and in what order the remaining
work should land. It supersedes ad-hoc "critical analysis" reports and
inline KERNEL_AGENTS.md priority lists; KERNEL_AGENTS.md defers to this file.

## Working chain (recap)

```text
intent -> decision -> obligation -> change -> attestation -> revision
```

Every commit on `main` must close at least one obligation. No obligation
closes without a positive + negative fixture. No kernel change ships
without a `decisions/*.yaml` decision under the active policy.

## Priority queue (highest leverage first)

The closed tiers are history, and their decisions are the record. Tiers
0, 1, 2, 2.5, 2.6, 3.5 and 4 are closed or landed: the bootstrap
(`decisions/decision.yaml`,
`decisions/gate-attestation-store-fill-decision.yaml`,
`decisions/mathc-self-check-subcommand.yaml`,
`decisions/mathc-explain-subcommand.yaml`,
`decisions/kernel-conformance-runner.yaml`,
`decisions/yaml-block-scalars.yaml`), process hardening
(`decisions/process-principles-close-branches.yaml`,
`decisions/site-deploy.yaml`, `decisions/mathc-packages-subcommand.yaml`,
`decisions/version-sync-2026-10.yaml`,
`decisions/install-tooling-2026-10.yaml`), the audit-deficit closures
(`decisions/priority-drift.yaml`, `decisions/spec-cli-catalog.yaml`,
`decisions/adapters.yaml`,
`decisions/D6-bootstrap-v3-verifiers-implemented.yaml`), the onboarding
batch (`decisions/install-tooling-default-tag-edge-2026-10.yaml`,
`archive/decisions/print-usage-complete-2026-10.yaml`,
`decisions/ux-3-adoption-doc-freshen-2026-10.yaml`,
`decisions/ux-3-new-decision-subcommand-2026-10.yaml`,
`decisions/mcp-agent-auto-connect-2026-10.yaml`,
`archive/decisions/ux-3-init-release-binary-noop-skill-2026-10.yaml`),
the two deferred designs (`decisions/update-check-notify-2026-10.yaml`,
`decisions/ux-3-init-copies-ci-workflow-2026-10.yaml`), the 3.2-ideal
algebra batch (`decisions/algebra-3.2.yaml`) and the minimal-pollution
batch (`decisions/ux-3-minimal-pollution-2026-10.yaml`,
`decisions/kernel-bugs-v3.4-2026-10.yaml`,
`archive/decisions/ux-3-attest-batch-subcommand-2026-10.yaml`). What
they bought, in one line each: a kernel that checks its own repository,
a gate that computes the verdict from evidence, a conformance runner,
the 3.2-ideal algebra (`spec/algebra-3.2.md`), and a resolver that
keeps the brownfield artifact tree to one directory.

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

### Open

| # | Deficit | Status | Notes |
|---|---|---|---|
| 11 | D8 (`mathc validate` coarse diagnostics) | **open** | tracked for 3.0-beta |

### Tier 3 — kernel enrichment (after Tier 1)

- OCaml types to replace `lib/domain.ml` strings (`id` phantom types)
- Decision validation against schema (currently parser-only)
- Multi-policy hierarchy (activation boundary per `spec/semantics.md` §"Protected Policy Transition")
- **D5: body-vs-wrapper canonicalization in `spec/algebra-3.2.md` §7** (2026-10-05 audit). **RESOLVED** by `decisions/d5-body-vs-wrapper-canonical-2026-10.yaml` (rev 1, 2026-10-13). The new `spec/algebra-3.2.md` §7.1 sub-section names the placeholder-substitution algorithm in OCaml (`lib/decision.ml::body_canonical_sha256`); the kernel's `tests/body_canonical_test.ml` pins four properties (stability, sensitivity, insensitivity-to-placeholder, CRLF-equals-LF); the kernel's `lib/decision.ml:1-20` comment block references the decision id and §7.1. The dual-authored case (algebra §6 sibling YAML) is formally DEFERRED to a follow-up decision `d5-dual-authored-canonical-2026-XX` with `reversal.signal: first-dual-authored-decision-drafted`. A3-protected transition (human review recorded in the decision's `kind_: review` attestation). 5/5 obligations closed; `mathc self-check` verdict on the new subject is `pass`.
- **`mathc migrate` declarative migration mechanism** (LANDED in v3.2.0-alpha, commit `81afd39` via `decisions/migration-mechanism-2026-10.yaml`). Pure `lib/migrate.ml` parses a `decisions/migrations/<from>-to-<to>.yaml` manifest with a four-kind vocabulary (`rename-field`, `add-field`, `bump-schema-string`, `manual-review`) and emits a per-file plan; the kernel never mutates YAML. First manifest `decisions/migrations/3.2-to-3.2.1.yaml` ships empty (proof-of-mechanism). Outstanding follow-ups still tracked here, NOT in `decisions/migration-mechanism-2026-10.yaml`, because each is itself a separate workstream:
  - **`--write` mode** that emits a sibling `<file>.migrated.yaml` (preserves the agent-review gate but provides a one-step assist); variant B from the original A/B/C analysis.
  - **Bump schema-string in all live decisions** from `math-coding/3.0-alpha` to `math-coding/3.2` — A3-protected transition (`schemas/decision.json` enum tightens; each live decision's `body_sha` + `yaml_sha` recompute; one new migration manifest becomes non-trivial). **LANDED in v3.2.0-alpha** via `decisions/schema-string-bump-3.0-alpha-to-3.2-2026-10.yaml`; 72 decisions bumped; 6 decisions back-filled with `body_sha`/`yaml_sha` (pre-v3.0.0.19 were missing those fields); no remaining follow-ups on the 3.0-alpha → 3.2 schema-string.
- **Schema-string bump 3.0-alpha → 3.3 is in progress** via
  `decisions/schema-string-bump-3.0-alpha-to-3.3-2026-10.yaml` (state:
  active). The legacy `3.0-alpha` family is fully retired; every new
  decision is authored at `3.3`, and existing `3.2` decisions are
  migrated on touch rather than in a bulk pass. The split between the
  two families moves with every authored decision, so read it live:
  `grep -rhoE '^schema: math-coding/3\.[0-9]+' decisions/ | sort | uniq -c`.

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
  integrity cycle**: the kernel reported 47 subjects with
  47 pass / 0 unknown (`mathc self-check`); the cram snapshots
  lag the live state until regenerated. The current fix path
  is `dune promote` after a clean `dune build` on a host
  with a working toolchain.
- **Portable binary build** (the 3.2-ideal algebra §30 closure): **RESOLVED** at
  rev 4 of `decisions/portable-linux-musl.yaml`
  (state: active, 2026-10-07). CI run #129
  (https://github.com/11111000000/math-coding/actions/runs/
  37696302997) is the first end-to-end green Alpine/musl
  build. Root cause of the 6 prior failures (#81, #83, #84,
  #85, #125, #126, #127, #128): `container: alpine:3.20`
  under `strategy.matrix.include` is silently ignored by
  GitHub Actions (only honored at the job level), so shell
  steps ran on the Ubuntu runner. OCAML_KERNEL_CONVENTIONS
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
**Rationale:** KERNEL_AGENTS.md self-application requires it; the T4/T6
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
`dune cram` in `tests/cli/*.t`. Cram now lives in
`tests/cli/*.t`, asserting CLI stdout/stderr snapshots via dune 3.23
cram stanzas. The `tests/fixtures/` directory persists only as a
host for `scripts/dev verify` aggregator wrappers, not per-CLI
fixtures. **Rationale:** dune cram exposes `bin/mathc.exe` via
`(deps %{bin:mathc})` in the cram stanza combined with
`(public_name mathc)` in `bin/dune`; shell fixtures could not do
this portably. The enforced test at
`tests/process_principles.ml:332-348` checks only the OLD
`tests/cram/` directory is absent; the live cram is in `tests/cli/`.

**Correction (2026-10-04, refresh 2026-10-05, 2026-10-07):** `OCAML_KERNEL_CONVENTIONS.md` §11
trap log has 42 entries (§11.1–§11.42, verified by
`grep -c '^### 11\.' OCAML_KERNEL_CONVENTIONS.md`); the earlier
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
lie (see OCAML_KERNEL_CONVENTIONS §11.20 RETIRED). Fixtures assert positive
and negative cases; otherwise they don't test the obligation.

### P8. No stub without tracking

A stub left in the tree with no decision that says what will replace it
is a silent promise. Every stub carries a tracking decision, and
`scripts/check-stub-lint.sh` fails the build on an untracked one.
**Rationale:** an unowned stub reads exactly like finished work.
The principle is recorded in
`decisions/plan-2026-10-improvements/t6-1.yaml` and asserted by
`tests/process_principles.ml`.

## What math-coding 3.7.4 is NOT

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

## The cost of the loop (measured 2026-10-26)

The requirement an adopter states first is that the checks be cheap
enough to run on EVERY change. Measured on a warm tree at
`be224a52` (`scripts/dev-profile.sh`):

| link | cost | share |
|---|---|---|
| `scripts/check.sh` | **77.2 s** | **78 %** |
| `dune runtest` (alcotest) | 10.5 s | 11 % |
| `dune build` | 6.2 s | 6 % |
| `nix develop` (one entry) | 3.2 s | 3 % |
| `mathc precommit` (corpus) | 1.8 s | 2 % |
| cram (cached) | 0.6 s | 1 % |

Five of the aggregator's thirty-three fixtures cost 43 % of it; three
of those five pay for a `nix develop` they are already standing in.
The sweep is a separate cost: 129–165 s and 891 rewritten files.

Four levers, in the order of their measured cost, and the target
against which they can be falsified, are in
`archive/decisions/verification-cycle-cost-2026-10.yaml`. The fast path
(`scripts/dev test-fast`) is 0.7–1.5 s for ONE binary and is the
only thing affordable per change.

## See also

- `KERNEL_AGENTS.md` — agent conduct (defer to this file for priorities)
- `OCAML_KERNEL_CONVENTIONS.md` — OCaml traps and conventions
- `decisions/decision.yaml` — the active policy
- `docs/AUDIT-0.0.11.md` — the open/closed audit chain
