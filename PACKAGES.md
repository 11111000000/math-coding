# Math-coding 3.0 — Packages

> **Single source of truth for "what exists in math-coding 3.0".**
> If you are a new agent picking up this repository, this is the file
> you read first (after `ROADMAP.md`, which is the priority queue).
> Every other decision document can be read in isolation; this one
> shows you the whole picture at a glance.

Last verified at: tag `v3-alpha-0.0.14`, commit `05e2ea5`.

**Cross-references:**
- `ROADMAP.md` — priorities, tier ordering, process principles (P1–P7)
- `AGENTS.md` — agent protocol, read-first order
- `OCAML_BEST_PRACTICES.md` — OCaml conventions + trap log
- `doc/AUDIT-0.0.11.md` — open/closed deficit chain

## Status legend

- **RESOLVED** — obligation closed by implementation, fixture green
- **DECISION** — decision recorded, implementation pending
- **DEFERRED** — explicitly deferred per recorded decision (see
  `bootstrap/<id>-impl-pending.md`)
- **SCAFFOLD** — kernel surface exists but does not yet block

## Active policy

**`bootstrap-v3@2`** (`bootstrap/decision.yaml`) — the master policy
that authorises all other decisions. Its obligations are tracked in
`bootstrap/obligations.yaml`.

## Bootstrap packages (by file)

| File | Decision id | Rev | Obs | Status | Closes audit |
|---|---|---|---|---|---|
| `bootstrap/decision.yaml` | `bootstrap-v3` | 2 | 13 | RESOLVED | bootstrap protocol |
| `bootstrap/infrastructure-honesty.yaml` | `infrastructure-honesty` | 1 | 10 | RESOLVED | audit D5, D7 |
| `bootstrap/kernel-conformance-runner.yaml` | `kernel-conformance-runner` | 1 | 9 | RESOLVED | conformance runner |
| `bootstrap/validate-and-context.yaml` | `validate-and-context` | 2 | 13 | RESOLVED | first CLI + context capsule |
| `bootstrap/priority-drift.yaml` | `priority-drift` | 2 | 5 | RESOLVED | audit D3 |
| `bootstrap/spec-cli-catalog.md` | `spec-cli-catalog` | 1 | 8 | RESOLVED | audit D4 |
| `bootstrap/adapters.yaml` | `adapters` | 2 | 6 | RESOLVED | audit D7 (git + junit) |
| `bootstrap/capsule-active-policy.yaml` | `capsule-active-policy` | 1 | 7 | RESOLVED | capsule priority class |
| `bootstrap/gate-decision.yaml` | `gate-decision` | 1 | 7 | SCAFFOLD | mc gate (no store yet) |
| `bootstrap/parse-acceptance-diagnostics.yaml` | `parse-acceptance-diagnostics` | 1 | 5 | RESOLVED | kernel diagnostics |
| `bootstrap/time-honesty.yaml` | `time-honesty` | 1 | 8 | RESOLVED | time-honesty distribution |
| `bootstrap/time-honesty-storage.yaml` | `time-honesty-storage` | 1 | 9 | RESOLVED | time storage writers |
| `bootstrap/yaml-block-scalars.md` | `yaml-block-scalars` | 2 | 9 | DECISION | audit D1/D2 (impl deferred) |
| `bootstrap/yaml-block-scalars-impl-pending.md` | `yaml-block-scalars-impl-pending` | 1 | 3 | DEFERRED | records D1/D2 deferral |
| `bootstrap/process-principles.yaml` | `process-principles` | 2 | 7 | RESOLVED | locks ROADMAP P1-P7 as obligations |
| `bootstrap/obligations.yaml` | (aggregator) | — | — | INDEX | tracks bootstrap-v3 obligations |

## Fixtures (`tests/fixtures/*.sh`)

Each fixture is a shell script that exits 0 if its obligation is
satisfied. `./scripts/check.sh` runs them all and aggregates.

