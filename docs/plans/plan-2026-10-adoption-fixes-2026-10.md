# Plan: Adoption-fixes, 2026-10

> **Status:** design draft, awaiting user sign-off.
> **Branch:** `plan/adoption-fixes-2026-10` (created from
> `experiment/adoption-external-projects-2026-10`).
> **Author:** orchestrator agent, 2026-10-17.
> **Companion decision:** `decisions/plan-2026-10-adoption-fixes-2026-10.yaml`.

## 0. Why this exists

The adoption experiment of 2026-10-17
(`docs/experiments/adoption-2026-10.md`) executed math-coding on
five external OSS projects in five languages and recorded 55
friction events. §13 of that report enumerates 9 recommendations
ranked by severity × frequency × blast radius. This plan turns
those recommendations into concrete change-records.

This plan is **additive to existing UX work**: it does not modify
or supersede `plan-2026-10-ux-friction` (12 UX improvements)
or `plan-2026-10-distro-friction` (13 distro fixes). It is a
third, narrowly-scoped plan whose scope is bounded by the
9 recommendations and the smaller set of friction events that
the experiment surfaced.

## 2. Boundaries (A3 self-application)

- **All sub-decisions land in 2026-10-2026-11.** A successor
  plan may supersede; this one does not.
- **No sub-decision modifies `lib/attestations/` or
  `lib/mcp/`** beyond the strict scope of its sub-decision.
  Cross-decision kernel surface changes are forbidden.
- **No change to `decisions/decision.yaml`** (the active policy).
  All sub-decisions inherit the current `bootstrap-v3@3` (or
  its successor) under A3.
- **No change to `schemas/*.json`** unless the sub-decision
  is specifically about a schema field.
- **Every sub-decision produces a passing `mathc self-check`**
  with the same 17 unknown subjects as at HEAD
  `experiment/adoption-external-projects-2026-10` and zero
  NEW unknown subjects. This is the **kernel-stability
  precondition** for the plan.

## 3. Hypotheses to test

This plan is implementation work, not research. Each sub-decision
must satisfy four pre-conditions:

1. The friction event it addresses was recorded in ≥ 1 of the
   5 experiment reports.
2. The fix does not regress any existing decision's verdict.
3. The fix produces a measurable improvement on the same metric
   that surfaced the friction (e.g. `ttfd_minutes`, `schema_errors`,
   wall-clock).
4. The fix is independently revertable in one commit.

## 4. Sub-decisions

### Batch A — kernel-critical, parallel (4 sub-decisions)

**A1. `fix-env-var-resolver-2026-10`** (R1)

- **What.** Make `mathc new-decision --write`, `mathc self-check`,
  `mathc packages`, `mathc find`, `mathc counters`, `mathc migrate`,
  `mathc re-evaluate <id>` honour `MATH_CODING_DECISIONS_DIR` and
  `MATH_CODING_ATTESTATIONS_DIR` via the existing
  `lib/path_config.ml::resolve_decisions_dir` resolver.
- **Scope.** `lib/path_config.ml`, `bin/Mathc.ml` (the relevant
  subcommand dispatch sites only — `do_new_decision`,
  `do_self_check`, `do_packages`, `do_find`, `do_counters`,
  `do_migrate`, `do_re_evaluate`).
- **Acceptance.**
  - For each affected subcommand: with `MATH_CODING_DECISIONS_DIR=.math-coding/decisions`
    exported and a single `decisions/<id>.yaml` file under
    `.math-coding/decisions/`, the subcommand operates on that
    file (not on `./decisions/<id>.yaml`).
  - `mathc validate decisions/<id>.yaml` exit 0.
  - `mathc self-check` exit 0; subjects include the new
    decision; verdict reflects the new decision's
    obligation/attestation state.
- **Risk.** Low. The resolver already exists; this is a wiring
  fix. Verify by running the experiment's reproduce commands
  (`MATH_CODING_DECISIONS_DIR=.math-coding/decisions mathc
  new-decision --write …`) — they must now succeed.

**A2. `fix-yaml-parser-2026-10`** (R3)

- **What.** Fix the custom YAML parser so that multi-line
  `risk.declared_triggers` items do not silently consume the
  following `counterexample:` key. Either:
  - (preferred) replace the custom parser with `Yaml.of_yaml` or
    `ezyaml`, OR
  - (minimal) tighten the parser so multi-line scalar values are
    not mistaken for the next top-level key.
