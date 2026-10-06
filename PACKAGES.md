# Math-coding 3.0 — Packages

> **Single source of truth for "what exists in math-coding 3.0".**
> If you are a new agent picking up this repository, this is the file
> you read first (after `ROADMAP.md`, which is the priority queue).
> Every other decision document can be read in isolation; this one
> shows you the whole picture at a glance.

Last verified at: HEAD `6a7c8e4` + Step 3 of the 2026-10 waiver
infrastructure (lib/waiver.ml lands, first waiver covers
`portable-linux-musl`; 2026-10-06).
Attestation store at `attestations/` contains **126 files** (verified by
`scripts/dev-counters.py`; the count is regenerated from `ls attestations/`
on every check); **`mathc packages` reports 33 active decisions / 129
obligations (116 pass, 12 missing, 1 unknown; the master policy's 7
obligations are enumerated separately)**. The exact numbers
are emitted by `scripts/dev-counters.py` and enforced against
`PACKAGES.md`, `ROADMAP.md`, `README.md` by `tests/counters_drift.ml`.

`mathc self-check` on a clean tree currently returns verdict `unknown` with
36 pass / 2 unknown out of 38 subjects. The 2 remaining unknown subjects are:
- `audit-0.0.21-fixes` (8 of 9 obligations have attestations; the 9th,
  `self-check-verdict-is-pass`, has an `inconclusive` attestation
  because the criterion cannot be satisfied while any subject
  contributes to `unknown`. Resolution: a separate waiver file
  per obligation — out of scope for Step 3; waiver record in
  `decisions/audit-0.0.21-fixes-self-check-waiver-2026-10.yaml`)
- `cli-canonical-name` (introduced by `83c3441`; 4 of its obligations
  have no attestations in the store. Not in scope — recorded
  here as an open deficit rather than closed by a fabricated
  attestation.)

`portable-linux-musl` was previously unknown (its 7 obligations have
no attestations because the Alpine CI build never succeeded and the
decision is in `state: retired`; reversal signal
`alpine-ci-build-fails` fired per `decisions/portable-linux-musl.yaml`).
Step 3 closes this subject via the new waiver file
`decisions/waivers/portable-linux-musl-2026-10.yaml`, which maps
the 4 structurally-unreachable obligations to
`Open_with_waiver` (CLI verdict: `pass`) until 2027-04-06.

The `mathc self-check` pass-fixture at
`tests/fixtures/self-check-pass/attestations` is regenerated to match
the current obligation set; the cram snapshot at
`tests/cli/self-check-pass.t` reflects the actual verdict.

**Cross-references:**
- `ROADMAP.md` — priorities, tier ordering, process principles (P1–P7)
- `AGENTS.md` — agent protocol, read-first order
- `OCAML_BEST_PRACTICES.md` — OCaml conventions + trap log
- `doc/AUDIT-0.0.11.md` — open/closed deficit chain

## Status legend

- **RESOLVED** — obligation closed by implementation, fixture green
- **DECISION** — decision recorded, implementation pending
- **DEFERRED** — explicitly deferred per recorded decision (see
  `decisions/<id>-impl-pending.md`)
- **SCAFFOLD** — kernel surface exists but does not yet block

## Active policy

**`bootstrap-v3@2`** (`decisions/decision.yaml`) — the master policy
that authorises all other decisions. Its obligations are tracked in
`decisions/obligations.yaml`.

## Bootstrap packages (by file)

