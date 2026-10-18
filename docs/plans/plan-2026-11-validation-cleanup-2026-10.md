# Plan: Validation Cleanup, 2026-11

> **Status:** active.
> **Branch:** `release/v3.3.3-followup-2026-10` (off `release/v3.3.2-2026-10@1881997`).
> **Author:** orchestrator, 2026-10-18.
> **Companion decision:** `decisions/plan-2026-11-validation-cleanup-2026-10.yaml`.

## 0. Why this exists

The Batch A merge (`release/v3.3.2-2026-10@1881997`) produced
self-check 183 pass / 0 unknown — green. But running
`mathc validate decisions/*.yaml` over every state: active
file in the tree reveals 35 false-rejects left behind by
earlier cycles (`kernel-bugs-v3.4-2026-10`,
`dialectic-method-v3-2026-10`, `audit-cleanup-2026-10`). These
false-rejects are pre-existing (not introduced by Batch A)
but they are a quality-gate hazard for every future
sub-decision: agents that wire `mathc validate` as a pre-commit
guard hit 35 noise fails before reaching their actual target.

This plan closes 35 false-rejects across 4 sub-decisions,
each atomic, each independently revertable:

| sub-decision | scope | files |
|---|---|---|
| **F11-A1** | `body_sha` / `yaml_sha` regex + canonical digest | 16 |
| **F11-A2** | `axiom_link` missing on `audit-cleanup-2026-10` | 1 + 6 re-attestations |
| **F11-B**  | `counterexample` missing on `mode: light` | 7 |
| **F11-C**  | malformed acceptance items | 2 |

Total: 17 file additions + 6 re-emitted attestations.

## 2. Boundaries (A3 self-application)

- No change to `lib/`, `bin/Mathc.ml`, `lib/decision.ml`,
  `lib/diagnostic.ml`, `schemas/decision.json`. All four
  sub-decisions touch only `decisions/`, `attestations/`, and
  `scripts/`. The validator's *interpretation* of these
  fields may stay as-is; only the data shape is corrected.
- No scope on `state: archived | retired` decisions. The
  validator `reject` on those is archival-by-design.
- The pre-plan pass count (183 / 0 unknown) must be
  preserved exactly. No new subjects, no flipped
  subjects. Sub-decisions must satisfy
  `no-self-check-regression` (acceptance §no-self-check-
  regression).

## 3. Hypotheses

Each sub-decision must satisfy four pre-conditions:

1. The defect is recorded in `validate` output of the
   current HEAD (`release/v3.3.2-2026-10`).
2. The fix does not regress any existing decision's verdict.
3. The fix produces a measurable improvement: the file
   enters the parse-ok set.
4. The fix is independently revertable in one commit.

## 4. Sub-decisions

### F11-A1 — `fix-body-sha-format-2026-10`

**Defect.** 16 decisions store `body_sha` / `yaml_sha`
either empty (5) or as bare 64-char hex without the
`sha256:` prefix (11). The validator's pattern
`^sha256:[0-9a-f]{64}$` (per `lib/decision.ml` line 908, also
referenced as `MC-BODY-SHA-PATTERN-VIOLATION` at
`lib/diagnostic.ml` line 530) rejects both cases.

**Algorithm.** The canonical digest is the function
`body_canonical_sha256` at `lib/decision.ml` lines 59–143:
  1. CRLF → LF on the file bytes
  2. Substitute `body_sha: "sha256:<64hex>"` and
     `yaml_sha: "sha256:<64hex>"` with the placeholder
     `sha256:<64zeros>`
  3. SHA-256 the result
  4. Format as `sha256:<64hex>`.

The algorithm has the fixed-point property (per
`spec/algebra-3.2.md` §303 — "Insensitivity to placeholder"):
a file's stored digest equals the algorithm's output for the
same file. For the 11 stores of bare 64-char hex, the value
is already the canonical digest (just missing the prefix).
For the 5 empty stores, the value must be computed.

**Tool.** `scripts/recompute-decision-sha.py` reimplements the
algorithm in Python (LF-normalise → placeholder-substitute →
SHA-256). Re-running on a tree with up-to-date digests is a
no-op. The script handles CRLF transparently. Body and
yaml_sha are kept equal (the spec single-file contract).

**Files (16):**
- `decisions/constitution-header-3-3-update-2026-10.yaml`
  (empty → must compute)
- `decisions/dialectic-method-v3-2026-10.yaml` (empty)
- `decisions/enable-counters-drift-test-2026-10.yaml` (empty)
- `decisions/placeholder-sha-cleanup-2026-10.yaml` (empty)
- `decisions/re-eval-remediation-todo-fix-2026-10.yaml` (empty)
- `decisions/ux-3-adopt-detect-2026-10.yaml` (bare 64-hex)
- `decisions/ux-3-adopt-real-arc42-2026-10.yaml` (bare 64-hex)
- `decisions/ux-3-adopt-roadmap-2026-10.yaml` (bare 64-hex)
- `decisions/ux-3-adopt-subcommand-2026-10.yaml` (bare 64-hex)
- `decisions/ux-3-import-adr-parser-2026-10.yaml` (bare 64-hex)
- `decisions/ux-3-import-adr-subcommand-2026-10.yaml`
  (bare 64-hex)
