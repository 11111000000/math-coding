# Math-coding 3.7.4 — Packages

> **Single source of truth for "what exists in math-coding 3.7.4".**
> If you are a new agent picking up this repository, this is the file
> you read first (after `ROADMAP.md`, which is the priority queue).
> Every other decision document can be read in isolation; this one
> shows you the whole picture at a glance.

Last reviewed: 2026-10-29 (prose cleanup). The live inventory is
`mathc counters --format=json` and `mathc packages --format=json`;
the sync history of earlier revisions is in `git log -- PACKAGES.md`.

Live counts are emitted by `mathc counters --format=json` and are the
**single source of truth** for "what exists in math-coding 3.7.4" —
this file deliberately does not re-state the per-checkout numbers,
because every `attestations/*.json` or `decisions/*.yaml` commit
would invalidate them.

Run `mathc counters --format=json` for the live attestation,
decision, obligation, cram, and CLI-subcommand counts. The raw
on-disk `live_store` additionally includes the `.gitignore`-excluded
test scratch — `t1-2-A0-*` attestations and the `1-foo` /
`1-use-postgresql` scaffold decisions — so the raw number varies
with local test runs; the committed count is the one a downstream
caller should cite. The master policy's 7 obligations are enumerated
separately from the live decisions' verdicts and also live in the
JSON.

`tests/counters_drift.ml` enforces this contract: it asserts that
`PACKAGES.md` and `ROADMAP.md` reference `mathc counters` instead of
carrying per-checkout numbers in the live-counter blocks. Adding a
new `attestations/*.json` (or `decisions/*.yaml`, or
`tests/cli/*.t`) MUST NOT cause that test to fail.

> Note: at HEAD `d52c85b` the `mathc counters` `schema`
> block reports the live values (schema_enum lists the six
> accepted families; intent_oneOf and scope_oneOf are true).
> The under-report recorded at
> `decisions/counters-schema-introspection-deferral-2026-10`
> is fixed at
> `decisions/counters-schema-introspection-fix-2026-10` (see
> commit `3310234` and merge `8b9a060`).

`mathc self-check` is the authority on the current verdict and on the
per-subject counts; `mathc gaps` lists every open promise with its
class, its state and the action that closes it. Neither is restated
here: both move with every attestation commit. The history of the
subjects that were unknown in earlier cycles is in
`git log -- PACKAGES.md`.

The attestation store is generated, not committed
(`decisions/store-not-committed-2026-10.yaml`); the release path is
`scripts/sign-store.sh`. A waiver changes a gate's disposition, never
the assurance result (`decisions/waiver-infrastructure-2026-10.yaml`,
`decisions/waivers/`).
The `mathc self-check` cram snapshot at `tests/cli/self-check-pass.t`
reads a hand-written store of ten pass attestations and reflects the
actual verdict; the full-corpus mirror it used to read was removed on
2026-10-28 with the corpus-debt meta-layer
(`decisions/corpus-meta-layer-2026-10.yaml`).

**Cross-references:**
- `ROADMAP.md` — priorities, tier ordering, process principles (P1–P7)
- `KERNEL_AGENTS.md` — agent protocol, read-first order
- `OCAML_KERNEL_CONVENTIONS.md` — OCaml conventions + trap log
- `docs/AUDIT-0.0.11.md` — open/closed deficit chain

## Status legend

- **RESOLVED** — obligation closed by implementation, fixture green
- **DECISION** — decision recorded, implementation pending
- **DEFERRED** — explicitly deferred per recorded decision (see
  `decisions/<id>-impl-pending.md`)
- **SCAFFOLD** — kernel surface exists but does not yet block

## Active policy

**`bootstrap-v3@3`** (`decisions/decision.yaml`) — the master policy
that authorises all other decisions. Its obligations are tracked in
`decisions/obligations.yaml`.

## Bootstrap packages (by file)

