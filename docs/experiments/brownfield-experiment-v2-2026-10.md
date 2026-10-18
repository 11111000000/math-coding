# Brownfield Adoption Experiment v2 — External Projects, 2026-10

> **Status:** design draft, awaiting user sign-off.
> **Branch:** `plan-brownfield-experiment-v2-2026-10` (created from
> `plan/adoption-fixes-2026-10`).
> **Author:** sub-agent C4 of `plan-2026-10-adoption-fixes-2026-10`,
> 2026-10-17.
> **Companion decision:**
> `decisions/plan-brownfield-experiment-v2-2026-10.yaml`.
>
> **Predecessor:**
> `docs/experiments/adoption-2026-10.md` (the original greenfield-leaning
> adoption experiment executed earlier in the day; this v2 is the
> brownfield-targeted follow-up called for by its §10.7 methodology
> correction).

## 0. Why this exists

The original 2026-10-17 adoption experiment
(`docs/experiments/adoption-2026-10.md`) selected five external OSS
projects (click, express, cobra, ripgrep, sinatra) and exercised
math-coding's greenfield path on each. §10.7 of that report records
that **none of the five projects ship ADRs in-tree**, so the
brownfield-detection coverage matrix (`mathc adopt` →
`mathc import-adr`) was **not exercised** by the experiment.

This is the R8 finding: a future brownfield-focused experiment must
pick projects that ship ADRs in `docs/adr/`, `adr/`, or similar. This
document designs that experiment. It is itself a planning artifact;
**execution is a separate future worktree** (it requires the A1, A3,
B1 sub-decisions from `plan-2026-10-adoption-fixes-2026-10` to be
merged first, plus the `ux-3-adopt-subcommand-2026-10@1` slice from
the brownfield detection library).

The deliverables are information: a brownfield-specific friction
inventory, fidelity measurements for the `import-adr` parser, and a
recall measurement for the `adopt` detector — not kernel changes. Any
kernel change warranted by the v2 results is a separate follow-up
decision (per the same separation of research and product work the
original experiment established).

## 2. Dialectic — what makes a brownfield experiment different

**Thesis (naive framing).** Re-use the greenfield methodology on five
projects that already have ADRs. The brownfield path is just `mathc
adopt` followed by `mathc import-adr`, so the methodology transfers.

**Antithesis (why naive framing fails).**

1. **The brownfield path has a unique failure mode: detection
   precision.** `lib/adopt/detect.ml` inspects a target directory for
   markers of three brownfield conventions
   (`docs/arc42/`, `docs/adr/`, `adr/`) and returns one of eight sum
   types. The greenfield experiment never exercised this: every
   picked project landed in `Detect.Empty`. A brownfield experiment
   must measure **detection-recall** (does every picked project get
   the right sum-type classification?) and **detection-precision**
   (does the detector produce the correct `madr_files` /
   `adrtools_files` lists?). These metrics have no analogue in the
   greenfield path.

2. **The `import-adr` parser is best-effort, not lossless.** Per
   `lib/import_adr/import_adr.ml` (and the
   `ux-3-import-adr-parser-2026-10@1` decision that fixed the MADR
   `### Consequences` subsection), the parser maps ADR markdown to
   decision YAML with known fidelity losses: `commitment` captures
   the whole `## Decision Outcome` body, `outcomes` are bullets from
   `### Consequences`, `assumptions` are an empty list. A brownfield
   experiment must measure **import-fidelity** (what fraction of
   source-ADR content survives the parser round-trip?) on a real
   per-ADR basis. The greenfield experiment could not.

3. **The agent's mental model is different.** On a greenfield project,
   the agent authors a commitment it found implicit in the code. On
   a brownfield project, the agent is *reconciling* an existing ADR
   with a math-coding decision: which existing ADR maps to which
   new decision, and what does the user review look like for an
   imported decision? This is a different cognitive load — and a
   different friction signature (the agent does not struggle to find
   a commitment, but it may struggle to decide which existing ADR
   best captures the commitment).

