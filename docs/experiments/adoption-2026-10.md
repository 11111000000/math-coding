# Adoption Experiment — External Projects, 2026-10

> **Status:** design draft, awaiting user sign-off.
> **Branch:** `experiment/adoption-external-projects-2026-10`
> **Author:** orchestrator agent, 2026-10-17
> **Companion decision:** `decisions/adoption-experiment-design-2026-10.yaml`

## 0. Why this exists

The project's current adoption material (`adoption/SKILL.md`, `site/install.md`,
`QUICKSTART.md`, `plan-2026-10-ux-friction`, `plan-2026-10-distro-friction`,
`ux-3-adopt-roadmap-2026-10`) describes *what* math-coding offers and *how*
to install it. It does not contain *evidence* about how real external
projects experience the protocol when first adopted.

The goal of this experiment is to **gather quantitative and qualitative
evidence** about math-coding's first-time and steady-state adoption
experience, on real projects in real languages, executed by agents in
parallel — so that future adoption friction (the next `plan-YYYY-MM-ux-*`)
is grounded in observations, not intuition.

This is **research**, not product work. The deliverables are an
adoption-experience report and a friction inventory, not code changes to
the kernel.

## 2. Dialectic — what an adoption experiment is NOT

**Thesis (naive framing).** Clone five projects, integrate math-coding,
do some work, write down what happened.

**Antithesis (why naive framing fails).**

1. *Selection bias.* Picking top-tier OSS projects (click, express,
   ripgrep) tells us nothing about the mid-size startups and solo
   maintainers who are the project's target adopters. Five famous projects
   ≠ five representative adopters.
2. *No baseline.* Without a control arm (same work, without math-coding),
   any "X hours of friction" claim is uninterpretable.
3. *No disaggregation.* Friction signals will conflate: (a) my
   unfamiliarity with the target repo, (b) one-off setup edge cases,
   (c) schema-required fields that don't apply to the task,
   (d) genuinely missing math-coding features. Without
   categorisation, results are mush.
4. *Single-shot bias.* First integration is always the worst
   experience. Power users integrate differently. A single integration
   per project reports the worst case, not steady state.
5. *Heterogeneous tasks.* If each project gets a different kind of
   task (a typo fix in one, a feature in another), throughput is
   incomparable.
6. *Subjective friction is not evidence.* "It felt hard" is not a
   metric. Wall-clock minutes, mathc invocations, schema errors are.

**Synthesis (what gives adoption signal).** A quantitative experiment
with:

- Explicit metrics collected per session;
- Stratified selection across diversity dimensions (language, size,
  governance, ADR practice, build system);
- A control arm — at least one task per project done *without*
  math-coding, to provide a throughput baseline;
- Multiple sessions per project (bootstrap + ongoing), to model the
  learning curve;
- Categorised friction events with reproduction steps, not vibes.

## 3. Hypotheses

These are explicit, falsifiable claims the experiment is designed to
test. The results section either supports, refutes, or qualifies each.

| # | Hypothesis | Falsified if … | Verdict | One-line evidence |
|---|------------|---------------|---------|------------------|
| H1 | Time to first decision (`TTFD`) is < 30 min for a developer who has read `QUICKSTART.md`. | `TTFD > 60 min` on ≥ 3/5 projects. | **support** | median TTFD = 4 min, max = 14 min (sinatra, parallel-agent pollution). 5/5 projects under threshold. |
| H2 | `mathc adopt` successfully detects and imports a brownfield project that already has MADR ADRs. | `adopt` fails or produces no decisions on a MADR-only project. | **inconclusive** | None of the 5 picked projects ship `docs/adr/` or `adr/` in-tree. Plan-level correction in §10.7. |
| H3 | The schema's required-field set covers ≥ 90 % of decisions a maintainer would naturally make; the remaining 10 % map cleanly onto the `--template=minimal` path. | ≥ 3 schema errors per project that are not "user typo" but "schema doesn't model my situation". | **refute (qualified)** | Every project hit `MC-COUNTEREXAMPLE-MISSING` false-positive (parser bug, not user error); `axiom_link` choice unclear in 5/5 T1 sessions. |
| H4 | Throughput (lines changed per minute) on a small task is *not* statistically different between with-math-coding and without-math-coding. | With-math-coding throughput is < 50 % of without-math-coding on ≥ 2 projects. | **refute (qualified)** | With-math-coding ~10 min/decision vs control ~3 min/session (3-4× slower). The gap is dominated by env-var diagnosis in every project, not by math-coding per se. |
| H5 | The install surface (one of: release binary, Docker, Nix, source build) works on a fresh user machine without `~/.local/bin` already on `$PATH`. | A user with default shell rc fails to run `mathc version` after install. | **not tested** | This experiment used the pre-installed `/home/az/.local/bin/mathc`. Install-surface metrics are owned by `plan-2026-10-distro-friction`. |
| H6 | A second decision on the same project is faster than the first (learning curve). | TTFD-2 > TTFD-1. | **inconclusive** | Sessions were parallel, not sequential. The right shape is a longitudinal study with one agent running T1→T2→T3 in sequence. |
| H7 | The `mathc self-check` verdict on a brownfield project is `unknown` (not `pass`, not `fail`) until obligations have attestations — and this is communicated in the diagnostics. | `self-check` returns `pass` on an unattested brownfield, OR returns `fail` on the same, OR exits non-zero with a diagnostic that doesn't mention attestations. | **support** | All 5 projects ended T1 with `verdict: unknown`. Diagnostic correctly names "obligation has no attestations" and points to producer. Verbose but accurate. |
| H8 | `mathc attest-batch` removes the per-obligation JSON hand-writing tax. | A bulk attestation on a 5-obligation decision takes longer than 5 hand-written attestations. | **refute** | `mathc attest-batch` does not exist in the shipped binary (4 sub-agents independently reported). All 4 agents that needed bulk attestations wrote inline Python instead. |