| File | Decision id | Rev | Status | Closes audit |
|---|---|---|---|---|
| `decisions/decision.yaml` | `bootstrap-v3` | 3 | RESOLVED | bootstrap protocol |
| `decisions/infrastructure-honesty.yaml` | `infrastructure-honesty` | 2 | RESOLVED | audit D5, D7 |
| `decisions/kernel-conformance-runner.yaml` | `kernel-conformance-runner` | 2 | RESOLVED | conformance runner |
| `decisions/validate-and-context.yaml` | `validate-and-context` | 3 | RESOLVED | first CLI + context capsule |
| `decisions/priority-drift.yaml` | `priority-drift` | 3 | RESOLVED | audit D3 |
| `decisions/spec-cli-catalog.yaml` | `spec-cli-catalog` | 2 | RESOLVED | audit D4 |
| `decisions/adapters.yaml` | `adapters` | 3 | RESOLVED | audit D7 (git + junit) |
| `decisions/capsule-active-policy.yaml` | `capsule-active-policy` | 2 | RESOLVED | capsule priority class |
| `decisions/gate-decision.yaml` | `gate-decision` | 2 | RESOLVED | mathc gate verdict against populated store |
| `decisions/gate-attestation-store-fill-decision.yaml` | `gate-attestation-store-fill` | 2 | RESOLVED | Tier-1 #1 (closed in `ed42290`) |
| `decisions/attestation-store-fill.yaml` | `attestation-store-fill` | 3 | RESOLVED | populates `attestations/` |
| `decisions/mathc-explain-subcommand.yaml` | `mathc-explain-subcommand` | 3 | RESOLVED | Tier-A (closed in `6e922d3`) — broken promise from `omitted[].expansion` resolved |
| `decisions/mathc-self-check-subcommand.yaml` | `mathc-self-check-subcommand` | 4 | RESOLVED | Tier-1 #2 (closed in `758f340`) |
| `decisions/parse-acceptance-diagnostics.yaml` | `parse-acceptance-diagnostics` | 2 | RESOLVED | kernel diagnostics |
| `decisions/time-honesty.yaml` | `time-honesty` | 2 | RESOLVED | time-honesty distribution |
| `decisions/time-honesty-storage.yaml` | `time-honesty-storage` | 2 | RESOLVED | time storage writers |
| `decisions/yaml-block-scalars.yaml` | `yaml-block-scalars` | 5 | RESOLVED | audit D1/D2 (closed in `79d138b`, v3.0.0.19) |
| `decisions/yaml-block-scalars-impl-pending.yaml` | `yaml-block-scalars-impl-pending` | 3 | RESOLVED | records D1/D2 deferral, superseded by yaml-block-scalars@4 |
| `archive/decisions/validator-actionable-error.yaml` | `validator-actionable-error` | 1 | RESOLVED | D8 actionable validator error: missing-field name in diagnostic |
| `decisions/process-principles.yaml` | `process-principles` | 3 | RESOLVED | locks ROADMAP P1-P7 as obligations |
| `archive/decisions/D6-bootstrap-v3-verifiers-implemented.yaml` | `D6-bootstrap-v3-verifiers-implemented` | 2 | RESOLVED | closes D6 (manual-only verifiers) per AUDIT-0.0.20 |
| `decisions/portable-linux-musl.yaml` | `portable-linux-musl` | 3 | RETIRED | attempted kernel contract §30 closure via Alpine container build; CI runs #81/#83/#84/#85 broke on opam setup; reversal signal `alpine-ci-build-fails` fired per the decision file. Re-enable when Alpine image debugged. |
| `decisions/agent-onboarding.yaml` | `agent-onboarding` | 2 | RESOLVED | locks ADR location + first-file convention |
| `decisions/formal-verifier-conventions.yaml` | `formal-verifier-conventions` | 2 | RESOLVED | locks tla:/coq:/alloy: prefix convention (no tool added) |
| `decisions/cli-cram-tests.yaml` | `cli-cram-tests` | 2 | RESOLVED | replaces 14 cli-*.sh fixtures with cram .t |
| `decisions/site-deploy.yaml` | `site-deploy` | 5 | RESOLVED | restores the project's published surface under its own gate |
| `decisions/cli-canonical-name.yaml` | `cli-canonical-name` | 2 | RESOLVED | collapses mc/mathc/mathc.exe CLI referents into one |
| `decisions/3-2-cli-catalog.yaml` | `3-2-cli-catalog` | 2 | RESOLVED | closes 3.2-cli-catalog drift (mode, rebuttals, re-evaluate subcommands added) |
| `decisions/algebra-3.2.yaml` | `algebra-3.2` | 2 | RESOLVED | adopts `spec/kernel-contract.md` as formal normative spec |
| `decisions/audit-0.0.21-fixes.yaml` | `audit-0.0.21-fixes` | 2 | RESOLVED | master decision for the integrity-fixes cycle (Phase 1-5) |
| `decisions/render-kernel-fixes-2026-10.yaml` | `render-kernel-fixes-2026-10` | 1 | RESOLVED | closes the 10 render-kernel defects catalogued in the decision's own scope (fenced blocks, list continuation, italic, MathJax, packages grid, RU nav, axiom single `<h1>`, footer text, `base href` empty option, `mc-*` deploy re-sync) |
| `decisions/mathjax-delimiter-hardening-2026-10.yaml` | `mathjax-delimiter-hardening-2026-10` | 1 | RESOLVED | narrows MathJax 3 inline/display delimiters to LaTeX-style `\(..\)` / `\[..\]` only; removes `$..$` and `$$..$$` from `lib/render/render.ml`; ships `mjx-container` + `.mermaid svg` CSS rules so future `--mathjax` opt-ins and mermaid diagrams respect the Tufte column rhythm |
| `archive/decisions/mathjax-default-on-2026-10.yaml` | `mathjax-default-on-2026-10` | 1 | RESOLVED | flips `Render.config.enable_mathjax` default `false` → `true`; reverses the `mathjax-default-off` workaround from `render-kernel-fixes-2026-10@1` because `mathjax-delimiter-hardening-2026-10@1` removed `$..$` as a math boundary; emits MathJax on every page (prose + axiom + spec) |
| `archive/decisions/site-version-from-file-2026-10.yaml` | `site-version-from-file-2026-10` | 1 | RESOLVED | replaces hardcoded `3.0-alpha` / `v3.0.0` literals in `lib/render/render.ml` with a single `VERSION` file; `mathc render` + `mathc version` read it; closes the dual-source drift between the live site hero and the current release tag |
| `decisions/plan-2026-10-improvements/t1-1.yaml` | `t1-1` | 1 | RESOLVED | wires `lib/rebuttal.ml::forge_mirror` to `MATH_CODING_FORGE_API`; kernel contract §10 hybrid mechanism is functional end-to-end; closes `plan-2026-10-improvements@1` Tier 1 obligation `t1-1-forge-mirror` |
| `decisions/risk-policy-driven-floor-2026-10.yaml` | `risk-policy-driven-floor-2026-10` | 1 | RESOLVED | wires `lib/policy.ml` into `lib/risk.ml` so `mode_floor` and `policy_override_probability` honor declared policies instead of returning constants; closes kernel contract §2 "Phase 2E replaces this stub" comment; adds `policies.yaml` at the repo root and `OCAML_KERNEL_CONVENTIONS.md` §11.25 |
| `archive/decisions/tier-1-closure-2026-10.yaml` | `tier-1-closure-2026-10` | 1 | RESOLVED | closes ROADMAP Tier 1: 5 conformance fixtures carry the v3 dialectic `antithesis` field, `process_principles.ml::classify_verifier` and `fixture_coverage.ml::classify` accept three new patterns (sub-decision refs, shell-negated grep, `mathc-self-check-` keywords), 18 stale verifier references in 4 decisions are fixed, ROADMAP.md §"Priority queue" records Tier 0 as `closed` |
| `decisions/ci-blocking-list-config.yaml` | `ci-blocking-list-config` | 2 | RESOLVED | configurable blocking-CI list via MATH_CODING_BLOCKING_CIS |
| `decisions/process-principles-close-branches.yaml` | `process-principles-close-branches` | 3 | RESOLVED | close-branches subcommand and pre-commit hook (process-principles@2 P2 detail) |
| `decisions/mathc-packages-subcommand.yaml` | `mathc-packages-subcommand` | 3 | RESOLVED | Tier-1 #4 |
| `decisions/obligation-count-reconcile.yaml` | `obligation-count-reconcile` | 3 | RESOLVED | aligns PACKAGES.md counts with `obligations.yaml` |
| `archive/decisions/spec-prose-corrections-2026-10.yaml` | `spec-prose-corrections-2026-10` | 2 | RESOLVED | factual corrections to spec/kernel-contract.md and spec/semantics.md (2026-10-05 audit F7, F11) |
| `decisions/algebra-3.2-notation-flag-2026-10.yaml` | `algebra-3.2-notation-flag-2026-10` | 2 | RESOLVED | flags ambiguous `⌈risk(c)⌉` notation in kernel contract §2 (2026-10-05 audit F9) |
| `decisions/schema-empty-sha-2026-10.yaml` | `schema-empty-sha-2026-10` | 3 | RETIRED | schema relaxation for empty-string `body_sha`/`yaml_sha` stubs; not counted as active decision |
| `archive/decisions/audit-0.0.21-fixes-self-check-waiver-2026-10.yaml` | `audit-0.0.21-fixes-self-check-waiver-2026-10` | 2 | META | waiver record for the structural deficit on `self-check-verdict-is-pass`; not counted as active decision |
| `decisions/waiver-infrastructure-2026-10.yaml` | `waiver-infrastructure-2026-10` | 1 | META | introduces `lib/waiver.ml` + the consult step in `bin/Mathc.ml`; waivers live under `decisions/waivers/`; not counted as active decision (no kernel surface) |
| `decisions/docker-alpine-impl-pending.yaml` | `docker-alpine-impl-pending` | 1 | DEFERRED | Phase-3 deferral of `Dockerfile.alpine` (depends on `mathc-linux-x86_64-musl` shipping as release asset, not yet wired in `release.yml:308-314`); reversal signal `docker-alpine-impl-pending-resolved` |
| `decisions/auto-update-per-user-skill-impl-pending.yaml` | `auto-update-per-user-skill-impl-pending` | 1 | DEFERRED | Phase-3+ deferral of silent auto-update of per-user skill; manual `install.sh --user-skill --upgrade` is the contract until version-pinning protocol lands; reversal signal `auto-update-per-user-skill-impl-pending-resolved` |
| `decisions/version-sync-2026-10.yaml` | `version-sync-2026-10` | 1 | RESOLVED | `scripts/sync-version.sh --check/--write` keeps `adoption/SKILL.md` and future `install.sh` derived version strings in sync with the `VERSION` file; closes the follow-up announced at `site-version-from-file-2026-10.yaml:76-81`; adds `OCAML_KERNEL_CONVENTIONS.md` §11.27 |
| `decisions/install-tooling-2026-10.yaml` | `install-tooling-2026-10` | 1 | RESOLVED | four install channels (release binary / docker image / nix run / source build) + per-user skill pipeline + `templates/active-policy.yaml` for new repos; POSIX-sh `install.sh` with SHA-256 verification; ships `Dockerfile.debian-slim`, `flake.nix` `apps.default`, `.github/workflows/docker.yml`, and `OCAML_KERNEL_CONVENTIONS.md` §11.28/§11.29 |
| `archive/decisions/lib-stale-comments-cleanup-2026-10.yaml` | `lib-stale-comments-cleanup-2026-10` | 1 | META | removes dead-code narrative comments from `lib/risk.ml` (Phase 2E stub claim, already wired via `risk-policy-driven-floor-2026-10`) and `lib/packages.ml` (v3.0.0.30 task claim, already landed via `waiver-infrastructure-2026-10`); behavioural equivalence preserved by construction; not counted as active decision (no kernel surface) |
| `decisions/parser-risk-owner-default.yaml` | `parser-risk-owner-default` | 1 | RESOLVED | documents the risk-block owner-default workaround for `decisions/decision.yaml`; proper kernel fix deferred to `kernel-default-owner-landed` reversal signal |
| `archive/decisions/agent-debug-infrastructure-2026-10.yaml` | `agent-debug-infrastructure-2026-10` | 1 | META | scripts/agent-debug + tests/traps.ml + tests/qcheck_parsers.ml + Jsonl.Parse_error verbosity; not counted as active decision (dev-infra, no kernel surface) |
| `decisions/merlin-lsp-2026-10.yaml` | `merlin-lsp-2026-10` | 1 | META | hand-written `.merlin` + `ocaml-lsp` + `merlin` in `flake.nix` ocamlDeps; not counted as active decision (dev-infra, no kernel surface) |
| `decisions/junit-entity-off-by-one-fix-2026-10.yaml` | `junit-entity-off-by-one-fix-2026-10` | 1 | RESOLVED | off-by-one in `lib/junit/junit.ml:74-90` entity-reference boundary check; `tests/junit_test.ml` regression; new §11.23 trap |
| `decisions/migration-mechanism-2026-10.yaml` | `migration-mechanism` | 2 | RESOLVED | `mathc migrate --from=X --to=Y [--root=DIR] [--format=text\|json] [--explain] [--manifest=PATH]` is a new declarative subcommand in `bin/Mathc.ml` backed by pure `lib/migrate.ml`; the kernel never mutates YAML on disk, it only reads a `decisions/migrations/<from>-to-<to>.yaml` manifest and prints a per-file plan; ships the first manifest `decisions/migrations/3.2-to-3.2.1.yaml` as a no-op proof-of-mechanism; **rev 2 adds `--write` and `--dry-run`**: `--write` applies auto-translatable actions to a sibling `<file>.migrated.yaml` (NEVER overwrites the original); `--dry-run` paired with `--write` prints the per-file JSON summary without touching the disk; the apply path …
| `archive/decisions/install-tooling-default-tag-edge-2026-10.yaml` | `install-tooling-default-tag-edge-2026-10` | 1 | RESOLVED | closes 404 install URL on first-touch adoption |
| `archive/decisions/print-usage-complete-2026-10.yaml` | `print-usage-complete-2026-10` | 1 | RESOLVED | mathc --help lists the dispatchable subcommands, including adopt, migrate, telemetry, new-decision |
| `archive/decisions/ux-3-init-release-binary-noop-skill-2026-10.yaml` | `ux-3-init-release-binary-noop-skill-2026-10` | 1 | RESOLVED | documents release-binary vs in-source-build split for --agent opencode |
| `decisions/ux-3-adoption-doc-freshen-2026-10.yaml` | `ux-3-adoption-doc-freshen-2026-10` | 2 | RESOLVED | Step 1 sync to install.sh --user-skill; drops 3.1.0-alpha-final literal |
| `decisions/ux-3-new-decision-subcommand-2026-10.yaml` | `ux-3-new-decision-subcommand-2026-10` | 1 | RESOLVED | mathc new-decision <id> scaffolds decisions/<id>.yaml |
| `decisions/mcp-server-impl-pending.yaml` | `mcp-server-impl-pending` | 2 | RETIRED | retired; MCP server landed via mcp-server-impl-2026-10@1 and ux-3-mcp-read-write-2026-10@1 |
| `decisions/mcp-agent-auto-connect-2026-10.yaml` | `mcp-agent-auto-connect-2026-10` | 1 | RESOLVED | documents mathc_mcp JSON-RPC integration in adoption/SKILL.md §"MCP integration" |
| `decisions/update-check-notify-2026-10.yaml` | `update-check-notify-2026-10` | 1 | DEFERRED | designs opt-in version notification (state: deferred; needs dune) |
| `decisions/ux-3-init-copies-ci-workflow-2026-10.yaml` | `ux-3-init-copies-ci-workflow-2026-10` | 1 | DEFERRED | designs mathc init auto-wire templates/ci.yml (state: deferred; needs dune) |
| `archive/decisions/schema-string-bump-3.0-alpha-to-3.2-2026-10.yaml` | `schema-string-bump-3.0-alpha-to-3.2` | 1 | RESOLVED | A3-protected transition that brings the schema-string on every live decision forward from `math-coding/3.0-alpha` to `math-coding/3.2` (matches the field set the algebra-3.2 spec formalises); `schemas/decision.json`'s `schema` enum now accepts both forms for one cycle (soft-deprecated `3.0-alpha`); first non-trivial migration cycle of `lib/migrate.ml` is `decisions/migrations/3.0-alpha-to-3.2.yaml` (a single `bump-schema-string` action); bulk-bumped 72 decision YAML files via `scripts/bulk-bump-schema.sh` (a one-shot, post-merger script that's now removed from the tree) and back-filled body_sha/yaml_sha on the 6 decisions that predated the v3.0.0.19 schema tightening; fixture: `tests/cli/migrate-bump-replay.t` (replays the manifest against a synthetic legacy tree and asserts a no-op plan against the live post-bump tree) |
| `decisions/plan-2026-10-improvements/t4-2.yaml` | `t4-2-explain-diagnostic` | 1 | RESOLVED | Tier-4 #2: `mathc explain-diagnostic <CODE>` subcommand; registry in `lib/diagnostic.ml::explain`; positive+negative cram fixture |
| `archive/decisions/site-svg-methodology-2026-10.yaml` | `site-svg-methodology-2026-10` | 1 | RESOLVED | adds 5 hand-rolled SVG figures to the methodology page (`lifecycle-fsm`, `friction-ladder`, `attestation-lifecycle`, `risk-bands`, `verdict-flow`); the figures are embedded inline in the site markdown; each SVG is accessibility-tagged (`role="img"` + `aria-labelledby` + `<title>`) and inherits the existing `.mathc-figure-methodology img { max-width: 56rem; }` CSS rule |
| `archive/decisions/site-svg-manifesto-2026-10.yaml` | `site-svg-manifesto-2026-10` | 1 | RESOLVED | adds 4 hand-rolled SVG figures to the manifesto page (`architecture-overview`, `human-in-the-loop`, `human-roles`, `kernel-vs-human`); the figures are embedded inline in the site markdown; new `.mathc-figure-manifesto img { max-width: 56rem; }` CSS rule in `assets/style.css` |
| `archive/decisions/site-svg-foundations-2026-10.yaml` | `site-svg-foundations-2026-10` | 1 | RESOLVED | adds 8 hand-rolled specialist diagrams to the foundations page (`counterexample-flow`, `axiom-transition`, `trust-dynamics`, `substrate-fingerprint`, `waiver-state-machine`, `friction-envelope-plot`, `quality-radar`, `reasoning-budget`); the figures are embedded inline in the site markdown; covers kernel contract §11, §12, §13–14, §16, §17, §18, §21, §22, §27 |
| `archive/decisions/site-svg-workflow-2026-10.yaml` | `site-svg-workflow-2026-10` | 1 | RESOLVED | adds the `bootstrap-timeline` SVG to the workflow page; the figure is embedded inline in the site markdown; new `.mathc-figure-workflow img { max-width: 56rem; }` CSS rule; the timeline shows the three regime boundaries (v3-alpha-0.0.1 → 8fa7fcf → today) |
| `decisions/obligations.yaml` | (aggregator) | — | INDEX | tracks bootstrap-v3 obligations |