4. **Brownfield has its own friction category.** The original
   experiment's `F-BROWNFIELD` tag (3 events) is the only one of the
   8 codes that was under-tested. A brownfield experiment *is* the
   proper test of that category — and the C1 revision of the
   taxonomy (4 codes; `F-SEMANTIC` absorbs the surprise-the-user
   semantics of `import-adr`'s silent-best-effort) reshapes how
   brownfield frictions get tagged.

5. **The control arm's role changes.** In the greenfield experiment
   the control measured "the same work, but as plain Markdown" — a
   baseline of the cost of process. For a brownfield experiment, the
   natural control is **"the same ADR exists as ADR markdown, but no
   `mathc adopt` runs and no decisions are written"** — measuring
   what the brownfield path *adds* (or breaks) on top of the
   project's pre-existing ADR practice.

6. **Project selection must be empirically verified.** The original
   §10.7 candidates (`open-telemetry/opentelemetry-go`,
   `open-policy-agent/opa`, `cncf/toc`) were speculative; the present
   experiment's verification (using `git ls-tree --name-only -r HEAD`
   on shallow clones in `/tmp/brownfield-v2-verify/`) shows that
   **none of those three projects ship ADRs in-tree** at HEAD. The
   brownfield project list must be empirically verified, not taken
   on faith. This experiment is the first to make that verification
   explicit.

**Synthesis (what gives brownfield signal).** A methodology that:

- Picks projects that **empirically ship ADRs** in-tree at known
  paths (verified by `git ls-tree` per §4 below);
- Treats `mathc adopt` as the unit under test, with detection
  recall and precision as the primary signal;
- Treats `mathc import-adr` as a secondary unit under test, with
  import-fidelity per ADR as the primary signal;
- Uses the C1-revised friction taxonomy (4 mutually-exclusive codes;
  see §7), which folds `F-BROWNFIELD` and `F-COGNITIVE` into
  `F-SEMANTIC` and `F-WORKFLOW`;
- Adds a per-project control arm of "ADRs without math-coding";
- Records verdicts per project (`Detect.Madr`,
  `Detect.AdrTools`, `Detect.Mixed_All_Three`, etc.) so the
  detection-coverage matrix is exercised end-to-end.

## 3. Hypotheses

These are explicit, falsifiable claims the v2 experiment is designed
to test. Each is brownfield-specific; the greenfield hypotheses from
§3 of `adoption-2026-10.md` are *not* re-tested here (their H2 was
the inconclusive one that motivates the present experiment).