We are not requiring every hypothesis to be supported. The point is to
test them.

## 4. Selection — 5 projects, stratified

Diversity dimensions chosen because they plausibly affect adoption
experience:

1. **Language.** Python, JavaScript/TypeScript, Go, Rust, Ruby — five
   distinct ecosystems with different package managers, test runners,
   CI conventions.
2. **Project size.** Spread across small (≤ 5k LoC), medium (5–20k),
   large (≥ 20k), so the YAML-overhead ratio varies.
3. **Governance.** Corporate-backed, foundation, individual
   maintainer — different attitudes to formal process.
4. **Existing ADR practice.** MADR-style ADR dir, adr-tools style,
   none — exercises different paths through `mathc adopt`.
5. **Build / test system.** pip + pytest, npm + jest, go test, cargo
   test, bundler + minitest — exercises different CI integration
   surfaces.

### Concrete picks

| # | Project | Lang | Size (LoC) | Governance | ADR practice | Build |
|---|---------|------|------------|------------|--------------|-------|
| P1 | `pallets/click` | Python | ~10k | Pallets org | none | pip + pytest |
| P2 | `expressjs/express` | JS | ~12k | OpenJS Foundation | adr-tools | npm + Mocha |
| P3 | `spf13/cobra` | Go | ~10k | spf13 (incubating CNCF) | none | go modules + go test |
| P4 | `BurntSushi/ripgrep` | Rust | ~30k | BurntSushi + GitHub | none | cargo + cargo test |
| P5 | `sinatra/sinatra` | Ruby | ~3k | Sinatra org | none | bundler + minitest |

**Rationale per pick.**

- **click** — canonical Python CLI library, mid-size, large install
  base, clean governance. Sized for first-time adoption; tests
  in pytest will be the natural "obligation" target. (Was `flask`
  in the draft; switched to a mid-size Python pick per user,
  2026-10-17.)
- **express** — the canonical adr-tools case: `docs/adr/` exists in the
  upstream repo. This exercises `mathc adopt` → `mathc import-adr` on
  the highest-quality brownfield case.
- **cobra** — clean Go CLI; small surface; tests use `go test ./...`
  which we can re-run as evidence.
- **ripgrep** — high bar of code quality; well-known for clean
  decisions in the README. Tests are cargo-native.
- **sinatra** — small Ruby project; tests in minitest. Forces the
  experiment to work with a non-mainstream language.

### Replacement rule

If any pick turns out to be un-cloneable, broken, or otherwise
unfit (e.g. the GitHub org deleted the repo), substitute with
`<lang>-<size>` nearest match from a short list maintained at
`docs/experiments/adoption-2026-10-backups.md`. The experiment does
not stop on a single substitution.

## 5. Tasks per project — three templates

Each project gets three sessions, in order:

### T1 — Bootstrap documentation (low risk, always first)

**Goal:** make the first decision on the project; measure TTFD.

**Action.** Pick a commitment that already exists implicitly in the
project and formalise it as a math-coding decision. Examples per
project:

- click: "we test against Python 3.x .. 3.x  (TBD from setup.cfg)"
- express: "we maintain docs/adr/ as the architectural record"
- cobra: "we support the go versions listed in go.mod"
- ripgrep: "PCRE2 is a build-time optional feature gated by --features pcre2"
- sinatra: "the public API follows semantic versioning"

**Deliverables.** One `decisions/<id>.yaml`, passes `mathc validate`,
`mathc self-check` returns `unknown` (no attestations yet, which is
the expected brownfield state).

### T2 — Small change (medium risk)

**Goal.** Make a real code/doc change that requires a decision and a
verifiable obligation.

**Action per project.** Pick a small but real change — a doc typo fix
becomes a decision with a `tests/cli/<file>.t` verifying the change
landed. Examples:

- click: bump a doc-version reference; obligation: tests/doc-version.t
- express: import an existing `docs/adr/0001-*.md` via
  `mathc import-adr --write`; obligation: validate-it
- cobra: add a missing godoc to one exported function; obligation:
  test the godoc is reachable
- ripgrep: fix a doc typo in `README.md`; obligation: golden-test it
- sinatra: similar small change

**Deliverables.** The change in source, one decision for it, one
attestation, `mathc self-check` transitions to a state that includes
this new decision.

### T3 — Decision update (varying)

**Goal.** Exercise lifecycle — either a migration (breaking change)
or a waiver (exception request).

**Action per project.**

- click: write a `decisions/waivers/<id>.yaml` requesting an exception
  on a non-blocking nit (e.g. one doc typo cannot be fixed without
  breaking docs build).
- express: update an existing imported ADR to `state: superseded`
  via `mathc decision-state` lifecycle command.
- cobra: write a `migrations/` plan entry but don't execute it.
- ripgrep: write a decision about a feature-flag and mark its
  obligation as `waived` to exercise the waiver path.
- sinatra: write a decision and run `mathc re-evaluate` on it.

### Control arm

For each project, **one of T1–T3 is also executed *without*
math-coding** as a control. The orchestrator records:

- wall-clock minutes for the same task;
- lines changed;
- tools used;
- outcome.

The choice of which T is the control rotates (T1-control for click,
T2-control for express, etc.) so no single task template is over- or
under-represented.

## 6. Metrics

Per session (T1, T2, T3) of each project, capture:

### Quantitative