**Column key.** `Rev` is the decision's revision and `Status` the
lifecycle state its file carries. The per-decision obligation count is
deliberately NOT a column: it moves with every revision, and the live
count for any decision is `mathc packages --format=json`.

## Cram integration tests (`tests/cli/*.t`)

Cram `.t` files exercise the mathc CLI as a separate process via
`dune runtest`. Each `.t` is both the test and the fixture: cram
captures stdout/stderr of the `$ command` lines and compares
against the expected snapshot below each command.

The binary is exposed to the cram shell by `(public_name mathc)`
in `bin/dune` combined with `(deps %{bin:mathc})` in the cram
stanza (`tests/cli/dune`). dune installs mathc to
`_build/install/default/bin/mathc` and adds it to `$PATH` of every
cram test that declares the dep.

Path portability: each test does `cd "$DUNE_SOURCEROOT"` first so
mathc sees project-relative paths; its output echoes those
relative paths back, which makes `.t` files portable across
machines without scrubbing. `DUNE_SOURCEROOT` is exported by
dune. Non-deterministic JSON fields (e.g. `now` timestamps) are
scrubbed with `jq -c 'del(.now)'` before comparison.

| Cram test | Obligation | Decision |
|---|---|---|
| `version.t` | mathc prints bootstrap hello on `version` | `decisions/cli-cram-tests.yaml` |
| `validate-positive.t` | valid decision accepted | `decisions/validate-and-context.yaml` |
| `validate-negative.t` | invalid decision rejected | `decisions/validate-and-context.yaml` |
| `validate-error-actionable.t` | validator names the missing required field | `archive/decisions/validator-actionable-error.yaml` |
| `validate-axiom-link.t` | MC-AXIOM-LINK-MISSING for active+empty axiom_link (T2.2) | `decisions/plan-2026-10-improvements.yaml` |
| `validate-sha-match.t` | body_sha == yaml_sha when both present (T0.2) | `decisions/plan-2026-10-improvements.yaml` |
| `validate-counterexample-required.t` | mode >= standard requires non-empty counterexample (T6.2) | `decisions/plan-2026-10-improvements.yaml` |
| `counterexample-warning.t` | validator warns when counterexample field is missing | `archive/decisions/validator-actionable-error.yaml` |
| `ambiguous-acceptance.t` | MC-AMBIGUOUS-ACCEPTANCE diagnostic | `decisions/parse-acceptance-diagnostics.yaml` |
| `malformed-acceptance.t` | MC-MALFORMED-ACCEPTANCE diagnostic | `decisions/parse-acceptance-diagnostics.yaml` |
| `context-budget.t` | context capsule JSON shape | `decisions/validate-and-context.yaml` |
| `context-budget-bound.t` | total_bytes <= budget | `decisions/validate-and-context.yaml` |
| `context-priority-order.t` | items[] priority order monotonic | `decisions/capsule-active-policy.yaml` |
| `context-required-for-gate.t` | active policy in RequiredForGate | `decisions/capsule-active-policy.yaml` |
| `context-truncated-omitted.t` | truncated:true + omitted[] with expansion | `decisions/validate-and-context.yaml` |
| `gate-scaffold.t` | gate emits documented JSON keys | `decisions/gate-decision.yaml` |
| `gate-pass.t` | gate returns pass when store has current attestation | `decisions/gate-attestation-store-fill-decision.yaml` |
| `gate-fail.t` | gate returns fail on decisive failed attestation | `decisions/gate-attestation-store-fill-decision.yaml` |
| `gate-stale.t` | gate returns stale on expired attestation | `decisions/gate-attestation-store-fill-decision.yaml` |
| `gate-v32-wired.t` | §15 phase-aware verdict wired into mathc gate | `decisions/algebra-3.2.yaml` |
| `gate-empty.t` | gate with empty store -> unknown verdict | `decisions/gate-attestation-store-fill-decision.yaml` |
| `gate-unknown-exit-3.t` | gate with empty store exits 3 (unknown != pass laundering) | `decisions/exit-code-symmetry-2026-10.yaml` |
| `gate-axiom-commit.t` | gate on axiom-only commit -> block at exhaustive mode (T3.1) | `decisions/plan-2026-10-improvements.yaml` |
| `risk-bucketing.t` | risk classification bucketed via thresholds (v3.2 §2) | `decisions/algebra-3.2.yaml` |
| `mode.t` | mathc mode computes risk+mode for paths (v3.2 §2) | `decisions/3-2-cli-catalog.yaml` |
| `re-evaluate.t` | mathc re-evaluate runs §17 oracle | `decisions/3-2-cli-catalog.yaml` |
| `re-evaluate-decisions.t` | mathc re-evaluate-decisions emits post-run verdicts + attestations (T1.2) | `decisions/plan-2026-10-improvements.yaml` |
| `rebuttals.t` | mathc rebuttals walks rebuttals/<sha>.yaml (v3.2 §10) | `decisions/3-2-cli-catalog.yaml` |
| `migration-3.2-fields.t` | migrated decisions have state=active + sha fields | `decisions/algebra-3.2.yaml` |
| `schema-extensions-3.2.t` | decisions with 3.2 fields parse via mathc validate | `decisions/algebra-3.2.yaml` |
| `self-check-pass.t` | self-check reports pass for covered subjects and unknown for the rest | `decisions/mathc-self-check-subcommand.yaml` |
| `self-check-fail.t` | self-check returns fail on broken invariant | `decisions/mathc-self-check-subcommand.yaml` |
| `self-check-unknown.t` | self-check returns unknown on infrastructure error | `decisions/mathc-self-check-subcommand.yaml` |
| `gate-waiver-scope.t` | waiver narrows to (decision, obligation) pair (T3.2) | `decisions/plan-2026-10-improvements.yaml` |
| `explain-positive.t` | explain resolves `decision:foo` to body | `decisions/mathc-explain-subcommand.yaml` |
| `explain-negative.t` | explain emits `MC-REF-UNKNOWN` on bad ref | `decisions/mathc-explain-subcommand.yaml` |
| `explain-diagnostic.t` | explain-diagnostic resolves `MC-*` codes to JSON | `decisions/plan-2026-10-improvements/t4-2.yaml` |
| `git-adapter.t` | assess runs git diff --name-only | `decisions/adapters.yaml` |
| `junit-adapter.t` | attest parses JUnit XML | `decisions/adapters.yaml` |
| `cli-time-estimate.t` | time-estimate 4 documented paths | `decisions/time-honesty.yaml` |
| `cli-time-storage.t` | session-start / record / stats pipeline | `decisions/time-honesty-storage.yaml` |
| `packages.t` | packages lists every decision + verdict | `decisions/mathc-packages-subcommand.yaml` |
| `render.t` | render produces the full dist/ tree | `decisions/site-deploy.yaml` |
| `render-mathjax-spec.t` | mathc render emits MathJax 3 deferred on spec pages (T5.2) | `decisions/plan-2026-10-improvements.yaml` |
| `applicability-envelope.t` | applicability decision tree surfaces in docs | `decisions/algebra-3.2.yaml` |
| `migrate-dry-run.t` | `mathc migrate --manifest=PATH --format=json` emits auto-translatable plan per file | `decisions/migration-mechanism-2026-10.yaml` |
| `migrate-no-changes.t` | `mathc migrate` on a tree already at the target schema is a no-op | `decisions/migration-mechanism-2026-10.yaml` |
| `migrate-malformed.t` | `mathc migrate` rejects unknown migration kind + incomplete rename-field with exit 2 | `decisions/migration-mechanism-2026-10.yaml` |
| `migrate-write.t` | `mathc migrate --write` writes sibling `<file>.migrated.yaml`; `--dry-run` does not touch the disk; original is untouched | `decisions/migration-mechanism-2026-10.yaml` |
| `migrate-bump-replay.t` | `mathc migrate --from=3.0-alpha --to=3.2` replays the first non-trivial manifest (`decisions/migrations/3.0-alpha-to-3.2.yaml`) against a synthetic legacy tree and produces zero plans against the live post-bump tree | `archive/decisions/schema-string-bump-3.0-alpha-to-3.2-2026-10.yaml` |