| File | Decision id | Rev | Obl | Status | Closes audit |
|---|---|---|---|---|---|
| `decisions/decision.yaml` | `bootstrap-v3` | 3 | 7 | RESOLVED | bootstrap protocol |
| `decisions/infrastructure-honesty.yaml` | `infrastructure-honesty` | 2 | 4 | RESOLVED | audit D5, D7 |
| `decisions/kernel-conformance-runner.yaml` | `kernel-conformance-runner` | 2 | 4 | RESOLVED | conformance runner |
| `decisions/validate-and-context.yaml` | `validate-and-context` | 3 | 6 | RESOLVED | first CLI + context capsule |
| `decisions/priority-drift.yaml` | `priority-drift` | 3 | 2 | RESOLVED | audit D3 |
| `decisions/spec-cli-catalog.yaml` | `spec-cli-catalog` | 2 | 2 | RESOLVED | audit D4 |
| `decisions/adapters.yaml` | `adapters` | 3 | 2 | RESOLVED | audit D7 (git + junit) |
| `decisions/capsule-active-policy.yaml` | `capsule-active-policy` | 2 | 3 | RESOLVED | capsule priority class |
| `decisions/gate-decision.yaml` | `gate-decision` | 2 | 2 | RESOLVED | mathc gate verdict against populated store |
| `decisions/gate-attestation-store-fill-decision.yaml` | `gate-attestation-store-fill` | 2 | 4 | RESOLVED | Tier-1 #1 (closed in `ed42290`) |
| `decisions/attestation-store-fill.yaml` | `attestation-store-fill` | 3 | 2 | RESOLVED | populates `attestations/` (75 files) |
| `decisions/mathc-explain-subcommand.yaml` | `mathc-explain-subcommand` | 3 | 2 | RESOLVED | Tier-A (closed in `6e922d3`) — broken promise from `omitted[].expansion` resolved |
| `decisions/mathc-self-check-subcommand.yaml` | `mathc-self-check-subcommand` | 4 | 3 | RESOLVED | Tier-1 #2 (closed in `758f340`) |
| `decisions/parse-acceptance-diagnostics.yaml` | `parse-acceptance-diagnostics` | 2 | 2 | RESOLVED | kernel diagnostics |
| `decisions/time-honesty.yaml` | `time-honesty` | 2 | 3 | RESOLVED | time-honesty distribution |
| `decisions/time-honesty-storage.yaml` | `time-honesty-storage` | 2 | 4 | RESOLVED | time storage writers |
| `decisions/yaml-block-scalars.yaml` | `yaml-block-scalars` | 5 | 2 | RESOLVED | audit D1/D2 (closed in `79d138b`, v3.0.0.19) |
| `decisions/yaml-block-scalars-impl-pending.yaml` | `yaml-block-scalars-impl-pending` | 3 | 1 | RESOLVED | records D1/D2 deferral, superseded by yaml-block-scalars@4 |
| `decisions/validator-actionable-error.yaml` | `validator-actionable-error` | 1 | 3 | RESOLVED | D8 actionable validator error: missing-field name in diagnostic |
| `decisions/process-principles.yaml` | `process-principles` | 3 | 7 | RESOLVED | locks ROADMAP P1-P7 as obligations |
| `decisions/D6-bootstrap-v3-verifiers-implemented.yaml` | `D6-bootstrap-v3-verifiers-implemented` | 2 | 1 | RESOLVED | closes D6 (manual-only verifiers) per AUDIT-0.0.20 |
| `decisions/portable-linux-musl.yaml` | `portable-linux-musl` | 3 | 7 | RETIRED | attempted algebra-3.2 §30 closure via Alpine container build; CI runs #81/#83/#84/#85 broke on opam setup; reversal signal `alpine-ci-build-fails` fired per the decision file. Re-enable when Alpine image debugged. |
| `decisions/agent-onboarding.yaml` | `agent-onboarding` | 2 | 4 | RESOLVED | locks ADR location + first-file convention |
| `decisions/formal-verifier-conventions.yaml` | `formal-verifier-conventions` | 2 | 2 | RESOLVED | locks tla:/coq:/alloy: prefix convention (no tool added) |
| `decisions/cli-cram-tests.yaml` | `cli-cram-tests` | 2 | 1 | RESOLVED | replaces 14 cli-*.sh fixtures with cram .t |
| `decisions/site-deploy.yaml` | `site-deploy` | 5 | 11 | RESOLVED | restores the project's published surface under its own gate |
| `decisions/cli-canonical-name.yaml` | `cli-canonical-name` | 2 | 5 | RESOLVED | collapses mc/mathc/mathc.exe CLI referents into one |
| `decisions/3-2-cli-catalog.yaml` | `3-2-cli-catalog` | 2 | 7 | RESOLVED | closes 3.2-cli-catalog drift (mode, rebuttals, re-evaluate subcommands added) |
| `decisions/algebra-3.2.yaml` | `algebra-3.2` | 2 | 7 | RESOLVED | adopts `spec/algebra-3.2.md` as formal normative spec |
| `decisions/audit-0.0.21-fixes.yaml` | `audit-0.0.21-fixes` | 2 | 9 | RESOLVED | master decision for the integrity-fixes cycle (Phase 1-5) |
| `decisions/ci-blocking-list-config.yaml` | `ci-blocking-list-config` | 2 | 2 | RESOLVED | configurable blocking-CI list via MATH_CODING_BLOCKING_CIS |
| `decisions/process-principles-close-branches.yaml` | `process-principles-close-branches` | 3 | 3 | RESOLVED | close-branches subcommand and pre-commit hook (process-principles@2 P2 detail) |
| `decisions/mathc-packages-subcommand.yaml` | `mathc-packages-subcommand` | 3 | 3 | RESOLVED | Tier-1 #4 |
| `decisions/obligation-count-reconcile.yaml` | `obligation-count-reconcile` | 3 | 2 | RESOLVED | aligns PACKAGES.md counts with `obligations.yaml` |
| `decisions/spec-prose-corrections-2026-10.yaml` | `spec-prose-corrections-2026-10` | 2 | 3 | RESOLVED | factual corrections to spec/algebra-3.2.md and spec/semantics.md (2026-10-05 audit F7, F11) |
| `decisions/algebra-3.2-notation-flag-2026-10.yaml` | `algebra-3.2-notation-flag-2026-10` | 2 | 2 | RESOLVED | flags ambiguous `⌈risk(c)⌉` notation in algebra §2 (2026-10-05 audit F9) |
| `decisions/schema-empty-sha-2026-10.yaml` | `schema-empty-sha-2026-10` | 3 | 2 | RETIRED | schema relaxation for empty-string `body_sha`/`yaml_sha` stubs; not counted as active decision |
| `decisions/audit-0.0.21-fixes-self-check-waiver-2026-10.yaml` | `audit-0.0.21-fixes-self-check-waiver-2026-10` | 2 | 3 | META | waiver record for the structural deficit on `self-check-verdict-is-pass`; not counted as active decision |
| `decisions/portable-linux-musl-retirement-record-2026-10.yaml` | `portable-linux-musl-retirement-record-2026-10` | 1 | 1 | META | records 3/7 obligations attested + 4/7 structurally held by reversal signal; not a waiver, not counted as active decision |
| `decisions/waiver-infrastructure-2026-10.yaml` | `waiver-infrastructure-2026-10` | 1 | 2 | META | introduces `lib/waiver.ml` + the consult step in `bin/Mathc.ml`; first waiver file `decisions/waivers/portable-linux-musl-2026-10.yaml`; not counted as active decision (no kernel surface) |
| `decisions/obligations.yaml` | (aggregator) | — | — | INDEX | tracks bootstrap-v3 obligations |