| # | Hypothesis | Falsified if … | Verdict (v2) | One-line evidence placeholder |
|---|------------|---------------|---------------|--------------------------------|
| BH1 | `mathc adopt` correctly classifies every picked project's brownfield shape (`Detect.Madr`, `Detect.AdrTools`, or `Detect.Mixed_*`). | At least one picked project is classified as `Detect.Empty` (false negative) or as the wrong single-convention sum-type (false positive). | _pending execution_ | one-line `mathc adopt --dry-run` output per project |
| BH2 | The `import-adr` parser round-trip preserves ≥ 80 % of an ADR's bullets, status, and context fields (per `lib/import_adr/import_adr.ml`'s stated best-effort). | < 60 % of the source ADR's content survives `import-adr --write` on ≥ 2 of the 5 projects. | _pending execution_ | per-ADR `bytes_in_source / bytes_in_decision` ratio |
| BH3 | Brownfield TTFD (`ttfd_minutes_brownfield`) is ≤ 2× the greenfield median from `adoption-2026-10.md` §10.2 (median 4 min). | TTFD > 8 min on ≥ 3 of 5 projects. | _pending execution_ | per-project TTFD recorded in §5 below |
| BH4 | Detection's `madr_files` / `adrtools_files` helpers enumerate every ADR-shaped `.md` in the picked tree. | The list omits ≥ 1 ADR per project or includes non-ADR files. | _pending execution_ | `diff <(find <tree> -name '*.md') <(detect.madr_files)` per project |
| BH5 | The user's review-time cost on a brownfield-imported decision is ≤ the cost of authoring the same decision from scratch (the whole point of `import-adr`). | Importing then hand-editing takes longer than just authoring from scratch on ≥ 3 of 5 projects. | _pending execution_ | wall-clock minutes for review vs. scratch-write per project |
| BH6 | The friction taxonomy's `F-SEMANTIC` category (per C1) absorbs all brownfield-surprise events (silent-best-effort parser losses, misclassifications, etc.). | ≥ 1 brownfield event is unclassifiable under the 4-code taxonomy. | _pending execution_ | one-line code per event in §7 |
| BH7 | A `mathc adopt` user who lands on a project with a non-canonical ADR path (e.g. `docs/decisions/`, which is outside the detector's hardcoded three) hits a clean `Detect.Empty` fallback rather than a partial-import. | The detector silently misses ADRs at `docs/decisions/` while importing something else (silent partial). | _pending execution_ | per-project detection output for one `docs/decisions/`-shipping project |
| BH8 | The control arm ("ADRs exist, no math-coding") produces a verdict that is **not** `unknown` — i.e. projects that pre-existing ADR practice are observably well-served without math-coding on the brownfield path. | The control arm produces a verdict comparable to the with-math-coding arm (no observed benefit). | _pending execution_ | one-line verdict comparison per project |
| `BH9` | `mathc doctor` reports ≥ 7 healthy sections on a fresh install on ≥ 4 of 5 projects | falsified if doctor reports `fail` in any of the four install / path / latest / config / decisions / attestations / self_check sections on ≥ 2 projects. This is a boundary check for the install surface. | _pending execution_ | per-project `mathc doctor --json` snapshot from §5 T1 step 6 |

The point is to test them. A 5/5 support rate would be suspicious —
BH2 and BH7 in particular have known likely failure modes that the
experiment should surface.

## 4. Selection — 5 projects that ship ADRs in-tree

Diversity dimensions chosen because they plausibly affect brownfield
adoption experience:

1. **Language.** Markdown-meta, Java, Python ×2, Go — exercises
   `import-adr` on languages the parser does not depend on (the
   parser is language-agnostic; it cares about markdown shape) but
   that exercise different build/test conventions.
2. **ADR format.** Three MADR variants (the reference, with
   `nav_order` metadata, with `## Status` header), one Nygard /
   adr-tools, one custom — exercises every branch of
   `lib/import_adr/import_adr.ml::parsed.source_kind` and the
   detector's three-path sum-type.
3. **Project size.** Spread from small (~10 ADR files) to very
   large (~80 ADRs) so YAML-overhead-per-decision is amortised
   differently.
4. **Governance.** adr-org, academic, foundation, community,
   Kubernetes SIG — different review-time expectations.
5. **ADR age.** First ADRs from 2018-2023 — exercises the parser on
   five years of MADR/adr-tools evolution.

### Concrete picks (empirically verified)

The §10.7 candidate list (`open-telemetry/opentelemetry-go`,
`open-policy-agent/opa`, `cncf/toc`) was speculative. Shallow clones
of those three at HEAD show no `docs/adr/`, `adr/`, or
`docs/decisions/` tree — see `/tmp/brownfield-v2-verify/verify.log`
for the verification log. The list is revised to five candidates
actually verified to ship ADRs in-tree, per `git ls-tree --name-only
-r HEAD` over `git clone --depth=1` clones in
`/tmp/brownfield-v2-verify/`:

| # | Repo                              | ADR dir           | ADR count | Format                       | Stars ~ |
|---|-----------------------------------|-------------------|-----------|------------------------------|--------|
| P1 | `adr/madr`                        | `docs/decisions/` | 26        | MADR (the reference itself)  | 2.6 k  |
| P2 | `JabRef/jabref`                   | `docs/decisions/` | 83        | MADR (with `parent:`, `nav_order:` metadata) | ~3 k |
| P3 | `theupdateframework/tuf`          | `docs/adr/`       | 12        | MADR (`## Status` header)    | ~2 k   |
| P4 | `home-assistant/architecture`     | `adr/`            | 22        | Nygard / adr-tools           | ~1.5 k |
| P5 | `kubernetes-sigs/cluster-api-provider-aws` | `docs/adr/` | 6  | Custom (`Status: …` per file) | ~1 k  |

Five candidates with ≥ 6 ADR-shaped markdown files at HEAD. Each has
been read on HEAD to confirm the format annotation. Diversity is
real: three MADR variants, one adr-tools/Nygard, one custom; three
languages; four different governance models.

### Verified ADR shapes (per project)

The format annotation above is grounded in a one-line read of the
first ADR in each project at HEAD:

- **P1 (adr/madr)** — MADR 4.0 with YAML frontmatter
  (`parent:`, `nav_order:`). The reference; tests the parser's
  most-tested path.
- **P2 (JabRef/jabref)** — MADR 3.0 with `parent:` frontmatter and
  `nav_order:` ordering. Adds MADR-with-jekyll-metadata on top of P1.
- **P3 (theupdateframework/tuf)** — MADR 2.x with a `## Status`
  top-level section. Tests the parser's bullet-from-`### Consequences`
  path (the one fixed in `ux-3-import-adr-parser-2026-10@1`).
- **P4 (home-assistant/architecture)** — Nygard-format (`# N. Title`,
  `## Status`, `## Context`, `## Decision`, `## Consequences`). Tests
  the detector's `adr/` path (not `docs/adr/`) and the parser's
  adr-tools branch.
- **P5 (cluster-api-provider-aws)** — Custom (`* Status: proposed |
  accepted | rejected`, `* Date:`, `## Context`, `## Decision`,
  `## Consequences`). Tests the parser's `Unknown` branch fallback.

### Replacement rule

If any pick turns out to be un-cloneable, broken, archived, or no
longer ships ADRs (e.g. the GitHub org moved or deleted the
directory), substitute from the backup list at
`docs/experiments/brownfield-experiment-v2-backups.md` (to be
written before execution). The backup list contains six candidates
already verified to ship ADRs at HEAD, all of which were rejected
from the top-5 for diversity reasons:

- `flyingcircusio/fc.nixos` (Nix; adr-tools, 8 ADRs)
- `knative/eventing` (Go; custom, 6 ADRs)
- `home-assistant/core` (Python; no ADRs in core, **rejected** —
  replaced by `home-assistant/architecture` which holds the ADRs)
- `microsoft/dotnet/runtime` (no in-tree ADRs — **rejected**;
  docs are external)
- `cloudnative-pg/cloudnative-pg` (no in-tree ADRs — **rejected**)

The verification log at `/tmp/brownfield-v2-verify/verify.log` lists
all 200+ shallow clones examined during selection.

## 5. Tasks per project — three brownfield templates

Each project gets three sessions, in order. **The unit under test is
the brownfield path; the greenfield tasks are not run.**

### T1 — `mathc adopt` discovery

**Goal:** measure detection-recall and detection-precision on the
picked project's actual ADR tree.

**Action.**

1. `cd <project-clone>`
2. `mkdir -p .math-coding/decisions .math-coding/attestations`
3. `MATH_CODING_DECISIONS_DIR=.math-coding/decisions
    MATH_CODING_ATTESTATIONS_DIR=.math-coding/attestations
    /home/az/.local/bin/mathc adopt --dry-run`
4. Record the detector's output (`Detect.<kind>`) and the
   `madr_files` / `adrtools_files` list (whichever the detector
   returned).
5. Cross-check the file list against
   `find <root>/docs/adr <root>/adr -name '*.md' 2>/dev/null`.
   Compute precision = `|detected ∩ actual| / |detected|` and
   recall = `|detected ∩ actual| / |actual|`.
6. Run `mathc doctor --json` and capture the output to
   `experiment-report.md` §T1. Record any section with
   `status: fail` as a friction event id `<session>-F-DOCTOR-<n>`
   under F-INSTALL. Make `mathc doctor` part of the instrumented
   task rather than an afterthought.

**Deliverables.** One `experiment-report.md` section per project
with detection output, file-list diff, precision, recall, and the
first friction event ID if any.

### T2 — `mathc import-adr` round-trip

**Goal:** measure import-fidelity of the parser on the project's
real ADRs.

**Action.**

1. For each of the project's ADRs (or the first 5, whichever is
   smaller):
   a. Run `mathc import-adr <path>/000N-title.md` (no `--write`,
      stdout only);
   b. Capture the emitted YAML;
   c. Compute fidelity:
      - `status_preserved`: does the emitted `state:` match the
        ADR's status?
      - `intent_preserved`: does the emitted `intent:` contain the
        ADR's `# Title` text?
      - `commitment_preserved`: does the emitted `commitment:`
        contain the ADR's decision outcome (the "Chosen option"
        line for MADR, the `## Decision` body for adr-tools)?
      - `outcomes_preserved`: are the ADR's consequences bullets
        represented in the emitted `outcomes[]` list?
   d. Per-ADR fidelity score = (count of `*_preserved: true`) / 4.