## Process-principles test (`tests/process_principles.ml`)

The ROADMAP P1-P7 process discipline is enforced by a single
OCaml/Alcotest executable, `tests/process_principles.ml`, registered
with `dune runtest` via `tests/dune`. Each principle is its own
labelled Alcotest case:

| Principle | What the case checks |
|---|---|
| P1 (decisions before kernel changes) | every non-meta `decisions/*.yaml`/`.md` has `schema`, `id`, `revision` frontmatter + `intent`, `commitment`, `scope`, `obligations`, `risk` body sections (per `tests/process_principles.ml:75-78`); the JSON-schema validator additionally requires `outcomes` (per `schemas/decision.json:6-9`); the two checks are independent |
| P2 (decisions paired with fixtures) | every obligation has a verifier; the verifier is a present fixture path, a kernel-test reference, a cram `.t` path, or a recognised manual-style prefix |
| P5 (cram retired) | `tests/cram/*.t` does not exist |
| P6 (pre-commit verification) | `scripts/check.sh` exists and is executable |
| P7 (honesty) | meta-assertion only; reviewed by the human maintainer |

Non-checkable principles (P3 time-box, P4 merge order) remain
manual-acceptance obligations on the same decision.

The P6 case also asserts that `scripts/dev close-branches` exists
(v3.0.0.20) and that the pre-commit hook at `.githooks/pre-commit`
is registered through `git config core.hooksPath`.