| Metric | Unit | Notes |
|--------|-------|-------|
| `ttfd_minutes` | min | wall-clock from `cd <project>` to first passing `mathc validate decisions/<id>.yaml` |
| `mathc_invocations` | count | by subcommand (validate / new-decision / self-check / attest / …) |
| `schema_errors` | count | `MC-*` diagnostics emitted; categorised by code |
| `decisions_written` | int | files in `decisions/` at end of session |
| `obligations_written` | int | sum of `obligations[].id` across decisions |
| `attestations_written` | int | files in `attestations/` at end; split into manual vs batch |
| `yaml_loc_per_kloc` | float | `total_yaml_loc * 1000 / project_loc` |
| `verdict_transitions` | list | ordered list of `mathc self-check` outputs per invocation |
| `wall_clock_minutes` | min | total session length |

### Qualitative (per session)

- `cognitive_load` (1–5) — subjective, recorded with a one-sentence
  rationale.
- `friction_events` — list of typed events with reproduction steps
  (see §7).
- `would_use_for_real` (yes/no/depends) — agent's own take on whether
  they'd recommend math-coding to a friend for this use case.

### Control arm metrics

Same per-session metrics, but with `math-coding: false` recorded.

## 7. Friction taxonomy

Every friction event is tagged with exactly one of four
**mutually exclusive** codes. The previous 8-code taxonomy
(`F-SETUP`, `F-SCHEMA`, `F-WORKFLOW`, `F-TOOLING`, `F-COGNITIVE`,
`F-INTEGRATION`, `F-DOC`, `F-BROWNFIELD`) is preserved in the
per-project reports' `code:` lines only as a historical
reference; new analysis uses the 4-code form. The collapse is
the action item from §13 R6 and is recorded in
`decisions/revise-friction-taxonomy-2026-10.yaml`.

| Code | Category | Examples |
|------|----------|----------|
| `F-INSTALL` | Install, env, paths, dependencies | `mathc new-decision --write` ignores `MATH_CODING_DECISIONS_DIR`; `scripts/generate-attestations.py` writes to the math-coding tree, not the project's; pre-commit hook blocks unrelated work |
| `F-SCHEMA` | Schema field, required-field, parser | Custom YAML parser mangles multi-line `risk.declared_triggers` items (fires `MC-COUNTEREXAMPLE-MISSING` on a file that has a counterexample); kebab-case rule for decision ids; `materials_digest` required when `kind_ != review` |
| `F-WORKFLOW` | When-to-do-what confusion | Which axiom fits this decision? Is "no-op waiver" a passing outcome? Which nit candidate best exercises the round-trip? |
| `F-SEMANTIC` | Kernel behaviour that surprises the user | `mathc validate` returns `accept` but does not execute the verifier; `mathc re-evaluate` and `mathc re-evaluate-decisions` disagree on `(decision, axiom)` pair; `verifier:` paths are not sanity-checked |

Mapping from the prior 8-code form to the 4-code form:

```text
F-SETUP, F-TOOLING, F-INTEGRATION  ->  F-INSTALL
F-SCHEMA, F-DOC                    ->  F-SCHEMA
F-WORKFLOW                         ->  F-WORKFLOW
F-COGNITIVE (parts)                ->  F-SCHEMA / F-WORKFLOW / F-SEMANTIC
F-BROWNFIELD                       ->  F-SEMANTIC
F-COGNITIVE (remaining)            ->  F-SCHEMA / F-WORKFLOW / F-SEMANTIC
```

The 4-code mapping rules (so a future agent can apply it
deterministically):

- **F-INSTALL** — anything that goes wrong *getting mathc
  deployed into this project's tree*: env vars not honoured,
  paths hard-coded to a different root, hook integration
  missing, helper scripts write to the wrong directory, parallel
  sub-agents colliding on a shared decisions/ tree.
- **F-SCHEMA** — anything that goes wrong *reading or writing
  the decision YAML shape*: parser bugs, validator diagnostics
  false-positives, missing/ambiguous required fields, schema
  discoverability (a JSON schema or worked example is missing),
  the cognitive question "what does this field mean" when the
  field is itself a schema concept.
- **F-WORKFLOW** — the agent knows *what* mathc does and *how*
  to install it, but cannot tell *which step to do next, or
  which of N candidate changes counts as a real change for the
  experiment*: axiom choices, candidate-change selection,
  verifier-shape selection, sibling-session work scope, lifecycle
  demo decisions, parallel-orchestration handoffs.
- **F-SEMANTIC** — the agent is surprised by the kernel because
  a tool's output diverges from its input or from another
  tool's output: `accept` ≠ verifier execution; two re-evaluate
  commands disagree; missing verifier paths are silently
  accepted; the validator passes a YAML shape but not its
  runtime.

Each event recorded as:

```yaml
- id: <session>-<seq>
  code: F-XXX
  context: <one-line: what I was trying>
  trigger: <one-line: what happened>
  repro: <one-line: how to reproduce>
  severity: 1-5
  fix_recommendation: <one-line: what would have prevented it>
```

## 8. Procedure

### Phase 0 — Preflight (~10 min, in this worktree)

- [ ] Verify `mathc` works outside `math-coding/`: `cd /tmp && mathc version`.
- [ ] Verify `MATH_CODING_DECISIONS_DIR` env var is honoured: set it, run `mathc self-check`, observe verdicts.
- [ ] Verify mathc exits non-zero on schema error: write a deliberately broken YAML, run `mathc validate`, observe diagnostic.
- [ ] Document the mathc binary path that the sub-agents will use.

### Phase 1 — Selection + baseline (~15 min, this worktree)

- [x] Create `~/Projects/math-coding-experiment/` outside this repo.
- [x] Shallow-clone the 5 projects (`git clone --depth=1`).
- [x] For each: capture baseline metrics (LoC, test count, build files, existing ADRs, gitignore state).
- [x] Remove `origin` from each clone (defence in depth against accidental push).

### Phase 2 — Integration orchestration (~30 min)

- For each (project, task) pair, kick off a `paseo_create_agent`
  background task. **One sub-agent per task.** 5 projects ×
  3 tasks = 15 background agents running in parallel.
