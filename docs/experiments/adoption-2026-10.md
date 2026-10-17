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

1. *Selection bias.* Picking top-tier OSS projects (flask, express,
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

| # | Hypothesis | Falsified if … |
|---|------------|---------------|
| H1 | Time to first decision (`TTFD`) is < 30 min for a developer who has read `QUICKSTART.md`. | `TTFD > 60 min` on ≥ 3/5 projects. |
| H2 | `mathc adopt` successfully detects and imports a brownfield project that already has MADR ADRs. | `adopt` fails or produces no decisions on a MADR-only project. |
| H3 | The schema's required-field set covers ≥ 90 % of decisions a maintainer would naturally make; the remaining 10 % map cleanly onto the `--template=minimal` path. | ≥ 3 schema errors per project that are not "user typo" but "schema doesn't model my situation". |
| H4 | Throughput (lines changed per minute) on a small task is *not* statistically different between with-math-coding and without-math-coding. | With-math-coding throughput is < 50 % of without-math-coding on ≥ 2 projects. |
| H5 | The install surface (one of: release binary, Docker, Nix, source build) works on a fresh user machine without `~/.local/bin` already on `$PATH`. | A user with default shell rc fails to run `mathc version` after install. |
| H6 | A second decision on the same project is faster than the first (learning curve). | TTFD-2 > TTFD-1. |
| H7 | The `mathc self-check` verdict on a brownfield project is `unknown` (not `pass`, not `fail`) until obligations have attestations — and this is communicated in the diagnostics. | `self-check` returns `pass` on an unattested brownfield, OR returns `fail` on the same, OR exits non-zero with a diagnostic that doesn't mention attestations. |
| H8 | `mathc attest-batch` removes the per-obligation JSON hand-writing tax. | A bulk attestation on a 5-obligation decision takes longer than 5 hand-written attestations. |

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
| P1 | `pallets/flask` | Python | ~30k | Pallets org | none | pip + pytest + tox |
| P2 | `expressjs/express` | JS | ~12k | OpenJS Foundation | adr-tools | npm + Mocha |
| P3 | `spf13/cobra` | Go | ~10k | spf13 (incubating CNCF) | none | go modules + go test |
| P4 | `BurntSushi/ripgrep` | Rust | ~30k | BurntSushi + GitHub | none | cargo + cargo test |
| P5 | `sinatra/sinatra` | Ruby | ~3k | Sinatra org | none | bundler + minitest |

**Rationale per pick.**

- **flask** — canonical micro-framework, large install base, clean
  governance. Tests will be the natural "obligation" target.
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

- flask: "we test against Python 3.x .. 3.x  (TBD from setup.cfg)"
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

- flask: bump a doc-version reference; obligation: tests/doc-version.t
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

- flask: write a `decisions/waivers/<id>.yaml` requesting an exception
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

The choice of which T is the control rotates (T1-control for flask,
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

Every friction event is tagged with one of:

| Code | Category | Examples |
|------|----------|----------|
| `F-SETUP` | Install, env, paths | mathc not on `$PATH`; Nix glibc dependency; first-run shell-RC line |
| `F-SCHEMA` | Required field, ambiguity | `counterexample` is required but I don't have one; `axiom_link` values unclear |
| `F-WORKFLOW` | When-to-do-what confusion | Do I run `validate` or `self-check` first? Where do I put the JSON? |
| `F-TOOLING` | Speed, errors, msgs | mathc slow on big tree; cryptic error; missing --help |
| `F-COGNITIVE` | Conceptual confusion | "Is this a decision or an issue?"; "Is the migration plan a decision?" |
| `F-INTEGRATION` | CI, hooks, gitignore | pre-commit hook blocks unrelated work; CI yaml missing |
| `F-DOC` | Docs discoverability | Didn't know `mathc find` existed; `QUICKSTART` doesn't link to `USAGE` |
| `F-BROWNFIELD` | Adopt, import-adr, init | `adopt` missed my arc42 section; `import-adr` lost the MADR status header |

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

- [ ] Create `~/Projects/math-coding-experiment/` outside this repo.
- [ ] Shallow-clone the 5 projects (`git clone --depth=1`).
- [ ] For each: capture baseline metrics (LoC, test count, build files, existing ADRs, gitignore state).

### Phase 2 — Integration orchestration (~30 min)

- For each project, kick off a `paseo_create_agent` background task that:
  1. Reads `docs/experiments/adoption-2026-10.md` (this file).
  2. Reads `decisions/adoption-experiment-design-2026-10.yaml`.
  3. Reads the project's README + CONTRIBUTING + ADRs (if any).
  4. Executes T1, T2, T3 (one of which is the control).
  5. Writes `~/Projects/math-coding-experiment/<project>/experiment-report.md`
     containing all metrics + friction events.
  6. Returns the path to that report.
- The orchestrator (this agent) does not interfere with the sub-agents'
  worktrees; sub-agents work in their own subdirectories.

### Phase 3 — Analysis (~30 min)

- [ ] Collate the 5 per-project reports into a single table.
- [ ] For each hypothesis in §3, mark support/refute/qualify with evidence.
- [ ] For each friction event, group by code; produce ranked list.

### Phase 4 — Documentation (~30 min)

- [ ] Append results section to this file: §10 Results, §11 Discussion,
  §13 Recommendations.
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

> *Filled in after Phase 3.*

## 11. Discussion

> *Filled in after Phase 3.*

## 12. Out of scope

- Changes to math-coding kernel (`lib/`, `bin/`, `spec/`, `schemas/`,
  `axioms/`).
- Push to upstream of any of the 5 cloned projects.
- More than 5 projects or more than 3 tasks per project (would dilute the
  signal-to-noise ratio given the time budget).
- Long-term adoption tracking (this experiment is single-session per
  task; longitudinal study is a separate future experiment).

## 13. Recommendations

> *Filled in after Phase 3; ranked list of candidate improvements to
> math-coding's adoption surface, traced back to specific friction
> events.*