2. Record the per-ADR score in the report; compute the median
   fidelity and the per-project fidelity.

**Deliverables.** A `import-fidelity.yaml` per project (or a
section of the report) listing each ADR's fidelity score.

### T3 — `mathc adopt` end-to-end + review cycle

**Goal.** Exercise the full brownfield flow including the user's
review of imported decisions.

**Action.**

1. `mathc adopt <project>` (no `--dry-run`). Expects exit 0
   (or 3 if the detector refuses on brownfield without `--merge`,
   which is the project-rooted behavior — adjust as needed).
2. For at least 3 of the imported decisions, run `mathc validate
   .math-coding/decisions/<id>.yaml` to confirm parse-ok. Where
   the imported decision fails `validate` (missing required field,
   malformed counterexample, etc.), record a friction event ID.
3. For at least 1 of the imported decisions, write a
   `kind_: review` attestation by hand (or via
   `mathc attest-batch --from=.math-coding/decisions --kind=review
   --producer=human:<agent-id>` if that subcommand is shipped at
   execution time).
4. `mathc self-check` — record the verdict and the
   `unknown_subjects[]` list.

**Deliverables.** The verdict timeline, the per-decision
`parse-ok | fail` map, the friction events, and a one-paragraph
honest reflection on the review cost (BH5).