## Kernel packages (`lib/`)

| Module | Purpose | May do I/O? |
|---|---|---|
| `domain.ml` | Closed algebraic types (Decision, Obligation, ...) | No |
| `canonical.ml` | String canonicalization (RFC 8785) | No |
| `jsonl.ml` | Hand-rolled JSON parser/printer | No |
| `schema.ml` | Schema-aware field extractors | No |
| `diagnostic.ml` | `Diagnostic.t` record + renderers | No |
| `digest.ml` | SHA-256 (hand-rolled; **RFC 6234 vectors green since v3.0.0.19**) | No |
| `reference.ml` | Reference parsing (`ref:`, `parent:`) | No |
| `codec.ml` | YAML/JSON loading + value parsing (block-scalars + front-matter since v3.0.0.19) | No |
| `decision.ml` | Decision decoder (mutually recursive parsers) | No |
| `capsule.ml` | Context capsule builder + priority sort | No |
| `memory.ml` | Project memory index | No |
| `gate.ml` | Gate verdict evaluator (reads attestation store); **v3.2: `apply()` for kernel rules + phase-aware gates** | No (read-only FS reads under explicit allow-list) |
| `attestations/attestations.ml` | Attestation store reader + freshness check; **v3.2: substrate fingerprint, env_class lattice, multi-CI aggregation** | No |
| `packages.ml` | `mathc packages` aggregator (decisions + obligations + verdicts) | No |
| `render.ml` | Static site generator (HTML + nav + assets) | No (writes `dist/` via caller) |
| `risk.ml` (v3.2 NEW) | Risk classifier: 12-entry path taxonomy, impact + irreversibility, risk-to-mode threshold | No (alg §2) |
| `policy.ml` (v3.2 NEW) | Per-path policy lookup, multi-policy composition (union + data-flow transitive) | No (alg §9) |
| `rebuttal.ml` (v3.2 NEW) | Hybrid rebuttal mechanism (sibling `rebuttals/<sha>.yaml` + forge mirror + trust binding) | No (alg §10) |
| `re_evaluation.ml` (v3.2 NEW) | `re_evaluate(d, A_new)` oracle returning `Compatible | Inconclusive | StaleClaim` | No (alg §17) |
| `waiver.ml` (2026-10) | Waiver consult step: `Open_with_waiver` mapping in `lib/gate.ml` | No |
| `migrate.ml` (2026-10) | Migration manifest parser + per-file planner; pure, no I/O; drives `mathc migrate` (read-only side: the kernel never writes to decision files) | No |
| `git/git_diff.ml` | `git diff --name-only` wrapper | Yes (syscall) |
| `junit/junit.ml` | JUnit XML parser | No (pure on strings) |