**Column key.** `Obl` = current obligation count for that decision
(counted via `python3 -c "import re,glob; ..."` against the
`obligations:` block of the YAML; equivalent to `mathc packages
--format=json` per-decision count, modulo unknown-filtered
obligations). The earlier `Obs` column showed a pre-3.2 snapshot that
drifted during the algebra-3.2 migration; the `Obs` label has been
removed in this revision and replaced with the live count, with the
script-derived value as the canonical source.

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
| `validate-error-actionable.t` | validator names the missing required field | `decisions/validator-actionable-error.yaml` |
| `counterexample-warning.t` | validator warns when counterexample field is missing | `decisions/validator-actionable-error.yaml` |
| `ambiguous-acceptance.t` | MC-AMBIGUOUS-ACCEPTANCE diagnostic | `decisions/parse-acceptance-diagnostics.yaml` |
| `malformed-acceptance.t` | MC-MALFORMED-ACCEPTANCE diagnostic | `decisions/parse-acceptance-diagnostics.yaml` |
| `context-budget.t` | context capsule JSON shape | `decisions/validate-and-context.yaml` |
| `context-budget-bound.t` | total_bytes <= budget | `decisions/validate-and-context.yaml` |
| `context-priority-order.t` | items[] priority order monotonic | `decisions/capsule-active-policy.yaml` |
| `context-required-for-gate.t` | active policy in RequiredForGate | `decisions/capsule-active-policy.yaml` |
| `context-truncated-omitted.t` | truncated:true + omitted[] with expansion | `decisions/validate-and-context.yaml` |
| `gate-scaffold.t` | gate emits documented JSON keys | `decisions/gate-decision.yaml` |
| `gate-pass.t` | gate returns pass when store has current attestation | `decisions/gate-attestation-store-fill.yaml` |
| `gate-fail.t` | gate returns fail on decisive failed attestation | `decisions/gate-attestation-store-fill.yaml` |
| `gate-stale.t` | gate returns stale on expired attestation | `decisions/gate-attestation-store-fill.yaml` |
| `gate-empty.t` | gate with empty store -> unknown verdict | `decisions/gate-attestation-store-fill.yaml` |
| `mode.t` | mathc mode computes risk+mode for paths (v3.2 §2) | `decisions/3-2-cli-catalog.yaml` |
| `re-evaluate.t` | mathc re-evaluate runs §17 oracle | `decisions/3-2-cli-catalog.yaml` |
| `rebuttals.t` | mathc rebuttals walks rebuttals/<sha>.yaml (v3.2 §10) | `decisions/3-2-cli-catalog.yaml` |
| `migration-3.2-fields.t` | migrated decisions have state=active + sha fields | `decisions/algebra-3.2.yaml` |
| `schema-extensions-3.2.t` | decisions with 3.2 fields parse via mathc validate | `decisions/algebra-3.2.yaml` |
| `self-check-pass.t` | self-check returns pass on clean HEAD | `decisions/mathc-self-check-subcommand.yaml` |
| `self-check-fail.t` | self-check returns fail on broken invariant | `decisions/mathc-self-check-subcommand.yaml` |
| `self-check-unknown.t` | self-check returns unknown on infrastructure error | `decisions/mathc-self-check-subcommand.yaml` |
| `explain-positive.t` | explain resolves `decision:foo` to body | `decisions/mathc-explain-subcommand.yaml` |
| `explain-negative.t` | explain emits `MC-REF-UNKNOWN` on bad ref | `decisions/mathc-explain-subcommand.yaml` |
| `git-adapter.t` | assess runs git diff --name-only | `decisions/adapters.yaml` |
| `junit-adapter.t` | attest parses JUnit XML | `decisions/adapters.yaml` |
| `cli-time-estimate.t` | time-estimate 4 documented paths | `decisions/time-honesty.yaml` |
| `cli-time-storage.t` | session-start / record / stats pipeline | `decisions/time-honesty-storage.yaml` |
| `packages.t` | packages lists every decision + verdict | `decisions/mathc-packages-subcommand.yaml` |
| `render.t` | render produces the full dist/ tree | `decisions/site-deploy.yaml` |
| `applicability-envelope.t` | applicability decision tree surfaces in docs | `decisions/algebra-3.2.yaml` |