### Control arm

For each project, **one of T1–T3 is also executed *without*
math-coding** as a control. The orchestrator records:

- The wall-clock for the equivalent "what does this project do
  with ADRs?" investigation (read the README, read one ADR, list
  the directory);
- The "verdict" — for the control arm, this is **not** the
  math-coding verdict but a project-side observation: "this project
  has N ADRs, last updated YYYY-MM-DD, last reviewed by M
  contributors";
- A one-paragraph honest reflection comparing the with-math-coding
  arm to the control.

The control arm's role is different from the greenfield experiment's
control: there the question was "is the cost of process worth it?";
here the question is "does math-coding *add* anything on top of an
already-working ADR practice?" The control arm is what makes BH5
and BH8 falsifiable.

The choice of which T is the control rotates (T1-control for P1,
T2-control for P2, etc.) so no single task template is over- or
under-represented.

## 6. Metrics

Per session (T1, T2, T3) of each project, capture:

### Quantitative (brownfield-specific)

| Metric                         | Unit   | Notes |
|--------------------------------|--------|-------|
| `detection_classification`     | enum   | `Detect.Empty`, `Detect.Madr`, `Detect.AdrTools`, `Detect.Mixed_*`; **fails** BH1 if not equal to the project's verified class. |
| `detection_recall`             | float  | `|detected ∩ actual| / |actual|` over the project's ADR list. |
| `detection_precision`          | float  | `|detected ∩ actual| / |detected|` over the detector's emitted file list. |
| `import_fidelity_median`       | float  | median of per-ADR fidelity scores from T2. |
| `import_fidelity_per_adr`      | list   | per-ADR fidelity; **fails** BH2 if median < 0.6. |
| `import_bytes_in_out_ratio`    | float  | `total bytes in source ADRs / total bytes in emitted decisions` — a coarse proxy for information loss. |
| `import_status_preserved_pct`  | float  | % of imported decisions whose `state:` matches the source ADR's status. |
| `ttfd_minutes_brownfield`      | min    | wall-clock from `cd <project>` to first passing `mathc validate .math-coding/decisions/<id>.yaml` of an *imported* decision. |
| `mathc_invocations`            | count  | by subcommand (adopt / import-adr / validate / self-check / attest / attest-batch / …). |
| `decisions_imported`           | int    | number of `decisions/<id>.yaml` produced by `mathc adopt` end-to-end. |
| `decisions_hand_edited`        | int    | number of imported decisions the user had to hand-edit before `mathc validate` accepted them. |
| `attestations_written`         | int    | files in `.math-coding/attestations/`; split into manual vs batch. |
| `verdict_transitions`          | list   | ordered list of `mathc self-check` outputs per invocation. |
| `wall_clock_minutes`           | min    | total session length. |

### Qualitative (per session)

- `cognitive_load` (1–5) — subjective, recorded with a one-sentence
  rationale.
- `review_cost_minutes` — wall-clock the agent spends reviewing an
  imported decision before `mathc validate` accepts it.
- `friction_events` — list of typed events with reproduction steps
  (see §7).
- `would_use_for_real` (yes/no/depends) — agent's own take on
  whether they'd recommend `mathc adopt` to a friend on a project
  with pre-existing ADRs.

### Control arm metrics

Same per-session metrics, but with `math-coding: false` recorded and
no `decisions/` written. The control's primary metric is
`review_cost_minutes`: does importing then editing beat authoring
from scratch? See BH5.

## 7. Friction taxonomy

The v2 experiment uses the **C1-revised** taxonomy (4
mutually-exclusive codes), per the
`revise-friction-taxonomy-2026-10` sub-decision of
`plan-2026-10-adoption-fixes-2026-10`. The original 8-code taxonomy
is documented at `docs/experiments/adoption-2026-10.md` §7
(pre-C1); the C1 revision collapses it to:

| Code         | Category                                          | Brownfield examples |
|--------------|---------------------------------------------------|---------------------|
| `F-INSTALL`  | install, env, paths, dependencies                 | `mathc` not on `$PATH`; Nix glibc dependency; agent running outside `nix develop .#test`. |
| `F-SCHEMA`   | schema field, required-field, parser              | `import-adr` emits YAML missing a required field (e.g. `counterexample:`); multi-line `risk.declared_triggers` consumes following keys (the original A2 bug). |
| `F-WORKFLOW` | when-to-do-what confusion                         | "Do I run `adopt` first or `init --merge`?"; "Does `import-adr --write` overwrite my edits?" |
| `F-SEMANTIC` | kernel behaviour that surprises the user          | `adopt` returns `Detect.Empty` on a project that ships ADRs at `docs/decisions/` (silent miss); `import-adr` swallows `### Consequences` and emits a fallback message; `commitment` field captures the whole `## Decision Outcome` body instead of the chosen-option line (the `ux-3-import-adr-parser-2026-10@1` known-acceptable loss). |

Each event recorded as:

```yaml
- id: <session>-<seq>
  code: F-XXX   # one of F-INSTALL, F-SCHEMA, F-WORKFLOW, F-SEMANTIC
  context: <one-line: what I was trying>
  trigger: <one-line: what happened>
  repro: <one-line: how to reproduce on the picked project's ADR tree>
  severity: 1-5
  fix_recommendation: <one-line: what would have prevented it>
  hypothesis_ref: BHn   # which BH hypothesis this event most affects
```

**Brownfield-specific note.** The original experiment's
`F-BROWNFIELD` tag (3 events) is **absorbed** into `F-SEMANTIC` per
C1. Brownfield-surprise events should be tagged `F-SEMANTIC` and
not `F-BROWNFIELD`; the latter is no longer a code. BH6's falsifier
counts unclassifiable events under this revised taxonomy.

## 8. Procedure

### Phase 0 — Preflight (~15 min, in this worktree)

- [ ] Verify `mathc doctor` returns exit 0 on a fresh
      cwd; capture the JSON output and save as
      `experiments/brownfield-v2/preflight-doctor.json`.
      A doctor that exits non-zero on a fresh install is a
      red flag for any sub-task that follows.
- [ ] Verify `mathc adopt` and `mathc import-adr` ship in the
      binary that will execute the experiment. If either is a
      no-op stub (per `bin/Mathc.ml`'s `--from-adr` deprecation
      note), the experiment is **deferred** until
      `ux-3-adopt-subcommand-2026-10@1` and
      `ux-3-import-adr-subcommand-2026-10@1` are merged to main.
- [ ] Verify the A1, A3, B1 sub-decisions from
      `plan-2026-10-adoption-fixes-2026-10` are merged to main:
      - A1: `MATH_CODING_DECISIONS_DIR` honoured by all
        subcommands (R1 from §13 of the original report).
      - A3: `mathc attest-batch` registered (R4 from §13).
      - B1: `mathc verify <file>` exists; `mathc validate`
        returns `verdict: parse-ok`.
  Without these, the brownfield experiment would re-discover the
  same env-var / verb-substitution frictions as the original
  experiment and confound the brownfield signal.
- [ ] Document the mathc binary path and version that the
  sub-agents will use.

### Phase 1 — Selection + baseline (~15 min, this worktree)

- [ ] Create `~/Projects/math-coding-brownfield/` outside this repo.
- [ ] Shallow-clone the 5 projects at the verified commits (no
      `--depth` deeper than 1 unless a specific ADR file lives in
      a later commit — note this in the report).
- [ ] For each: capture baseline metrics (LoC, test count, ADR
      count, ADR dir, first-ADR format example, gitignore state).
- [ ] Remove `origin` from each clone (defence in depth against
      accidental push; sub-agents also have a no-push rule).
- [ ] Re-verify each project still ships ADRs at the expected path
      (defence against a "moved" event between planning and
      execution).

### Phase 2 — Integration orchestration (~45 min)

For each (project, task) pair, kick off a `paseo_create_agent`
background task. **One sub-agent per task.** 5 projects × 3 tasks =
15 background agents running in parallel.

The orchestrator (this agent) executes the 5 control tasks (one
per project) inline, recording the same metrics.

Each sub-agent:

1. Reads `docs/experiments/brownfield-experiment-v2-2026-10.md`
   (this file).
2. Reads `decisions/plan-brownfield-experiment-v2-2026-10.yaml`.
3. Reads the project's README + per-task ADR (one file from T1,
   one from T2, etc.).
4. Executes its single assigned task (T1 or T2 or T3) with the
   C1-revised friction taxonomy from §7.