## CLI packages (`bin/`)

| Module | Purpose |
|---|---|
| `Mathc.ml` | argv dispatcher + every subcommand handler (validate, verify, version, update, context, explain, explain-diagnostic, forge-verify, assess, import-junit, attest, attest-batch, time-estimate, gate, mode, rebuttals, re-evaluate, re-evaluate-decisions, self-check, gaps, negative-control, find, precommit, graph, decision-state, session-start, record, stats, packages, render, counters, init, import-adr, adopt, new-decision, telemetry, migrate, doctor, rehash) — 39 subcommands total |
| `data/time-distribution.yaml` | SWE-bench Verified (n=500, 2025-Q4) reference class for `mathc time-estimate` |

## Adapter protocol (`lib/git/`, `lib/junit/`)

Adapters live in **separate libraries** with their own `dune` files.
This isolates I/O from the pure kernel (see `OCAML_KERNEL_CONVENTIONS §10.1`).

## Schema packages (`schemas/`)

| File | Purpose |
|---|---|
| `common.json` | Shared definitions (id pattern, scope, timestamp, acceptance) |
| `decision.json` | Decision artifact schema |
| `obligation.json` | Obligation artifact schema |
| `attestation.json` | Attestation artifact schema |
| `waiver.json` | Waiver artifact schema |

