# Math-coding 3.0-alpha — ROADMAP

> **Status (2026-09-27, post-v3-alpha-0.0.11):** alpha kernel in place
> for 14 of 14 constitution invariants; CLI surface complete (validate,
> context, assess, attest, gate scaffold, time-estimate, session-start,
> record, stats); 24 shell fixtures green on `scripts/dev verify`.
>
> **Author:** Petr Kosov <p.b.kosov@yandex.ru>
> **License:** Apache-2.0 (see `LICENSE`, `NOTICE`)
> **Active policy:** `bootstrap-v3@2` (see `bootstrap/decision.yaml`)

This document is the **single source of truth** for what math-coding 3.0
is doing, what it is not yet doing, and in what order the remaining
work should land. It supersedes ad-hoc "critical analysis" reports and
inline AGENTS.md priority lists; AGENTS.md defers to this file.

## Working chain (recap)

```text
intent -> decision -> obligation -> change -> attestation -> revision
```

Every commit on `main` must close at least one obligation. No obligation
closes without a positive + negative fixture. No kernel change ships
without a `bootstrap/*.yaml` decision under the active policy.

## Priority queue (highest leverage first)

### Tier 1 — protocol becomes executable

| # | Task | Decision | Why |
|---|---|---|---|
| 1 | `gate-attestation-store-fill` | (planned) `gate-attestation-store-fill@1` | Without an attestation store, `mc gate` returns `unknown` for every obligation. The gate is the only kernel primitive that can block merges; today it's a scaffold. |
| 2 | `mc self-check` | (depends on #1) | Bootstrap expires when `mc self-check` checks this repository. Until then every assessment is a manual declaration, not an automated guarantee (see AGENTS.md). |

### Tier 2 — process hardening (one-time)

| # | Task | Effort | Closes |
|---|---|---|---|
| 3 | CI hook on PR (`.github/workflows/ci.yml`) | small | every merge to `main` runs `scripts/dev verify` in a fresh runner |
| 4 | Branch-hygiene script (`scripts/dev close-branches`) | small | stops stale worktree accumulation |
| 5 | Decision-fixture co-commit pre-commit hook | small | stops "decision without implementation" + "implementation without decision" drift |

### Tier 3 — close specific audit deficits

| # | Deficit | Status | Notes |
|---|---|---|---|
| 6 | D1/D2 (yaml-block-scalars impl) | **deferred**; decision @rev2 in main, implementation pending | `bootstrap/yaml-block-scalars-impl-pending.yaml` records the deferral with rationale |
| 7 | D5 (stale `bin/mathc_main.ml`) | **closed** in commit `191d1af` | |
| 8 | D7 (adapters decision covers two obligations) | **closed** in commit `be5c4bd` | |
| 9 | D3 (priority-drift detector) | **closed** in commit `4855a57` | |
| 10 | D4 (spec-cli-catalog) | **closed** in commit `2c2a032` | |

### Tier 4 — kernel enrichment (after Tier 1)

- OCaml types to replace `lib/domain.ml` strings (`id` phantom types)
- Decision validation against schema (currently parser-only)
- `mc explain <decision-id>` (read the kernel verdict for a single decision)
- Multi-policy hierarchy (activation boundary per spec/semantics.md §"Protected Policy Transition")

## Process principles (binding on all agents)

These are derived from the dialectical analyses accumulated across
2026-09-27 sessions. Each principle cites the failure mode it
prevents.

### P1. Decisions before kernel changes

A change to `lib/*.ml`, `spec/*.md`, `schemas/*.json`, or `bin/Mathc.ml`
ships with a `bootstrap/*.yaml` decision under the active policy.
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

1. **Decisions** (bootstrap/*.yaml) — never conflict
2. **Tests/fixtures** — additive, low conflict
3. **lib/ pure helpers** — additive at the type level
4. **bin/Mathc.ml** — touches dispatcher; merge last
5. **OCaml build fixes** (build artifacts, lockfiles) — own commit

### P5. Cram is retired; shell fixtures only

`tests/cram/*.t` were removed in `dc78bcd`. New CLI tests go in
`tests/fixtures/cli-<sub>.sh` per the pattern in `cli-time-estimate.sh`
and `cli-time-storage.sh`. **Rationale:** dune 3.23 cram sandbox does
not expose `_build/default/bin/mathc.exe` (see OCAML_BEST_PRACTICES
§11.22 RETIRED).

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

## What math-coding 3.0 is NOT

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
- `bootstrap/decision.yaml` — the active policy
- `doc/AUDIT-0.0.11.md` — the open/closed audit chain