- **Scope.** `lib/yaml_mini.ml` (or equivalent parser module),
  `lib/decision.ml` if it has parser-coupled logic.
- **Acceptance.**
  - A decision with `risk.declared_triggers: - foo\n- bar` and
    `counterexample: | …` validates `accept` without
    `MC-COUNTEREXAMPLE-MISSING`.
  - The same decision under the old parser emits
    `MC-COUNTEREXAMPLE-MISSING` (regression fixture).
- **Risk.** Medium. YAML parsers are notorious for these bugs;
  a fix can break other YAML shapes that currently parse.

**A3. `ship-attest-batch-2026-10`** (R4)

- **What.** The `mathc attest-batch` subcommand exists in the
  spec (`bin/Mathc.ml::do_attest_batch`, `lib/attestations/batch.ml`)
  but is not registered in the `dispatch` table. Register it.
- **Scope.** `bin/Mathc.ml::dispatch` (one-line addition).
- **Acceptance.**
  - `mathc attest-batch --help` shows usage; `mathc attest-batch
    --manifest=foo.tsv --dry-run` prints the would-write
    filenames without writing.
  - The end-to-end flow (`mathc new-decision` → `mathc
    attest-batch --manifest=...` → `mathc self-check`) flips the
    verdict from `unknown` to `pass` in <5 seconds for a
    5-obligation decision.
- **Risk.** Very low. Subcommand already implemented.

**A4. `fix-generate-attestations-env-2026-10`** (R5)

- **What.** `scripts/generate-attestations.py` writes to the
  math-coding repo's own `attestations/` tree and ignores
  `MATH_CODING_DECISIONS_DIR` / `MATH_CODING_ATTESTATIONS_DIR`.
  Add env-var support matching the kernel's behaviour.
- **Scope.** `scripts/generate-attestations.py` only.
- **Acceptance.**
  - With `MATH_CODING_ATTESTATIONS_DIR=/tmp/alt/attestations`,
  the script writes JSONs to `/tmp/alt/attestations/` instead
  of the math-coding tree.
  - The script's `--help` documents the env vars.
  - `python3 -m py_compile scripts/generate-attestations.py`
  succeeds.
- **Risk.** Very low. Python script, ~30 lines change.
- **Depends on.** A1 (so the env var semantics are unified across
  Python and OCaml).

### Batch B — kernel-medium, after A (2 sub-decisions)

**B1. `add-verify-subcommand-2026-10`** (R2, R9)