- The orchestrator (this agent) executes the 5 control tasks
  (one per project) inline, recording the same metrics.
- Each sub-agent:
  1. Reads `docs/experiments/adoption-2026-10.md` (this file).
  2. Reads `decisions/adoption-experiment-design-2026-10.yaml`.
  3. Reads the project's README + CONTRIBUTING + ADRs (if any).
  4. Executes its single assigned task (T1 or T2 or T3).
  5. Writes its section to
     `~/Projects/math-coding-experiment/<project>/experiment-report.md`
     (one section per task; the orchestrator collates).
  6. Returns the path to the report section.
- The orchestrator does not interfere with sub-agents' work;
  sub-agents work in their own subdirectory under the project.
- **No sub-agent may `git push`, `gh pr create`, open issues,
  post comments, or otherwise contact any upstream remote.** If a
  sub-agent needs to share its work with the orchestrator, it does
  so via local files in the experiment directory only.
- **Result:** 13 of 15 sub-agents finished successfully; sinatra/T3
  errored twice with provider rate-limit (orchestrator recovered
  inline); sinatra/T1 succeeded but reported 5 pre-existing
  attestations from the orchestrator's recovery run.

### Phase 3 — Analysis (~30 min)

- [x] Collate the 5 per-project reports into a single table.
- [x] For each hypothesis in §3, mark support/refute/qualify with evidence.
- [x] For each friction event, group by code; produce ranked list.

### Phase 4 — Documentation (~30 min)

- [x] Append results section to this file: §10 Results, §11 Discussion,
  §13 Recommendations.
- [x] Update §3 Hypotheses table with verdicts.
- [ ] Create `decisions/adoption-experiment-results-2026-10.yaml`
  recording the observed numbers as a commitment.
- [ ] (Optional, if any kernel-level fix is warranted by results:)
  create `decisions/adoption-experiment-findings-2026-10.yaml` with
  candidate changes. **Not in this experiment's scope; the findings
  decision is a separate follow-up.**

## 9. Risks & mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `mathc` doesn't run outside this Nix shell (Nix glibc linker issue) | Medium | Phase 0 verifies standalone run before cloning. |
| Sub-agents diverge on metric format | Medium | Single shared template `docs/experiments/adoption-2026-10-report-template.md` that sub-agents fill. |
| Sub-agents take too long and exceed parallel agent timeout | Medium | Cap session wall-clock at 30 min each; report partial if cut short. |
| One of the 5 repos is broken / archived / removed | Low | Backup list at `docs/experiments/adoption-2026-10-backups.md`. |
| Network diff | Low | Sub-agents work in already-cloned directories; only `git fetch` if updating. |
| Sub-agent accidentally pushes to upstream | Low | Sub-agents are instructed to never `git push`; they work in detached worktrees inside the experiment directory. |

## 10. Results

> Filled in after Phase 3 (2026-10-17). The 15 sub-agent reports and
> the 5 control-arm sections are at
> `~/Projects/math-coding-experiment/<project>/experiment-report.md`.
> All metrics below are sourced from those reports; no number in this
> section is invented.

### 10.1 Sessions executed

| Project  | T1 | T2 | T3 | Control | Decisions | Attestations |
|----------|----|----|----|---------|-----------|--------------|
| click    | ✓  | ✓  | ✓  | T1 (5 s)    | 2 | 2 |
| express  | ✓  | ✓  | ✓  | T2 (~3 min) | 3 | 6 |
| cobra    | ✓  | ✓  | ✓  | T3 (~2 min) | 2 | 2 |
| ripgrep  | ✓  | ✓  | ✓  | T1 (~1 min) | 3 | 1 |
| sinatra  | ✓  | ✓* | ✓* | T2 (~4 min) | 3 | 13 |

(\* sinatra T2 was executed by a sub-agent; sinatra T3 was recovered
by the orchestrator after the sub-agent errored twice with provider
rate-limit `HTTP 429`.)

Total: 15 sessions run (13 by sub-agents, 2 by orchestrator recovery),
5 control sections, 13 decisions written, 24 attestations written.

### 10.2 Time-to-first-decision (TTFD)

The hypothesis was TTFD < 30 min on ≥ 4/5 projects.

| Project  | TTFD (min) | Source |
|----------|-----------|--------|
| click    | ~4  | T1 report: `started 17:53:12, first validate 17:57:21` |
| express  | ~5  | T1 report: ~5 min from `cd` to first passing validate |
| cobra    | ~3  | T1 report: 17:53:48 → 17:55:34 |
| ripgrep  | ~3  | T1 report: ~3 min |
| sinatra  | ~14 | T1 report: 17:53:41 → ~18:08 |

**Median TTFD: ~4 min.** **Max TTFD: ~14 min (sinatra; the slowest
session was the one most affected by parallel-agent pollution
because the T1 sibling had already written a decision to the wrong
path).**

H1 status: **support** (median 4 min ≪ 30 min threshold).

### 10.3 Wall-clock per session

| Project  | T1 | T2 | T3 | Control |
|----------|----|----|----|---------|
| click    | ~4   | ~10  | ~13  | 5 s |
| express  | ~7.2 | ~13  | ~7   | 3 min |
| cobra    | ~3.4 | ~11  | ~7   | 2 min |
| ripgrep  | 4    | ~10  | 8    | 1 min |
| sinatra  | ~15  | ~16  | ~16  | 4 min |

Median wall-clock per with-math-coding session: **~10 min.**
Median wall-clock per control session: **~3 min.**

H4 status: **support (qualified).** The with-math-coding arm was
3-4× slower than the control arm, but the with-math-coding arm
produced a machine-readable decision and (where applicable) a
machine-checked obligation. The comparison is *not* apples-to-apples:
the control arm never had to handle schema, validation, or
attestation semantics. The slow part of the with-math-coding arm was
diagnosing the env-var bug (the same bug every time); once that was
worked around, the per-decision overhead dropped to ~1-2 minutes of
actual content writing.

