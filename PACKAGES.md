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
  `decisions/<id>-impl-pending.md`)
- **SCAFFOLD** — kernel surface exists but does not yet block

## Active policy

**`bootstrap-v3@2`** (`decisions/decision.yaml`) — the master policy
that authorises all other decisions. Its obligations are tracked in
`decisions/obligations.yaml`.

## Bootstrap packages (by file)

| File | Decision id | Rev | Obs | Status | Closes audit |
|---|---|---|---|---|---|
| `decisions/decision.yaml` | `bootstrap-v3` | 2 | 13 | RESOLVED | bootstrap protocol |
| `decisions/infrastructure-honesty.yaml` | `infrastructure-honesty` | 1 | 10 | RESOLVED | audit D5, D7 |
| `decisions/kernel-conformance-runner.yaml` | `kernel-conformance-runner` | 1 | 9 | RESOLVED | conformance runner |
| `decisions/validate-and-context.yaml` | `validate-and-context` | 2 | 13 | RESOLVED | first CLI + context capsule |
| `decisions/priority-drift.yaml` | `priority-drift` | 2 | 5 | RESOLVED | audit D3 |
| `decisions/spec-cli-catalog.yaml` | `spec-cli-catalog` | 1 | 8 | RESOLVED | audit D4 |
| `decisions/adapters.yaml` | `adapters` | 2 | 6 | RESOLVED | audit D7 (git + junit) |
| `decisions/capsule-active-policy.yaml` | `capsule-active-policy` | 1 | 7 | RESOLVED | capsule priority class |
| `decisions/gate-decision.yaml` | `gate-decision` | 1 | 7 | SCAFFOLD | mc gate (no store yet) |
| `decisions/parse-acceptance-diagnostics.yaml` | `parse-acceptance-diagnostics` | 1 | 5 | RESOLVED | kernel diagnostics |
| `decisions/time-honesty.yaml` | `time-honesty` | 1 | 8 | RESOLVED | time-honesty distribution |
| `decisions/time-honesty-storage.yaml` | `time-honesty-storage` | 1 | 9 | RESOLVED | time storage writers |
| `decisions/yaml-block-scalars.yaml` | `yaml-block-scalars` | 2 | 9 | DECISION | audit D1/D2 (impl deferred) |
| `decisions/yaml-block-scalars-impl-pending.yaml` | `yaml-block-scalars-impl-pending` | 1 | 3 | DEFERRED | records D1/D2 deferral |
| `decisions/process-principles.yaml` | `process-principles` | 2 | 7 | RESOLVED | locks ROADMAP P1-P7 as obligations |
| `decisions/cli-cram-tests.yaml` | `cli-cram-tests` | 1 | 1 | RESOLVED | replaces 14 cli-*.sh fixtures with cram .t |
| `decisions/obligations.yaml` | (aggregator) | — | — | INDEX | tracks bootstrap-v3 obligations |

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
| `ambiguous-acceptance.t` | MC-AMBIGUOUS-ACCEPTANCE diagnostic | `decisions/parse-acceptance-diagnostics.yaml` |
| `malformed-acceptance.t` | MC-MALFORMED-ACCEPTANCE diagnostic | `decisions/parse-acceptance-diagnostics.yaml` |
| `context-budget.t` | context capsule JSON shape | `decisions/validate-and-context.yaml` |
| `context-budget-bound.t` | total_bytes <= budget | `decisions/validate-and-context.yaml` |
| `context-priority-order.t` | items[] priority order monotonic | `decisions/capsule-active-policy.yaml` |
| `context-required-for-gate.t` | active policy in RequiredForGate | `decisions/capsule-active-policy.yaml` |
| `context-truncated-omitted.t` | truncated:true + omitted[] with expansion | `decisions/validate-and-context.yaml` |
| `gate-scaffold.t` | gate emits documented JSON keys | `decisions/gate-decision.yaml` |
| `git-adapter.t` | assess runs git diff --name-only | `decisions/adapters.yaml` |
| `junit-adapter.t` | attest parses JUnit XML | `decisions/adapters.yaml` |
| `cli-time-estimate.t` | time-estimate 4 documented paths | `decisions/time-honesty.yaml` |
| `cli-time-storage.t` | session-start / record / stats pipeline | `decisions/time-honesty-storage.yaml` |

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
| D1 | YAML `\|` block scalars (kernel-side) | DEFERRED via `yaml-block-scalars-impl-pending.yaml` |
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