## Process-principles test (`tests/process_principles.ml`)

The ROADMAP P1-P7 process discipline is enforced by a single
OCaml/Alcotest executable, `tests/process_principles.ml`, registered
with `dune runtest` via `tests/dune`. Each principle is its own
labelled Alcotest case:

| Principle | What the case checks |
|---|---|
| P1 (decisions before kernel changes) | every non-meta `decisions/*.yaml`/`.md` has `schema`, `id`, `revision` frontmatter + `intent`, `commitment`, `scope`, `obligations`, `risk` body sections |
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
| `identifier.ml` | id / timestamp / digest parsers | No |
| `digest.ml` | SHA-256 (hand-rolled; **RFC 6234 vectors green since v3.0.0.19**) | No |
| `scope.ml` | Scope target parsing | No |
| `reference.ml` | Reference parsing (`ref:`, `parent:`) | No |
| `codec.ml` | YAML/JSON loading + value parsing (block-scalars + front-matter since v3.0.0.19) | No |
| `decision.ml` | Decision decoder (mutually recursive parsers) | No |
| `capsule.ml` | Context capsule builder + priority sort | No |
| `memory.ml` | Project memory index | No |
| `gate.ml` | Gate verdict evaluator (reads attestation store); **v3.2: `apply()` for kernel rules + phase-aware gates** | No (read-only FS reads under explicit allow-list) |
| `attestations.ml` | Attestation store reader + freshness check; **v3.2: substrate fingerprint, env_class lattice, multi-CI aggregation** | No |
| `self_check.ml` | (n/a — self-check logic lives in `bin/Mathc.ml`; see **v3.2** subcommand table below) | No |
| `packages.ml` | `mathc packages` aggregator (decisions + obligations + verdicts) | No |
| `render.ml` | Static site generator (HTML + nav + assets) | No (writes `dist/` via caller) |
| `risk.ml` (v3.2 NEW) | Risk classifier: 12-entry path taxonomy, impact + irreversibility, risk-to-mode threshold | No (alg §2) |
| `policy.ml` (v3.2 NEW) | Per-path policy lookup, multi-policy composition (union + data-flow transitive) | No (alg §9) |
| `rebuttal.ml` (v3.2 NEW) | Hybrid rebuttal mechanism (sibling `rebuttals/<sha>.yaml` + forge mirror + trust binding) | No (alg §10) |
| `re_evaluation.ml` (v3.2 NEW) | `re_evaluate(d, A_new)` oracle returning `Compatible | Inconclusive | StaleClaim` | No (alg §17) |
| `git/git_diff.ml` | `git diff --name-only` wrapper | Yes (syscall) |
| `junit/junit.ml` | JUnit XML parser | No (pure on strings) |