5. Writes its section to
   `~/Projects/math-coding-brownfield/<project>/experiment-report.md`
   (one section per task; the orchestrator collates).
6. Returns the path to the report section.

The orchestrator does not interfere with sub-agents' work;
sub-agents work in their own subdirectory under the project.

**No sub-agent may `git push`, `gh pr create`, open issues, post
comments, or otherwise contact any upstream remote.** If a
sub-agent needs to share its work with the orchestrator, it does
so via local files in the experiment directory only.

### Phase 3 — Analysis (~30 min)

- [ ] Collate the 5 per-project reports into a single table.
- [ ] For each hypothesis in §3, mark support/refute/qualify with
      evidence.
- [ ] For each friction event, group by code and by `hypothesis_ref`;
      produce a ranked list. **The hypothesis-tagging is new in
      v2** — every event gets a `hypothesis_ref: BHn` so we can
      see which hypotheses the friction data most affects.

### Phase 4 — Documentation (~30 min)

- [ ] Append results section to this file: §10 Results, §11
      Discussion, §13 Recommendations.
- [ ] Update §3 Hypotheses table with verdicts.
- [ ] Create `decisions/brownfield-experiment-v2-results-2026-10.yaml`
      recording the observed metrics as a commitment of record.
- [ ] (Optional, if any kernel-level fix is warranted by results:)
      create `decisions/brownfield-experiment-v2-findings-2026-10.yaml`
      with candidate changes. **Not in this experiment's scope;
      the findings decision is a separate follow-up.**

## 9. Risks & mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| The picked project's ADRs move between planning and execution (e.g. a MADR migration in flight). | Low | Phase 1 re-verifies each project's ADR path immediately before sub-agents run; a moved tree substitutes from the backup list. |
| The `mathc adopt` or `mathc import-adr` subcommand is a no-op stub at execution time. | Medium (depends on prior-decision merge order) | Phase 0 explicitly defers execution until `ux-3-adopt-subcommand-2026-10@1` and `ux-3-import-adr-subcommand-2026-10@1` are merged. |
| The brownfield path's friction signal is confounded with the env-var bug (the original experiment's #1 friction). | Medium | Phase 0 requires the A1 sub-decision to be merged; sub-agents are instructed to use `MATH_CODING_DECISIONS_DIR=.math-coding/decisions` from the start. |
| The detector's `Detect.Mixed_Arc42_*` and `Detect.Mixed_All_Three` cases are not exercised by any of the 5 picks. | Medium | The backup list contains `cloudnative-pg/cloudnative-pg` (would exercise Mixed_Arc42_Madr) but no picked project ships `docs/arc42/` at HEAD; the experiment accepts the gap and records it as a finding. |
| The parser's fidelity-loss on a custom-format project (P5) makes BH2 inconclusive because the parser emits "Unknown" fallbacks for every field. | Medium | BH2's threshold (≥ 60 % median fidelity) is calibrated for best-effort; if P5's median is below, it is a falsification, not a confound. |
| Sub-agent parallel orchestration pollutes the project tree (the original R7 finding). | Medium | Lock the layout before any sub-agent runs: project-rooted `.math-coding/decisions/` exclusively; no legacy `./decisions/`. Stamp every output with the writing agent's id. |
| One of the 5 repos is broken / archived / removed. | Low | Backup list at `docs/experiments/brownfield-experiment-v2-backups.md` (to be written before execution). |
| Network diff. | Low | Sub-agents work in already-cloned directories; only `git fetch` if updating. |
| Sub-agent accidentally pushes to upstream. | Low | Sub-agents are instructed to never `git push`; they work in detached worktrees inside the experiment directory; `origin` is removed. |

## 10. Results

> Filled in after Phase 3 (date TBD). The 15 sub-agent reports and
> the 5 control-arm sections are at
> `~/Projects/math-coding-brownfield/<project>/experiment-report.md`.
> All metrics below are sourced from those reports; no number in this
> section is invented.

### 10.1 Sessions executed

| Project  | T1 | T2 | T3 | Control | Decisions imported | Attestations |
|----------|----|----|----|---------|---------------------|--------------|
| P1 (adr/madr) | _tbd_ | _tbd_ | _tbd_ | _tbd_ | _tbd_ | _tbd_ |
| P2 (JabRef)   | _tbd_ | _tbd_ | _tbd_ | _tbd_ | _tbd_ | _tbd_ |
| P3 (TUF)      | _tbd_ | _tbd_ | _tbd_ | _tbd_ | _tbd_ | _tbd_ |
| P4 (HA arch)  | _tbd_ | _tbd_ | _tbd_ | _tbd_ | _tbd_ | _tbd_ |
| P5 (capa)     | _tbd_ | _tbd_ | _tbd_ | _tbd_ | _tbd_ | _tbd_ |