## Spec packages (`spec/`)

| File | Purpose |
|---|---|
| `constitution.md` | 14 invariants; the kernel MUST preserve these |
| `domain.md` | Closed entity model; what kinds exist (prose; superseded by `kernel-contract.md` §7) |
| `semantics.md` | Operational rules (prose; superseded by `kernel-contract.md` §15) |
| `kernel-contract.md` | Formal mathematical specification of the 3.2-ideal kernel (31 sections, §0–§30) |

## Paseo console (`plugin/math-coding-console/`)

| Path | Purpose |
|---|---|
| `index.client.tsx` | The client half: workspace panel, screen, sidebar row, Command Center entries, slash command, settings screen |
| `index.server.ts` | The server half: nine RPC contracts over one kernel runner |
| `shared/contracts.ts` | The RPC contracts, and the shapes the client renders |
| `shared/verdict.ts` | The one place the verdict vocabulary is named |
| `server/kernel.ts` | The kernel readers; the path every verdict comes from |
| `server/corpus.ts` | The reader over the corpus files, for their text alone |
| `server/layout.ts` | Where the corpus lives, under either layout |
| `client/console.tsx` | The console: six views over one repository |
| `dev.sh` | The development loop: typecheck, install, reload, status |
| `scripts/probe.ts` | The console's read model, exercised without a host |