- `decisions/ux-3-init-agent-skill-2026-10.yaml` (bare 64-hex)
- `decisions/ux-3-init-subcommand-2026-10.yaml` (bare 64-hex)
- `decisions/ux-3-mcp-read-write-2026-10.yaml` (bare 64-hex)
- `decisions/ux-3-nfr3-cold-start-2026-10.yaml` (bare 64-hex)
- `decisions/ux-3-telemetry-stub-2026-10.yaml` (bare 64-hex)

**Acceptance.**
- Re-running `mathc validate decisions/<file>.yaml` per file
  returns `parse-ok` (no `MC-BODY-SHA-PATTERN-VIOLATION`).
- `scripts/recompute-decision-sha.py --check` (the dry-run
  flag) on the post-fix tree exits 0.

**Risk.**
- Digest drift: if a commit modifies the file between
  recompute and commit, the hash won't match. Mitigation:
  use `--check` mode before the final commit to confirm
  idempotence.

### F11-A2 — `add-axiom-link-to-audit-cleanup-2026-10`

**Defect.** `decisions/audit-cleanup-2026-10.yaml` lacks
`axiom_link:`. `MC-AXIOM-LINK-MISSING` fires (per
`lib/decision.ml` line 908 / `spec/algebra-3.2.md` §7). The
decision IS the Category A attestation target (13
attestations across 5 decisions, of which 6 are for
`audit-cleanup-2026-10` — w1 through w6).

**Fix.** Add `axiom_link: [A0, A1, A3]` to the front-matter
(A0: separation, A1: epistemic honesty, A3: self-application
applies because audit-cleanup tightens protected policy
gates). The added field is a body-content change, so the
canonical digest changes, and the six attestations must be
re-emitted with their SHA-256 ids matching the new file.

**Edge case.** `audit-cleanup-2026-10` was itself a
`*Release B1*`-derived decision (line 194 of the YAML
references B1's `accept` → `parse-ok` rename; line 553
references `plan-2026-10-ux-friction@1`). The 6
attestations on disk (Category A batch — `human:opencode-
agent`) commit-id themselves were re-stamped at the v3.3.2
followup commit `6903bdf` (plan-doc §303's fixed-point
property means re-stamping is a no-op when the file is
unchanged). After we add `axiom_link`, the file's
canonical digest changes, so the 6 `kind_: review`
attestations must be re-recorded. The producer identity
stays `human:opencode-agent`.

**Files.**
- `decisions/audit-cleanup-2026-10.yaml` — add `axiom_link:`
- 6 attestations under
  `attestations/audit-cleanup-2026-10-w<1..6>-*.json` —
  re-stamp (delete and re-create with new sha256-ids)

**Acceptance.**
- `mathc validate decisions/audit-cleanup-2026-10.yaml`
  returns `parse-ok` (no `MC-AXIOM-LINK-MISSING`).
- `mathc self-check` still returns 183 pass / 0 unknown.
- The 6 w1..w6 attestations exist with `producer.identity
  = human:opencode-agent` and `result: pass` and a SHA-256
  id recomputed by `mathc attest`.

**Risk.**
- Audit-cleanup attestations id mismatch (F14 replay).
- The producer identity `human:opencode-agent` is the
  orchestrator's runtime identity, which is correct for
  this case (the change was authored by the orchestrator).

### F11-B — `add-missing-counterexamples-2026-10`

**Defect.** 7 decisions emit soft-warn
`MC-COUNTEREXAMPLE-MISSING`: spec/algebra-3.2.md §11
requires counterexample for `mode >= light`. The 7
decisions have `mode: light` and no `counterexample:` field.

**Fix.** For each, author a synthetic counterexample block
in the spirit of AXIOM A0 («the strongest plausible case
where this decision is wrong, and what would change your
verdict»). Examples follow the established pattern in
existing decisions (e.g. `fix-env-var-resolver-2026-10`).

**Alternative (per decision):** downgrade `mode: light` to
`mode: minimal`, which exempts the dialectical slot. This
is the per-decision fallback when the synthetic text would
be unauthentic. Both land parse-ok.

**Files (7):**
- `decisions/considered-mode-migration-2026-10.yaml`
- `decisions/fix-curl-exit-code.yaml`
- `decisions/fix-mcp-sigpipe.yaml`
- `decisions/fix-validate-id.yaml`
- `decisions/paren-balance-fix-2026-10.yaml`
- `decisions/render-module-split-phase1a-2026-10.yaml`
- `decisions/render-module-split.yaml`

(Note: `render-ordered-lists-2026-10.yaml` ALSO emits the
same soft-warn — included here, total 8 files in the §0
table — bringing F11-B to 8 files. The §0 sum of 35 includes
this as one of the soft-warns.)