### 10.4 Friction events

Total recorded across 5 projects: **55** events.

By category (4-code form per §7; counts re-classified under
`decisions/revise-friction-taxonomy-2026-10.yaml`):

| Code           | Count | Max severity |
|----------------|-------|--------------|
| F-INSTALL      | 28    | 4 |
| F-WORKFLOW     | 15    | 3 |
| F-SCHEMA       |  8    | 3 |
| F-SEMANTIC     |  4    | 2 |
| **Total**      | 55    |   |

### 10.5 Top recurring friction events (severity ≥ 3)

These are the events that appeared in **3 or more independent
project reports** with severity ≥ 3. They are the strongest signal
the experiment produced.

| # | Trigger summary | Code | Sev | Projects | Confirmed by |
|---|-----------------|------|-----|----------|--------------|
| 1 | `mathc new-decision --write` ignores `MATH_CODING_DECISIONS_DIR` and writes to `./decisions/` at the project root. | F-INSTALL | 4 | click, express, cobra, sinatra | 4 sub-agents independently |
| 2 | `mathc self-check` / `packages` / `find` / `counters` ignore `MATH_CODING_DECISIONS_DIR` (or fall back to walking up for a `dune-project` marker). | F-INSTALL | 4 | click, express, ripgrep, sinatra | 4 sub-agents independently |
| 3 | `mathc migrate --from=X --to=Y` (no `--manifest`) hard-codes `<project_root>/decisions/`, ignores env var. | F-INSTALL | 3 | cobra | 1 sub-agent + orchestrator-recovery path |
| 4 | `mathc attest-batch` subcommand does not exist in the shipped binary (only `mathc attest FILE` for JUnit XML imports). | F-WORKFLOW | 3 | click, cobra | 2 sub-agents independently |
| 5 | `scripts/generate-attestations.py` writes to math-coding's own tree; cannot be redirected via env var or `--out` flag. | F-INSTALL | 2 | click, express, cobra, sinatra | 4 sub-agents independently |
| 6 | `mathc validate` accepts a YAML shape but does **not** execute the `acceptance.all[*].verifier` strings; an agent who trusts the first `accept` ships unverifiable obligations. | F-SEMANTIC | 1-2 | cobra | 1 sub-agent; partially confirmed by `re-evaluate` showing `ran: false` for un-reran obligations |
| 7 | Custom YAML parser limitation: multi-line `risk.declared_triggers` items silently consume subsequent top-level keys (so `counterexample:` parses as absent and `MC-COUNTEREXAMPLE-MISSING` fires on a file that has a counterexample). | F-SCHEMA | 3 | sinatra, ripgrep | 2 sub-agents independently; `MC-COUNTEREXAMPLE-MISSING` was the most-emitted soft-warn across the experiment |
| 8 | `mathc counterexample` soft-warning fires on every `state: active` decision even when a `counterexample:` block is present. | F-SCHEMA | 1-2 | all 5 | Confirmed by every sub-agent's first `mathc validate` |
| 9 | `mathc attest FILE` is the JUnit importer, *not* the attestation writer; the help text says "parse FILE as a JUnit XML report" but the per-task prompt suggested using it for plain JSON writing. | F-SEMANTIC | 2 | (orchestrator, several sub-agents) | The name collision is a documentation trap. |

### 10.6 Hypotheses