## CLI packages (`bin/`)

| Module | Purpose |
|---|---|
| `Mathc.ml` | argv dispatcher + every subcommand handler (validate, context, explain, assess, attest, gate, version, session-start, record, stats, time-estimate, self-check, render, packages, mode, rebuttals, re-evaluate) — 17 subcommands total |
| `data/time-distribution.yaml` | SWE-bench Verified (n=500, 2025-Q4) reference class for `mathc time-estimate` |

## Adapter protocol (`lib/git/`, `lib/junit/`)

Adapters live in **separate libraries** with their own `dune` files.
This isolates I/O from the pure kernel (see `OCAML_BEST_PRACTICES §10.1`).

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
| `domain.md` | Closed entity model; what kinds exist (prose; superseded by `algebra-3.2.md` §7) |
| `semantics.md` | Operational rules (prose; superseded by `algebra-3.2.md` §15) |
| `algebra-3.2.md` | Formal mathematical specification of the 3.2-ideal kernel (30 sections) |

## Axiom packages (`axioms/`)

| File | Axiom | Summary |
|---|---|---|
| `index.md` | — | Entry point + table linking each axiom to kernel properties |
| `separation.md` | A0 | Kinds are distinct; chains go one way |
| `feedback.md` | A1 | Every commitment has a path to observation |
| `invariants.md` | A2 | Every invariant has an authorized recovery |
| `self-application.md` | A3 | The rules govern their own changes |
| `care.md` | A4 | Owner, consequence, accountability required |

## Open audit items (see `doc/AUDIT-0.0.11.md` for full detail)

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
6. Run `./scripts/check.sh` before every commit; the AGENTS.md self-application protocol requires it.

## What this file is NOT

- **Not** a priority queue — see `ROADMAP.md`.
- **Not** a changelog — see `git tag --list | grep v3-alpha` for tags.
- **Not** a recipe — see `OCAML_BEST_PRACTICES.md` §1–§11 for OCaml conventions and traps.

## Site packages (`site/`)

The site at `site/` is the project's published surface. The site
**demonstrates** the methodology: every page that documents a
feature of the kernel is itself produced by an OCaml kernel
function, every link between pages is the same lifecycle on
artifacts, and the build pipeline is `scripts/render.sh` +
`scripts/dev render` (which calls `mathc render`).

| Source | Output | Notes |
|---|---|---|
| `site/index.md` | `dist/index.html` | hero + axiom grid + protocol diagram |
| `site/axioms.md` | `dist/axioms.html` | A0–A4 with formal statements |
| `site/methodology.md` | `dist/methodology.html` | mathcoding (the methodology) explained |
| `site/bootstrap-gate.md` | `dist/bootstrap-gate.html` | the bootstrap-expiry story |
| `site/packages.md` | `dist/packages.html` | mirror of `mathc packages --format=html` |
| `site/decisions/` | `dist/decisions/*.html` | one page per `decisions/*.yaml` |
| `site/axioms/*.md` | `dist/axioms/*.html` | one page per axiom |
| `assets/style.css` | `dist/assets/style.css` | shared stylesheet |
| `assets/site.js` | `dist/assets/site.js` | navigation, mermaid init |

The site is built and deployed by `.github/workflows/site.yml`
(see `decisions/site-deploy.yaml`). Pin to `ubuntu-22.04`
(setup-ocaml/v2 needs darcs which is unavailable on 24.04).

## Versioning

This file is updated only when **a new decision file** is created or
when **an existing decision** changes revision. It is NOT updated for
every code change.

Last updated at: HEAD `83c3441` + Phase 4b (2026-10-05): real sha256
computed for all 37 decision files carrying body_sha/yaml_sha,
schema re-tightened to `^sha256:[0-9a-f]{64}$`,
`schema-empty-sha-2026-10` retired at rev 3, and the
`cli-rename-mc-to-mathc` row corrected to the real filename
`cli-canonical-name.yaml`.

Previous: HEAD `50b8cd3` (Phases 1-5 of 2026-10-05 analysis
applied: mathoding→mathcoding, editorial cleanup, spec prose
corrections, audit-0.0.21-fixes deficit closure, schema
relaxation, §27 proof completion, §2 notation flag; 2026-10-05).