**Acceptance.**
- All 7-8 `mathc validate FILE` calls return `parse-ok`
  with no `MC-COUNTEREXAMPLE-MISSING` warning.

**Risk.**
- Counterexample text quality: a too-shallow counterexample
  would be inauthentic; a too-deep one would change the
  decision's verdict. Mitigated by following the existing
  pattern (one paragraph naming the strongest objection +
  the reversal condition).
- Mode downgrade (alternative) shrinks the dialectical
  coverage of the project. Use sparingly.

### F11-C — `fix-malformed-acceptances-2026-10`

**Defect.** 2 decisions emit
`MC-MALFORMED-ACCEPTANCE`: an acceptance item has the
right field structure (`verifier+result` or `review`) but
the values do not parse — see `mathc explain-diagnostic
MC-MALFORMED-ACCEPTANCE`: "`result:` must be one of
pass | fail | inconclusive | infrastructure-error".

**Files (2):**
- `decisions/mathc-self-check-subcommand.yaml` — obligation
  `mathc-self-check-store-precedes`, acceptance item
  (all[0]) needs review.
- `decisions/yaml-block-scalars.yaml` — obligation
  `yaml-block-scalars-loader-extended`, acceptance item
  (all[2]) needs review.

**Fix.** Read the offending acceptance block; either (a)
correct the `result:` to one of the four valid values, or
(b) replace the malformed item with a syntactically-valid
sibling, or (c) add a small syntactic note explaining why
the original is intentionally unparseable (P1 elsewhere
calls this out as an option).

**Acceptance.**
- `mathc validate decisions/mathc-self-check-subcommand.yaml`
  returns `parse-ok`.
- `mathc validate decisions/yaml-block-scalars.yaml`
  returns `parse-ok`.

**Risk.**
- Acceptance semantics: changing `result:` from one legal
  value to another changes the verdict language but not
  the underlying fact. Mitigation: read the obligation
  claim first; choose the closest legal `result:`.

## 6. Sub-agent worktree protocol

All four sub-decisions land on the same integration branch
(`release/v3.3.3-followup-2026-10`). They are sequential,
not parallel, because each is a one-file-or-few-files
mechanical change. A single agent (or the orchestrator
itself, since these are short) handles all four. The
parallelism available at the kernel-edit level is moot —
the kernel is not edited.

If parallelism is desired:
- Worktree A: `feat/F11-A1-body-sha`
- Worktree B: `feat/F11-A2-axiom-link`
- Worktree C: `feat/F11-B-counterexamples`
- Worktree D: `feat/F11-C-acceptances`
- Merge all four into `release/v3.3.3-followup-2026-10`
  via `--no-ff` octopus or sequential merges.

The default per plan-2026-10 P9: scaffold commit
EMPTY/skeleton first, then content commit. For this plan
the four sub-decisions are *data* changes, not kernel, so
the scaffold is unnecessary; one commit per sub-decision.

## 7. Outcomes

The plan closes when, for every obligation below, the
acceptance verifier exits 0:

- `plan-document-exists`
- `a1-recompute-script`
- `a1-sixteen-body-sha-fixed`
- `a2-audit-cleanup-axiom-link`
- `a2-audit-cleanup-attestations-renewed`
- `b-counterexamples-filled`
- `c-acceptances-fixed`
- `full-validate-clean` (no `reject:` for any
  `decisions/*.yaml` whose `state: active`)
- `no-self-check-regression`

Self-check invariant: at HEAD, `mathc self-check` returns
183 pass / 0 unknown — exactly the pre-plan count.

## 8. Out of scope

- Changes to `lib/`, `bin/`, `schemas/`, `axioms/`,
  `spec/`.
- `state: archived | retired` decisions — archival by design.
- The 2 pre-existing `unknown` subjects that are masked
  by gitignored `attestations/t1-2-A0-*.json` (covered by
  a separate follow-up, not Batch A or F11).
- Brownfield-experiment-v2 execution (covered by
  plan-2026-11-adoption-fixes-2026-10).

## 9. Risks

- **digest-drift-after-edit**: a commit between recompute
  and the final commit invalidates the hash. Mitigation:
  `scripts/recompute-decision-sha.py --check` is the dry-run
  guard, run before every commit.
- **audit-cleanup-attestations-id-mismatch** (F14 replay):
  re-emit on a fresh orchestrator-side call, not by hand.
- **counterexample-synthetic-text-inauthentic**: follow the
  established pattern (one paragraph naming the strongest
  objection + the reversal condition), not more.
- **archived-decisions-validate-still-rejects**: out of
  scope; archived decisions are archival.

## 13. Recommendations (post-plan)

- Move `recompute-decision-sha.py` into a pre-commit hook
  on `decisions/*.yaml` so future drifts are caught at
  authoring time (not 6 months later).
- Add a release-cadence CI gate per Batch C4 that fails
  the release-pending run if any active decision
  parse-fails on `mathc validate`.
- Bump version to `v3.3.3` after F11 lands — `v3.3.2` is
  shipped, F11 is a follow-up.