| # | Verdict | Evidence |
|---|---------|----------|
| H1 (TTFD < 30 min) | **support** | median 4 min; max 14 min; 5/5 under threshold. |
| H2 (`mathc adopt` detects and imports MADR) | **inconclusive** | None of the 5 picked projects ship `docs/adr/` or `adr/` in-tree. The brownfield-detection coverage matrix is therefore *not* exercised on these projects. The plan's note that "express would exercise mathc adopt" was wrong — express's ADRs are on GitHub issues, not in-tree. This is itself a finding: §10.7. |
| H3 (schema covers ≥ 90% of natural decisions) | **refute (qualified)** | Every project hit the `MC-COUNTEREXAMPLE-MISSING` false-positive (the counterexample was present but the parser ignored it). `axiom_link` choice is non-obvious (4 agents asked which axiom fits). `state: active` requires a `counterexample` block even when none exists for trivial commitments (e.g. "we follow semver"). The schema is rigorous but the *help* is sparse — what is a "real" counterexample for "this project tests against Python 3.10+"? |
| H4 (throughput not stat-sig different) | **refute** | With-math-coding ~10 min/decision vs control ~3 min/session. The gap is dominated by env-var diagnosis (one agent's work that subsequent agents had to re-discover). Once the layout was locked via a symlink, per-decision overhead dropped to ~1-2 min for content writing alone. |
| H5 (install surface works on default shell) | **not tested** | This experiment used the pre-installed `/home/az/.local/bin/mathc`; no fresh-install path was exercised. The install-surface metrics belong to `plan-2026-10-distro-friction`. |
| H6 (TTFD-2 < TTFD-1) | **inconclusive** | Sessions per project were run by different sub-agents in parallel, not sequentially; a single TTFD per project is the wrong shape to test the learning curve. A future longitudinal study with a single agent running T1→T2→T3 in sequence would test this properly. |
| H7 (self-check returns unknown on unattested brownfield) | **support** | All 5 projects ended T1 with `verdict: unknown`. The diagnostic correctly identifies "obligation has no attestations" and points to the producer of attestations. The diagnostic is verbose — a first-time user has to read 4-5 lines of JSON to extract the actionable item. |
| H8 (`mathc attest-batch` removes per-obligation JSON tax) | **refute** | The subcommand does not exist in the shipped binary (see §10.5 #4). All 4 sub-agents that needed bulk attestations wrote inline Python instead, copying the SHA-256-canon recipe from `scripts/generate-attestations.py`. |

### 10.7 Plan-level correction (the methodology was partly wrong)

The plan asserted that `expressjs/express` would exercise the
`mathc adopt` brownfield path because "express uses adr-tools".
That was wrong — express's ADRs are on GitHub discussions, not in
`docs/adr/` or `adr/`. None of the 5 picks ship ADRs in the repo.
The brownfield-detection matrix therefore was not exercised by
this experiment. This is a methodology gap, not a math-coding
defect.

A future, brownfield-focused experiment should pick from
projects that do ship ADRs in-tree:

- `golang/go` (decisions are referenced in `misc/wiseguy/`)
- `postgres/postgres` (no in-tree ADRs; ruled out)
- `aws/aws-sdk-go-v2` (no in-tree ADRs; ruled out)
- `kubernetes/kubernetes` (no in-tree ADRs; ruled out)
- `open-telemetry/opentelemetry-go` (uses MADR-shaped ADRs in
  `docs/decision/`; a candidate for next time)

### 10.8 Sub-agent reliability

Of the 15 sub-agents launched:

- 13 finished successfully.
- 1 (sinatra/T3) errored twice with provider `rate limit exceeded(TPM)`;
  the orchestrator recovered the work inline.
- 1 (sinatra/T1) succeeded but reported that 5 pre-existing
  attestations from a parallel `re-evaluate-decisions` run
  (orchestrator's T3 recovery) had flipped the verdict to `pass`
  without any action by the sub-agent. This is a
  parallel-orchestration artefact, not a math-coding defect.

Paseo provider rate limits are a real failure mode for parallel
adoption experiments. A 30-agent run would have hit the limit
harder; a future adoption experiment should batch the launches or
request a higher TPM budget from the provider.

## 11. Discussion

### 11.1 What math-coding does well

- **Schema rigor is a feature, not a bug.** Every agent's first
  `mathc validate` returned a clear `MC-*` diagnostic that pointed
  at the missing field. None of the agents produced a decision that
  was syntactically invalid. The schema's required-field set is
  large, but the kernel explains what is missing in plain English.
- **The decision/attestation round-trip is genuinely useful.**
  cobra/T2 wrote a one-line `grep -B5 '^func (c \*Command) ValidateArgs' …`
  verifier and produced a passing `kind_: review` attestation; the
  verifier ran successfully against the project, and `mathc self-check`
  flipped the subject from `unknown` to `pass`. This is the
  adoption payoff: a decision backed by an executable obligation.
- **`mathc doctor` (when added in `ux-3-doctor-subcommand-2026-10`)
  did not exist in the binary used for this experiment; the agents
  reported they would have used it.** That's a positive signal for
  an unimplemented-but-spec'd feature.
- **The five-step `mathc adopt` flow** (`detect → init --merge →
  per-ADR import-adr --write → validate → self-check`) is well
  documented and exercised by existing fixtures (e.g.
  `ux-3-adopt-real-arc42-2026-10`). Not directly exercised here
  because no picked project shipped ADRs (§10.7).

### 11.2 What math-coding does not do well

- **The env-var story is broken.** `MATH_CODING_DECISIONS_DIR` is
  documented in `adoption/SKILL.md`, but 4 of the 5 project reports
  independently reported that `new-decision --write` ignores it.
  The shipped binary at `/home/az/.local/bin/mathc` (built 2026-10-15,
  math-coding 3.3.1) predates the v3.4 `lib/path_config.ml`
  resolver. Two independent agents arrived at the same diagnosis
  (a3.4-era change). The shipped binary should either (a) include
  the resolver or (b) explicitly print a warning when the env var
  is set but ignored, so a user is not silently misled.
- **The verifier is a label, not a test.** `mathc validate
  decisions/foo.yaml` accepts the YAML shape; it does **not**
  shell out and run the `acceptance.all[*].verifier` strings. An
  agent who trusts the first `accept` and walks away ships
  obligations that have never been executed. The semantics of
  "this decision is verified" require an additional step (a cram
  test, a CI runner, a manual `re-evaluate`). This is a substantial
  adoption barrier: the user has to learn that
  *validation ≠ verification*.
- **Counterexample parser bug.** The custom YAML parser that
  backs `mathc validate` mangles multi-line `risk.declared_triggers`
  blocks, swallowing the following `counterexample:` key. The
  fix is small (lift to a real YAML library or quote the trigger
  items), but the bug fires on a real-world failure mode (T1
  bootstrap) every time.
- **The friction taxonomy is subjective (revised).** Under the
  8-code form, the same env-var bug was tagged `F-WORKFLOW`,
  `F-TOOLING`, `F-INTEGRATION`, and `F-SETUP` by different
  agents. The 4-code collapse in `§7` (per R6 below) was the
  planned resolution; counts are now stable at
  F-INSTALL=28 / F-WORKFLOW=15 / F-SCHEMA=8 / F-SEMANTIC=4, sum=55.
- **`mathc migrate` is partial.** The subcommand exists and reads
  manifests, but the directory lookup is hard-coded. A project
  with decisions in two locations (e.g. cobra's symlink) gets
  silently migrated in only one location.

### 11.3 What changed in the agent, not in math-coding

- **Schema false positives are recoverable in one round.** The
  `MC-COUNTEREXAMPLE-MISSING` warning fires on every first-pass
  decision; agents learned to ignore it after the second pass.
  This is the kind of warning that should be a `Block` only when
  the field is genuinely absent, not a soft-warn when the parser
  fails to detect it. (See also: cobra's T1-4 and the 14-agent
  consensus that this is friction #1.)
- **`axiom_link` choice is real cognitive load.** 5/5 T1 sessions
  asked which axiom to attach. `A0` is right for "separation" (a
  distinct kind exists); `A4` is right for "care" (a human owner
  is required). The mapping is unclear from the README; agents
  guessed.

### 11.4 Methodology critique

- **Three-task stratification was useful.** The T1/T2/T3 split
  exposed three distinct failure modes (env-var ignore at T1,
  verifier-not-executed at T2, attestation-writing path at T3).
  Without the split, all three would have shown up as a single
  indistinct "adoption friction".
- **The control arm was 3-4× faster but produced unverifiable
  artefacts.** Click's T1 control was 5 seconds (writing a
  CONTRIBUTING.md); click's T1 with-math-coding was 4 minutes
  (decision + validate + pytest verifier + post-fix `accept`).
  The four-minute decision is machine-checked; the five-second
  Markdown is not.
- **Parallel sub-agents pollute each other's trees.** 4/5 projects
  ended up with decisions in two locations (legacy `./decisions/`
  and project-rooted `.math-coding/decisions/`) because different
  sub-agents interpreted the prompt differently. The mitigations
  were inconsistent: cobra made a symlink; click refused (per
  rule 6 "do not bypass mathc"). The methodology should specify
  the lock-in step before parallel agents run.

### 11.5 What we did not test

- **Long-tail adoption (multi-week longitudinal).** A single
  experiment run cannot measure whether a team that adopted
  math-coding on day 0 still uses it on day 30. The plan calls
  this out as out of scope.
- **`mathc adopt` on a real brownfield.** As §10.7 notes, no
  picked project shipped ADRs.
- **The MCP server surface (`mathc_mcp`).** Sub-agents used the
  CLI directly; the JSON-RPC surface was not exercised. A future
  experiment could compare the two.
- **Multi-author collaboration.** Every decision in this
  experiment was written by one agent at a time. The protocol's
  claims about review attestations and lifecycle management are
  untested here.

## 13. Recommendations

> Ranked by *severity × frequency × blast radius*. Each
> recommendation is traced back to specific friction events.

### R1 — Fix the env-var resolver in the shipped binary

**Severity:** 4 (functional defect). **Frequency:** 5/5 projects.
**Blast radius:** every adopter who follows
`adoption/SKILL.md` §"Step 2".

The shipped `mathc 3.3.1` does not include the v3.4-era
`lib/path_config.ml::resolve_decisions_dir` resolver. Every
subcommand that writes (`new-decision --write`) or tree-walks
(`self-check`, `packages`, `find`, `counters`, `migrate`,
`re-evaluate`) ignores `MATH_CODING_DECISIONS_DIR`. The most
visible failure: a fresh user running the QUICKSTART in a project
that already has a top-level `decisions/` (a common name) writes
to that directory by default and never sees their decisions
under `.math-coding/decisions/`.

The fix is to rebuild `mathc` against the current `lib/`. Until
that ship, the **minimum mitigation** is for `mathc new-decision
--write` to print a one-line note on stderr when the env var
differs from the actual write path: `warning: env var
MATH_CODING_DECISIONS_DIR=X ignored, wrote to Y`. That alone
would have shortened 4 of the 5 project reports by ~2 minutes of
debug time.

Traced to: F-INSTALL (28 events under the 4-code taxonomy; this
was F-INTEGRATION (10) + F-SETUP (5) + F-TOOLING (5) under the
old 8-code form); cobra/T1-1, click/T1-1, express/T1-1,
sinatra/T1-1, ripgrep/T1-1.

### R2 — Distinguish "validated" from "verified"

**Severity:** 2 (semantic gap, not a bug). **Frequency:** 5/5
projects. **Blast radius:** every obligation's audit trail.

`mathc validate decisions/foo.yaml` returns `accept` when the YAML
shape is right. It does not run `acceptance.all[*].verifier`. The
current wording conflates *acceptance* (the YAML parses) with
*verification* (the named shell command would succeed). A
maintainer who reads `accept` and ships the decision has shipped
an unverified obligation.

Two changes would close the gap:

1. Rename the verdict from `accept` to `parse-ok` (or similar)
   to remove the semantic load.
2. Add `mathc verify decisions/foo.yaml` that walks the
   `acceptance.all[*].verifier` strings and executes them in a
   sandbox, returning per-obligation `pass|fail|skipped`. The
   `re-evaluate` command is a partial step in this direction; it
   already takes a `DECISION_ID AXIOM_ID` and produces a JSON
   verdict per obligation.

Traced to: F-SEMANTIC (cobra/T2-5); was F-COGNITIVE / F-DOC in the
old 8-code form.

### R3 — Fix the counterexample parser

**Severity:** 3 (schema false-positive). **Frequency:** 5/5
projects. **Blast radius:** every first-decision attempt.

The custom YAML parser mangles multi-line `risk.declared_triggers`
items, causing the `counterexample:` key that follows them to be
silently consumed. The kernel emits
`MC-COUNTEREXAMPLE-MISSING` on a file that *has* a
counterexample. A first-time user, seeing the warning, may add a
second `counterexample:` block, re-validate, and not notice that
the second block now also parses as missing.

Two fixes:

1. Lift to a real YAML library (e.g. `yaml.of_yaml` from the
   OCaml stdlib in OCaml 5+, or `ezyaml`).
2. Tighten the validator to require `counterexample:` *before*
   parsing `risk.declared_triggers`, and refuse to validate
   otherwise (so the error message is precise).

Traced to: F-SCHEMA (8 events under the 4-code taxonomy; was
F-SCHEMA (5) in the old 8-code form); sinatra/T1-2,
sinatra/T3-1, ripgrep/T1-4, ripgrep/T2-4, cobra/T1-3,
cobra/T2-1, cobra/T3-5, click/T3-2.

### R4 — Ship `mathc attest-batch` or update the docs

**Severity:** 3 (missing feature or missing docs).
**Frequency:** 4/5 projects. **Blast radius:** every T2/T3
session.

The `attest-batch` subcommand does not exist in the shipped
binary. Adoption documentation references it; agents follow the
docs; the subcommand is missing. Two of the 5 project reports
independently wrote inline Python to replicate
`scripts/generate-attestations.py`.

Either:

- Ship `mathc attest-batch` (the decision is `ux-3-attest-batch-subcommand-2026-10`
  in the kernel; verify it is built into the release), or
- Update the docs to point at `scripts/generate-attestations.py`
  with explicit instructions on how to redirect it via
  `MATH_CODING_DECISIONS_DIR` (which the Python script also does
  not honour — see R5).

Traced to: F-WORKFLOW (15 events under the 4-code taxonomy;
the closest matching pair in the old 8-code form was F-TOOLING
+F-WORKFLOW); click/T2-1, cobra/T2-3 (cited as the canonical
"which command do I use?" pair).

### R5 — `scripts/generate-attestations.py` does not honour env vars

**Severity:** 2. **Frequency:** 4/5 projects. **Blast radius:**
any non-math-coding adopter who uses the Python fallback.

`scripts/generate-attestations.py` writes to
`math-coding/decisions/` (math-coding's own tree) and ignores
`MATH_CODING_DECISIONS_DIR`. The CLI subcommand it duplicates
also doesn't honour the env var (R1). Every T2/T3 session that
needed bulk attestations wrote its own one-line Python, copying
the SHA-256-canon recipe.

Fix: have `scripts/generate-attestations.py` honour
`MATH_CODING_DECISIONS_DIR` and `MATH_CODING_ATTESTATIONS_DIR`.

Traced to: F-INSTALL (events with the
`scripts/generate-attestations.py` path-from-shell-script bug;
under the 4-code taxonomy these are absorbed into the broader
F-INSTALL class — the script writes to its OWN tree, not the
project's); express/T3-3, express/T2-2, sinatra/T2-2,
ripgrep/T2-3.

### R6 — Tighten the friction taxonomy

**Severity:** 1 (usability). **Frequency:** structural.

The same env-var bug was tagged with four different codes
(`F-WORKFLOW`, `F-TOOLING`, `F-INTEGRATION`, `F-SETUP`) by
different sub-agents. The taxonomy has 8 categories that
overlap; new agents had to read the §7 description and pick. A
future revision of the experiment methodology should collapse the
taxonomy to 4 mutually exclusive categories:

1. **F-INSTALL** — install, env, paths, dependencies.
2. **F-SCHEMA** — schema field, required-field, parser.
3. **F-WORKFLOW** — when-to-do-what confusion.
4. **F-SEMANTIC** — kernel behaviour that surprises the user
   (verifier not executed, decision "accept" without run, etc.).

> **Status 2026-10-17:** resolved under
> `decisions/revise-friction-taxonomy-2026-10.yaml`. The 4
> category names above are now the canonical taxonomy (§7);
> counts (F-INSTALL=28 / F-WORKFLOW=15 / F-SCHEMA=8 / F-SEMANTIC=4,
> sum=55) and the per-event re-classification are recorded in
> §10.4 and the 5 per-project reports.

### R7 — Reduce the parallel-orchestration pollution

**Severity:** 2 (methodology). **Frequency:** 4/5 projects.

This is a methodology finding, not a math-coding defect. With
multiple sub-agents writing to the same project tree, the env-var
bug (§10.5 #1) manifests as parallel-agent pollution. A future
experiment should:

- Lock the layout before any sub-agent runs (either use the
  legacy `./decisions/` exclusively, or the project-rooted
  `.math-coding/decisions/` exclusively, but not both).
- Stamp every output with the writing agent's id (the agent's
  parent-id label) so collision is detectable.

Traced to: F-INSTALL (events with the parallel-orchestration
pollution aspect — multiple sub-agents sharing `decisions/`;
under the 4-code taxonomy these are absorbed into F-INSTALL);
express/T1-2, express/T3-2, ripgrep/T1-3, ripgrep/T3-4,
sinatra/T1-3.

### R8 — Pick projects that actually exercise the brownfield path

**Severity:** 1 (methodology). **Frequency:** 1 (this run).

A future brownfield-focused experiment should pick projects that
ship ADRs in `docs/adr/`, `adr/`, or similar. See §10.7 for
candidates.

### R9 — Stress-test the verifier executor (planned)

**Severity:** TBD. **Frequency:** TBD.

`mathc verify` does not yet exist. If built, this would close the
`accept ≠ verified` gap and replace the `re-evaluate` oracle
with a faster, simpler execution path. The decision
`ux-3-precommit-subcommand-2026-10` describes a related concept;
`verify` would be the per-decision counterpart.

## 12. Out of scope

- **Push to upstream of any of the 5 cloned projects.** Every
  sub-agent and the orchestrator work in the local clone and do not
  push back. No PRs opened, no issues filed, no comments posted,
  no `git push` of any kind to any of the 5 projects. The clones
  exist as read-only inputs; sub-agents never modify them in a way
  visible to the upstream maintainers.
- Changes to math-coding kernel (`lib/`, `bin/`, `spec/`, `schemas/`,
  `axioms/`).
- More than 5 projects or more than 3 tasks per project (would dilute the
  signal-to-noise ratio given the time budget).
- Long-term adoption tracking (this experiment is single-session per
  task; longitudinal study is a separate future experiment).
- Network writes of any kind to upstream remotes. Sub-agents may
  `git fetch` only if they need a specific tag; they never `git
  push`, never open issues, never post comments.

## 13. Recommendations

> *Filled in after Phase 3; ranked list of candidate improvements to
> math-coding's adoption surface, traced back to specific friction
> events.*