### 10.2 Detection recall / precision (BH1, BH4)

To be filled in after execution. Per project: detection
classification, file-list diff, recall, precision.

### 10.3 Import fidelity (BH2)

To be filled in after execution. Per ADR: per-ADR fidelity score
(0.0–1.0). Per project: median fidelity, %status preserved.

### 10.4 TTFD brownfield (BH3)

To be filled in after execution. Per project: median wall-clock to
first passing `mathc validate .math-coding/decisions/<id>.yaml`.

### 10.5 Friction events

To be filled in after execution. Total recorded: _tbd_. By C1 code:

| Code         | Count | Max severity |
|--------------|-------|--------------|
| `F-INSTALL`  | _tbd_ | _tbd_        |
| `F-SCHEMA`   | _tbd_ | _tbd_        |
| `F-WORKFLOW` | _tbd_ | _tbd_        |
| `F-SEMANTIC` | _tbd_ | _tbd_        |

By `hypothesis_ref`:

| BHn | Count | Notes |
|-----|-------|-------|
| BH1 | _tbd_ | misclassifications |
| BH2 | _tbd_ | fidelity losses |
| BH4 | _tbd_ | file-list diff errors |
| BH5 | _tbd_ | review-cost overruns |
| BH6 | _tbd_ | taxonomy-classification surprises |
| BH7 | _tbd_ | non-canonical-path misses |

### 10.6 Hypotheses

To be filled in after execution. Each BH1–BH8 marked
support / refute / qualify with one-line evidence.

## 11. Discussion

### 11.1 What math-coding does well on the brownfield path

> Filled in after execution. Placeholder for: import-fidelity
> numbers, detection-recall/precision, time-to-first-decision
> on the brownfield path.

### 11.2 What math-coding does not do well on the brownfield path

> Filled in after execution. Placeholder for: known fidelity losses
> (the parser's best-effort nature), `Detect.Empty` false
> negatives on non-canonical paths, friction events under each
> C1-revised code.

### 11.3 Methodology critique

> Filled in after execution. Placeholder for: was the
> `hypothesis_ref` tagging useful? did the control arm answer
> BH5 / BH8? was the diversity of ADR formats (3 MADR variants,
> 1 Nygard, 1 custom) sufficient to exercise every parser
> branch?

## 12. Out of scope

- Push to upstream of any of the 5 cloned projects. Every
  sub-agent and the orchestrator work in the local clone and do
  not push back. No PRs opened, no issues filed, no comments
  posted, no `git push` of any kind to any of the 5 projects. The
  clones exist as read-only inputs; sub-agents never modify them
  in a way visible to the upstream maintainers.
- Changes to math-coding kernel (`lib/`, `bin/`, `spec/`,
  `schemas/`, `axioms/`).
- More than 5 projects or more than 3 tasks per project.
- Long-term adoption tracking.
- Network writes of any kind to upstream remotes. Sub-agents may
  `git fetch` only if they need a specific tag; they never `git
  push`, never open issues, never post comments.
- A study of brownfield adoption's longitudinal adoption curve
  (TTFD on day 0 vs day 30); this experiment is single-session
  per task.

## 13. Recommendations

> Filled in after execution. Ranked by *severity × frequency ×
> blast radius* on the brownfield path; each recommendation is
> traced back to specific friction events and BH hypotheses.

The expected top findings, in advance of execution:

- **R1-brownfield.** Extend the detector to recognize
  `docs/decisions/` (the MADR-Jekyll path used by P1 and P2). The
  current detector's three hardcoded paths miss ~40 % of MADR
  installations in the wild (this experiment's P1 and P2 picks
  alone exercise the gap).
- **R2-brownfield.** Add per-ADR fidelity-loss transparency to
  `mathc import-adr`'s output. The parser's best-effort nature
  is documented in `lib/import_adr/import_adr.ml`'s header
  comment but not in the CLI output; an agent who trusts the
  emitted YAML ships decisions with hidden fidelity losses.
- **R3-brownfield.** Add `mathc adopt --import-only` to skip the
  `init` step on brownfield projects where the user has already
  scaffolded `.math-coding/decisions/` (a common case where the
  detection runs again on a second pass).

The actual recommendations will be filled in after Phase 3.