- **What.** Add `mathc verify <decision-file-or-id>` that walks
  `acceptance.all[*].verifier` strings and executes them in a
  sandbox (subprocess, env-stripped, timeout, working dir =
  decision's repo root). Returns per-obligation `pass | fail |
  skipped`. Renames `mathc validate`'s verdict from `accept` to
  `parse-ok` to remove the semantic load.
- **Scope.** `bin/Mathc.ml` (new `do_verify`); `lib/decision.ml`
  (verifier-string parsing if not already a function).
- **Acceptance.**
  - A decision with `acceptance.all[*].verifier: file-exists path`
    produces `verdict: pass` on `mathc verify` when the path
    exists, `verdict: fail` when it does not.
  - `mathc validate decisions/foo.yaml` returns
    `verdict: parse-ok` (renamed).
  - The 5 pre-existing attestations on this experiment's
    decisions (`adoption-experiment-design-2026-10-*`,
    `adoption-experiment-results-2026-10-*`) are still parsed
    correctly.
- **Risk.** Medium. New command, semantics change for
  `mathc validate` (the rename). The rename is a breaking
  change for any downstream test that asserts on
  `verdict: accept`; this must be coordinated with
  `tests/cli/*.t` fixtures.
- **Depends on.** A1 (env var working).

**B2. `tighten-counterexample-warn-2026-10`**

- **What.** The `MC-COUNTEREXAMPLE-MISSING` soft-warn fires even
  when the counterexample is present but parser-ignored (the A2
  case). Tighten the warn to fire only when the field is
  genuinely absent after A2's parser fix.
- **Scope.** `bin/Mathc.ml::validate_with_counts` (or wherever
  the diagnostic is emitted).
- **Acceptance.**
  - A decision with `counterexample: | …` does NOT emit
    `MC-COUNTEREXAMPLE-MISSING`.
  - A decision without `counterexample:` (in `state: active`)
    still emits the warning.
- **Risk.** Low. Diagnostic tightening only.
- **Depends on.** A2.

### Batch C — process / docs / future, parallel (4 sub-decisions)

**C1. `revise-friction-taxonomy-2026-10`** (R6)

- **What.** Collapse the 8 friction codes (F-SETUP/SCHEMA/
  WORKFLOW/TOOLING/COGNITIVE/INTEGRATION/DOC/BROWNFIELD) to 4
  mutually exclusive categories (F-INSTALL / F-SCHEMA /
  F-WORKFLOW / F-SEMANTIC). Update `adoption-2026-10.md` §7.
- **Scope.** `docs/experiments/adoption-2026-10.md` §7 only.
- **Acceptance.** Re-classify all 55 events under the new
  taxonomy; counts per category still sum to 55.
- **Risk.** Trivial. Docs only.

**C2. `axiom-link-inference-2026-10`** (R10)

- **What.** When `mathc new-decision` produces a decision without
  `axiom_link`, suggest the top-3 most-likely candidates based on
  the decision's `scope.paths` (e.g. `lib/**` → `A0`, `tests/**`
  → `A1`, `decisions/**` → `A4`). Do not auto-fill; emit a
  soft-warn that names the candidates.
- **Scope.** `bin/Mathc.ml::do_new_decision` (template generation);
  `lib/decision.ml` (the inference rule).
- **Acceptance.** A new-decision on a `lib/` path produces a
  decision with `axiom_link: TODO` and a soft-warn naming A0/A1
  as candidates.
- **Risk.** Medium. Inference rules are subjective.

**C3. `verify-mathc-doctor-ships-2026-10`**

- **What.** Verify whether `mathc doctor` ships in the released
  binary; if yes, ensure the experiment prompt mentions it; if
  no, ship it.
- **Scope.** `bin/Mathc.ml::dispatch` if not shipped; else
  `docs/experiments/adoption-2026-10.md` §11.1 only.
- **Acceptance.** `mathc doctor --help` returns usage; the
  experiment prompt mentions it.
- **Risk.** Low. Already spec'd.

**C4. `plan-brownfield-experiment-v2-2026-10`** (R8)

- **What.** Plan a follow-up experiment on projects that ship
  ADRs in `docs/adr/`, `adr/`, or similar. Pick from
  `open-telemetry/opentelemetry-go` (MADR), `golang/go`
  (referenced in `misc/wiseguy/`), `open-policy-agent/opa`
  (MADR), `cncf/toc` (MADR-shaped).
- **Scope.** `docs/experiments/brownfield-experiment-v2-2026-10.md`
  + corresponding decision.
- **Acceptance.** Future-experiment design document with
  methodology, hypotheses, metric template, friction taxonomy
  revision (if any).
- **Risk.** Trivial. Docs only. The plan is itself a planning
  artifact; execution is a separate future worktree.

## 6. Sub-agent worktree protocol

Each sub-decision lands in its own worktree. The orchestrator
does the planning and review; the sub-agents do the implementation.

### Worktree naming

`<type>-<topic>-2026-10` per the project's worktree-first
convention. Examples:

- `fix-env-var-resolver-2026-10`
- `fix-yaml-parser-2026-10`
- `ship-attest-batch-2026-10`
- `fix-generate-attestations-env-2026-10`
- `add-verify-subcommand-2026-10`
- `tighten-counterexample-warn-2026-10`
- `revise-friction-taxonomy-2026-10`
- `axiom-link-inference-2026-10`
- `verify-mathc-doctor-ships-2026-10`
- `plan-brownfield-experiment-v2-2026-10`

### Branch ordering (sequencing)

- **Batch A (4 sub-decisions):** all four launch in parallel in
  separate worktrees from `experiment/adoption-external-projects-2026-10`.
  Each PR lands independently.
- **Batch B (2 sub-decisions):** B1 depends on A1 (env-var
  working); B2 depends on A2 (parser fixed). Launch after the
  relevant A sub-decision merges to main.
- **Batch C (4 sub-decisions):** all four launch in parallel;
  independent of A and B.

### Common sub-agent instructions

Each sub-agent prompt enforces:

1. **Worktree-first.** Sub-agent creates its own worktree
   (`git worktree add ~/.paseo/worktrees/math-coding/<topic>
   -b <type>-<topic>-2026-10 experiment/adoption-external-projects-2026-10`).
2. **Decision file.** Sub-agent writes
   `decisions/<sub-decision-id>.yaml` (mode `light` for
   non-kernel; mode `standard` for kernel changes).
3. **mathc validate.** Sub-agent runs
   `MATH_CODING_DECISIONS_DIR=decisions
    MATH_CODING_ATTESTATIONS_DIR=attestations
    mathc validate decisions/<id>.yaml` and fixes any `MC-*`
   diagnostic before committing.
4. **mathc self-check.** Sub-agent runs `mathc self-check` and
   verifies the verdict contains the same 17 unknown subjects
   as at HEAD and zero NEW unknown subjects. A sub-decision
   that introduces a new unknown subject is blocked until the
   unknown is resolved (attestation or waiver).
5. **Tests.** Sub-agent adds or extends a cram test in
   `tests/cli/<feature>.t` exercising the fix.
6. **No kernel regression.** Sub-agent runs `dune build` and
   `dune test`; both must exit 0.
7. **Atomic commit.** Sub-agent's change is one commit on
   the topic branch.
8. **No push.** Sub-agent does not push or open a PR. The
   orchestrator does that after the experiment reports.

### Counterexample-to-the-plan

The counter-position considered: "10 sub-decisions is too
many; the experiment surfaced 9 recommendations, not 10. The
extra is gold-plating." Rejected on three grounds: (a) C3
(`mathc doctor`) was a 4th-positive note in §11.1 that
deserves an explicit decision, not silent omission; (b) the
R10 `axiom_link` inference is independently small but
discovered in 5/5 T1 sessions, so it is a real friction;
(c) C2 and R10 together close the same class of UX gap.

A second counter-position: "B1's rename of `accept` →
`parse-ok` is a breaking change that breaks downstream
fixtures." Acknowledged: the rename is a breaking change
and is the *most* consequential sub-decision in the plan.
The acceptance criteria require the change to be
coordinated with `tests/cli/*.t` updates. If a downstream
fixture fails, B1 is blocked until it passes; the sub-agent
does not ship a half-renamed binary.

## 7. Outcomes

The plan closes when, for every obligation below, the
sub-decision exists in `decisions/`, has at least one matching
attestation in `attestations/`, the surface change is exercised
by a cram or conformance test, and `mathc self-check` returns
`verdict: "unknown"` with the **same 17 pre-existing unknown
subjects** and zero NEW unknowns.

The 10 sub-decisions cover the 9 recommendations in §13 plus
the 1 additional gap (`mathc doctor` verification). Each
sub-decision is independently revertable in one commit; the
plan survives any single sub-revert.

## 8. Out of scope

- Changes to `lib/attestations/` or `lib/mcp/` beyond each
  sub-decision's strict scope.
- Changes to `decisions/decision.yaml`.
- Kernel changes that are not in the 10 sub-decisions above.
- The brownfield-experiment v2 *execution* (only the plan is
  in scope; execution is a separate future worktree).
- Push to upstream of any external project (this plan makes
  no changes to external projects).
- More than 10 sub-decisions or a longer time horizon than
  2026-10 → 2026-11.

## 9. Risks

- **kernel-stability precondition** (R1, A2, B1, B2 in
  particular): any kernel change risks regressing the
  self-check verdict. Mitigated by the per-sub-decision
  `no-self-check-regression` obligation.
- **B1's breaking rename** (`accept` → `parse-ok`):
  mitigations include coordinating with `tests/cli/*.t` and
  documenting the change in `USAGE.md` before merge.
- **Sub-agent divergence** (the experiment had a friction
  taxonomy subjective problem): mitigated by the per-task
  prompts that pre-classify frictions for the agent.
- **Nix-glibc dependency**: not addressed by this plan
  (the `plan-2026-10-distro-friction` plan owns that).

## 13. Recommendations (post-plan)

After all 10 sub-decisions land and the plan closes, the
follow-up plan (`plan-2026-11-adoption-fixes` or successor)
should consider:

- Whether the new `mathc verify` command should be the
  default verifier path, or whether `validate` should
  shell out to it.
- Whether `axiom_link` inference should auto-fill the field
  or only suggest it (current decision is suggest-only).
- Whether the brownfield-experiment v2 results suggest
  further changes to `mathc adopt`.

The post-plan recommendations are *not* in this plan's
scope. They belong to a successor plan.