| Fixture | Obligation | File |
|---|---|---|
| `ambiguous-acceptance.sh` | parse handles ambiguous predicate shape | `lib/codec.ml` |
| `attestation-skip-message.sh` | attestation parser wired | `bootstrap/kernel-conformance-runner.yaml` |
| `ci-targets-exist.sh` | CI workflows reference real paths | `bootstrap/infrastructure-honesty.yaml` |
| `cli-time-estimate.sh` | `mc time-estimate` works | `bootstrap/time-honesty.yaml` |
| `cli-time-storage.sh` | `mc session-start`/`mc record` work | `bootstrap/time-honesty-storage.yaml` |
| `process-principles.sh` | ROADMAP P1, P2, P5, P6, P7 enforced | `bootstrap/process-principles.yaml` |
| `release-checksum-verified.sh` | SHA256 in CI for opam download | `bootstrap/infrastructure-honesty.yaml` |
| `yaml-block-scalars.sh` | yaml-block-scalars obligation has fixtures | `bootstrap/yaml-block-scalars.md` |
| `context-budget-bound.sh` | context budget not silently exceeded | `bootstrap/validate-and-context.yaml` |
| `context-budget.sh` | context capsule produced | `bootstrap/validate-and-context.yaml` |
| `context-priority-order.sh` | RequiredForGate > Changed > ... | `bootstrap/capsule-active-policy.yaml` |
| `context-required-for-gate.sh` | RequiredForGate classifier correct | `bootstrap/capsule-active-policy.yaml` |
| `context-truncated-omitted.sh` | omitted items listed on truncation | `bootstrap/validate-and-context.yaml` |
| `decision-parses.sh` | Decision.parse_decision works | `bootstrap/kernel-conformance-runner.yaml` |
| `digest-vectors-coverage.sh` | digest vectors are exercised | `OCAML_BEST_PRACTICES §5` |
| `dune-runs-conformance.sh` | dune test runs conformance runner | `bootstrap/kernel-conformance-runner.yaml` |
| `enumerate.sh` | kernel-conformance-runner skeleton exists | `bootstrap/kernel-conformance-runner.yaml` |
| `flake-lock-changes-record-decision.sh` | flake.lock changes are recorded | `bootstrap/infrastructure-honesty.yaml` |
| `flake-ref-is-commit.sh` | nixpkgs pinned to a commit hash | `bootstrap/infrastructure-honesty.yaml` |
| `fmt-clean.sh` | `dune fmt --check` is clean | `OCAML_BEST_PRACTICES §10.4 item 6` |
| `gate-scaffold.sh` | `mc gate` runs and emits JSON | `bootstrap/gate-decision.yaml` |
| `git-adapter.sh` | `mc assess` works via lib/git | `bootstrap/adapters.yaml` |
| `junit-adapter.sh` | `mc attest` works via lib/junit | `bootstrap/adapters.yaml` |
| `malformed-acceptance.sh` | malformed predicate shape rejected | `bootstrap/parse-acceptance-diagnostics.yaml` |
| `spec-catalog-present.sh` | spec lists current CLI subcommands | `bootstrap/spec-cli-catalog.md` |
| `spec-vs-bp-priority.sh` | priority tables in spec and practice match | `bootstrap/priority-drift.md` |
| `validate-negative.sh` | invalid decision rejected | `bootstrap/validate-and-context.md` |
| `validate-positive.sh` | valid decision accepted | `bootstrap/validate-and-context.md` |
| `waiver-parser.sh` | waiver parser wired | `bootstrap/kernel-conformance-runner.yaml` |

## Kernel packages (`lib/`)

| Module | Purpose | May do I/O? |
|---|---|---|
| `domain.ml` | Closed algebraic types (Decision, Obligation, ...) | No |
| `canonical.ml` | String canonicalization (RFC 8785) | No |
| `jsonl.ml` | Hand-rolled JSON parser/printer | No |
| `schema.ml` | Schema-aware field extractors | No |
| `diagnostic.ml` | `Diagnostic.t` record + renderers | No |
| `identifier.ml` | id / timestamp / digest parsers | No |
| `digest.ml` | SHA-256 (hand-rolled; **untested**) | No |
| `scope.ml` | Scope target parsing | No |
| `reference.ml` | Reference parsing (`ref:`, `parent:`) | No |
| `codec.ml` | YAML/JSON loading + value parsing | No |
| `decision.ml` | Decision decoder (mutually recursive parsers) | No |
| `capsule.ml` | Context capsule builder + priority sort | No |
| `memory.ml` | Project memory index | No |
| `gate.ml` | Gate verdict evaluator | No |
| `git/git_diff.ml` | `git diff --name-only` wrapper | Yes (syscall) |
| `junit/junit.ml` | JUnit XML parser | No (pure on strings) |

## CLI packages (`bin/`)

| Module | Purpose |
|---|---|
| `Mathc.ml` | argv dispatcher + every subcommand handler |

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
| `domain.md` | Closed entity model; what kinds exist |
| `semantics.md` | Operational rules (merge gate, exit codes, CLI subcommands) |

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
| D1 | YAML `\|` block scalars (kernel-side) | DEFERRED via `yaml-block-scalars-impl-pending.md` |
| D2 | YAML front-matter (kernel-side) | DEFERRED via same (bypassed in `Memory.strip_yaml_frontmatter`) |
| D4 | SHA-256 RFC vectors (kernel-side) | OPEN |
| D6 | bootstrap-v3 manual-only verifiers | TRACKED (kernel does not exist yet) |
| D8 | `mc validate` coarse diagnostics | TRACKED for 3.0-beta |

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
- **Not** a recipe — see `OCAML_BEST_PRACTICES.md §1–§11` for OCaml conventions and traps.

## Versioning

This file is updated only when **a new decision file** is created or
when **an existing decision** changes revision. It is NOT updated for
every code change.

Last updated at: `v3-alpha-0.0.14` (commit `05e2ea5`).
