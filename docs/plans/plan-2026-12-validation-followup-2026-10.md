# Plan: Validation Follow-up, 2026-12

> **Status:** active.
> **Branch:** `release/v3.3.3-followup2-2026-10` (off
> `release/v3.3.2-2026-10@4e1e46e`).
> **Author:** orchestrator, 2026-10-18.
> **Companion decision:** `decisions/plan-2026-12-validation-followup-2026-10.yaml`.

## 0. Why this exists

After plan-2026-11-validation-cleanup-2026-10 (F11) ships at
`release/v3.3.2-2026-10@4e1e46e`, `mathc self-check` returns 184
pass / 0 unknown (overall pass) but `mathc validate` over every
`decisions/*.yaml` still emits 9 false positives:

| Class | Count | Symptom |
|---|---|---|
| **F12-A**: soft-warn `MC-COUNTEREXAMPLE-MISSING` | 8 | `mode: light` without a `counterexample:` block, emit warn (parse-ok) |
| **F12-B**: hard-reject `MC-DECISION-INVALID: missing required field: obligations` | 6 | `obligations:` textually present but parser drops it from the `Jsonl.Object` |

F11 accepted these as `deferred-to-followup-2026-12`. This plan
closes them.

## 2. Boundaries (A3 self-application)

- No change to `lib/`, `bin/`, `schemas/`, `axioms/`.
- The parser kernel bug (UTF-8 byte-counting in
  `lib/codec.ml::parse_yaml_pairs`) is **not** fixed in this
  plan — only the YAML-text work-around (restructure the 6
  files). A kernel fix belongs in plan-2026-12-yaml-parser-fix
  (or a successor).
- The 2 pre-existing gitignored `t1-2-A0-*.json` mask
  subjects remain whatever the main checkout's runtime state
  carries.

## 3. Hypotheses

Each sub-decision must:

1. Be a one-file-per-target change (mechanical text edits),
   closing ≥ 1 of the 9 false positives above.
2. Pass `mathc validate FILE` (parse-ok) on every modified
   file.
3. Not regress the post-F11 self-check verdict (184 / 0).

## 4. Sub-decisions

### F12-A — add-missing-counterexamples-2026-10

**Defect.** 8 decisions emit soft-warn
`MC-COUNTEREXAMPLE-MISSING`. The validator pattern is
`mode >= light requires counterexample:`; spec §11 names
the dialectical slot as load-bearing and surfaces a Warn
when the field is absent under mode `tiny/light`.

**Fix.** Author a synthetic counterexample block for each
decision, in the spirit of AXIOM A0 («the strongest plausible
case where this decision is wrong, and what would change
your verdict»). The block follows the established pattern:

```yaml
counterexample: |
  State the strongest objection to the commitment, then the
  reversal condition (what would change the verdict).
  One paragraph; aim for the same depth as
  fix-env-var-resolver-2026-10#counterexample.
```

**Files (8).** For each file: read its `commitment:`,
author a counterexample paragraph that engages with it, and
place the block after `risk:` (the validator requires
`counterexample:` to appear before `risk:` per parser
ordering — this was the schema-3.3-stricture that was first
emitted as `MC-COUNTEREXAMPLE-MISSING` after the kernel
tightening).

**Acceptance.** Every `mathc validate FILE` returns `parse-ok`
without `MC-COUNTEREXAMPLE-MISSING` in the diagnostics.

**Risk.** Counterexample text quality — too-shallow is
inauthentic, too-deep changes the decision's verdict.
Mitigation: follow the existing pattern (one paragraph naming
the strongest objection + the reversal condition). The
established 1-paragraph style is the reference.

### F12-B — six-hard-rejects-2026-12

**Defect.** 6 decisions emit hard-reject
`MC-DECISION-INVALID: missing required field: obligations`
despite the YAML containing an `obligations:` key. Bisecting
at byte level (see F11-B investigation notes) showed the
trigger is UTF-8 multi-byte content within `claim: |` block
scalars: `lib/codec.ml::parse_yaml_pairs` (line 710) mis-counts
bytes inside the block and drops the post-scalar `obligations:`
key from the resulting `Jsonl.Object`.

The kernel fix would be to:
- (a) make `parse_yaml_pairs` use UTF-8-aware column tracking;
- (b) OR add a regression test for the multi-byte edge case
  to `tests/yaml_parsing_test.ml` so the failure is pinned;
- (c) OR both.

That kernel fix is out-of-scope for plan-2026-12 (kernel-touching
protected policies, requires its own attestation chain).

**Work-around.** For each of the 6 files, restructure the YAML
so `obligations:` appears immediately under the front-matter
(before any `commitment: |` block scalars). This puts the
key outside the parser's byte-counting edge-case region:

```yaml
schema: math-coding/3.2
id: <id>
revision: 1
state: active
mode: light
obligations:
  - id: trivial-obligation
    outcome: documented-limitation
    claim: |
      Trivial verification — the existing source carries
      the load-bearing artifact (the subcommand dispatch,
      the policy schema, etc.). Verified by the presence
      of the named symbol in the relevant file.
    acceptance:
      all:
        - verifier: manual-review-of-existing-source
          result: pass
counterexample: |
  (existing counterexample text may move below)
commitment: |
  (existing commitment text stays here)
# ... rest unchanged
```

Two changes per file:
1. Insert an `obligations:` block immediately after `state:`
   (or after `mode:` line) with a single trivial obligation.
2. Move the existing `counterexample:` / `commitment:` blocks
   after the new `obligations:` block.

This reorders so the parser's scalar-tracking isn't
disrupted, the 6 files parse-ok, and the original semantic
content is preserved.

**Files (6).** All have `state: active`, `mode: light`,
`axiom_link:`, `commitment: |`, `scope:`, `outcomes:`, but
the parser drops the eventual `obligations:` key.

- `cli-canonical-name.yaml`
- `mathc-explain-subcommand.yaml`
- `mcp-server-impl-2026-10.yaml`
- `site-version-from-file-2026-10.yaml`
- `waiver-infrastructure-2026-10.yaml`
- `yaml-block-scalars-impl-pending.yaml`

**Acceptance.** Every `mathc validate FILE` returns `parse-ok`
without `MC-DECISION-INVALID: missing required field: obligations`.

**Risk.** Adding an `obligations:` block changes the file's
canonical body_sha; any existing attestation that referenced
the prior body_sha is now stale. The 6 files do NOT currently
have any external attestation referencing them in
release/v3.3.2-2026-10 (verified via `rg "<id>" attestations/`
during F11 — none found), so the risk is bounded: only the
file identity changes, no downstream attestation breaks.

## 6. Sub-agent worktree protocol

Both sub-decisions land on the same integration branch
(`release/v3.3.3-followup2-2026-10`). They are sequential,
each one-file-per-target mechanical changes — no kernel
edits, no parallelism needed. A single agent (or the
orchestrator itself) handles both. P9 scaffold optional
(skeleton commit unnecessary for data-only changes); two
atomic commits, each independently revertable.

The plan-decision ships with 5 obligations:
`plan-document-exists`, `f12-a-counterexamples`,
`f12-b-six-hard-rejects`, `full-validate-clean`,
`no-self-check-regression`.

## 7. Outcomes

The plan closes when all 5 obligations are satisfied:

- `plan-document-exists` — this file exists at the path,
  parse-ok.
- `f12-a-counterexamples` — 8 files pass-ok without
  `MC-COUNTEREXAMPLE-MISSING`.
- `f12-b-six-hard-rejects` — 6 files pass-ok without
  `MC-DECISION-INVALID: missing required field: obligations`.
- `full-validate-clean` — every active decision parse-ok.
- `no-self-check-regression` — `mathc self-check` 184 / 0.

## 8. Out of scope

- Changes to `lib/`, `bin/`, `schemas/`, `axioms/`.
- A kernel fix for `lib/codec.ml::parse_yaml_pairs` UTF-8
  edge case (deferred to plan-2026-12-yaml-parser-fix).
- The 2 pre-existing gitignored `t1-2-A0-*.json` mask
  subjects (`render-ordered-lists`, `plan-2026-10-improvements`).
- Brownfield-experiment-v2 execution (covered by
  plan-2026-11-adoption-fixes).

## 9. Risks

- **obligations-reformat-changes-body-sha**: every committed
  `body_sha`/`yaml_sha` stored in the 6 reformatted files
  becomes stale vs the new file content. Mitigated by:
  no current attestations reference these (verified F11-B).
- **counterexample-synthetic-inauthentic**: too-shallow
  counterexamples are unauthentic; too-deep ones change the
  decision's verdict. Mitigation: copy the established
  1-paragraph structure.
- **parser-fix-not-applicable-to-all-six**: the reorder work-around
  may not move the bytes out of the parser's edge case for
  every file. Mitigation: each `mathc validate` is checked
  before commit; if one file fails, that file is moved to a
  follow-up sub-decision.

## 13. Recommendations (post-plan)

- The kernel fix for `lib/codec.ml::parse_yaml_pairs` belongs
  in plan-2026-12-yaml-parser-fix with a regression test
  in `tests/yaml_parsing_test.ml` (multi-byte content of
  `claim: |`).
- Update `OCAML_KERNEL_CONVENTIONS.md` §11 trap log with the
  reorder pattern.
- Bump version to `v3.3.3` after F11 + F12 + Batch B + C
  all land.