The console is a view and a control surface over the kernel. It computes no verdict of its own.
See `docs/paseo-console.md` and `decisions/paseo-console-plugin-2026-10.yaml`.

## Axiom packages (`axioms/`)

| File | Axiom | Summary |
|---|---|---|
| `index.md` | — | Entry point + table linking each axiom to kernel properties |
| `separation.md` | A0 | Kinds are distinct; chains go one way |
| `feedback.md` | A1 | Every commitment has a path to observation |
| `invariants.md` | A2 | Every invariant has an authorized recovery |
| `self-application.md` | A3 | The rules govern their own changes |
| `care.md` | A4 | Owner, consequence, accountability required |

## Open audit items (see `docs/AUDIT-0.0.11.md` for full detail)

| id | Description | Status |
|---|---|---|
| D1 | YAML `\|` block scalars (kernel-side) | **CLOSED** at v0.0.19 (`79d138b`) |
| D2 | YAML front-matter (kernel-side) | **CLOSED** at v0.0.19 (`79d138b`) |
| D4 | SHA-256 RFC vectors (kernel-side) | **CLOSED** at v0.0.19 (`d77624b`) |
| D6 | bootstrap-v3 manual-only verifiers | **CLOSED** at v0.0.20 (this release): each obligation now has a machine-checked verifier reachable from CI |
| D8 | `mathc validate` coarse diagnostics | OPEN; tracked for 3.0-beta |
| D10 | stale-worktree accumulation | CLOSED at v0.0.20 (`scripts/dev close-branches`) |

## How to use this file

A new agent should:

1. Read `ROADMAP.md` for **what to work on next** (Tier 1 → Tier 4).
2. Pick a **decision** from the table above matching the chosen task.
3. Read that decision file in full — it lists obligations, fixtures, and the active policy it depends on.
4. Read the matching fixture (or create one if missing) — fixtures are the executable acceptance gate.
5. Implement the kernel change in `lib/` only after the decision file is in `main`.
6. Run `./scripts/check.sh` before every commit; the KERNEL_AGENTS.md self-application protocol requires it.

## What this file is NOT

- **Not** a priority queue — see `ROADMAP.md`.
- **Not** a changelog — see `git tag --list | grep v3-alpha` for tags.
- **Not** a recipe — see `OCAML_KERNEL_CONVENTIONS.md` §1–§11 for OCaml conventions and traps.

## Site packages (`site/`)

The site at `site/` is the project's published surface. The site
**demonstrates** the methodology: every page that documents a
feature of the kernel is itself produced by an OCaml kernel
function, every link between pages is the same lifecycle on
artifacts, and the build pipeline is `scripts/render.sh` +
`scripts/dev render` (which calls `mathc render`).

| Source | Output | Notes |
|---|---|---|
| `render/templates/index.*.html` | `dist/index.html` | hero + axiom grid + protocol diagram |
| `site/*.md` (plus `.ru.md`, `.zh.md`) | `dist/*.html` | the prose articles: readme, manifesto, methodology, workflow, axioms, foundations, bootstrap-gate, packages, install, faq, contributing, differences |
| `axioms/*.md` | `dist/axioms/*.html` | one page per axiom |
| `decisions/*.yaml` | `dist/decisions/*.html` | one page per decision |
| `assets/style.css` | `dist/assets/style.css` | shared stylesheet |
| `assets/site.js` | `dist/assets/site.js` | navigation, mermaid init |

The site is built and deployed by `.github/workflows/site.yml`
(see `decisions/site-deploy.yaml`). Pin to `ubuntu-22.04`
(setup-ocaml/v2 needs darcs which is unavailable on 24.04).

## Versioning

This file is updated only when **a new decision file** is created or
when **an existing decision** changes revision. It is NOT updated for
every code change.

The live counters are `mathc counters --format=json`; the sync history
of this file is in `git log -- PACKAGES.md`.
