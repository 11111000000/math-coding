# Plan sub-agent prompt template

> **Status:** active.
> **Author:** orchestrator, 2026-10-18 (codified at
> `decisions/attestation-namespace-meta-2026-11@1`).
> **Use this file when:** a plan-doc (`docs/plans/plan-<id>-*.md`)
> needs a per-sub-decision prompt template that delegates the work
> to a sub-agent. Copy the bullets in §1–§5 into the
> sub-agent's initial prompt verbatim, substituting
> `<sub-decision-id>` and the sub-decision-specific scope.
>
> This template supersedes the ad-hoc format used in
> `docs/plans/plan-2026-10-adoption-fixes-2026-10-prompts.md`
> (the prior format had one section per (sub-decision, batch)
> pair; this template collocates the per-template rules so
> future plan-docs don't re-derive them).

## 0. Attestation-namespace reservation (binding on every sub-agent)

> Filenames of the form
> `attestations/plan-<id>-*-<obligation>.json` are **reserved**
> for plan-meta attestations only — i.e., for attesting the
> plan-decision's own obligations (`plan-document-exists`,
> `a1-sixteen-body-sha-fixed`, `no-self-check-regression`,
> etc.). Sub-decisions may NOT use the same filename stem.
>
> Sub-decisions may have plan-anchored attestation **content**
> (e.g., `material: parent-plan-<id>`) — that's a JSON
> field, not a filename. Filenames are governed by
> `scripts/generate-attestations.py::emit`, which always
> writes `<decision>-<obligation>.json` for the `decision`
> value in the manifest row. So the rule operationally is:
> the `decision` column in a sub-agent's TSV manifest MUST
> be the sub-decision's own ID, never the parent plan's
> ID. Sharing the parent plan's ID would produce
> `attestations/plan-<id>-<obligation>.json` and collide
> with the plan-meta attestations on the same (decision,
> obligation) namespace.

**Why this matters.** `lib/attestations/` de-duplicates on
first occurrence (no warning, no error — silent drop). When
two attestations claim the same `(decision, obligation)`
pair, the second is dropped on the floor at evaluation time.
A sub-agent that emits `<plan-id>-<obligation>.json` from
its own `--manifest` therefore deletes the plan-meta
attestation when both kernels converge. This is the
correctness-shaped failure mode the rule prevents.

**Verbatim copy-paste block for the sub-agent prompt:**

```text
Your attestation filenames must use the pattern
attestations/<sub-decision-id>-<obligation>.json.
DO NOT name a file attestations/plan-<parent-plan-id>-<obligation>.json
— that pattern is reserved for the parent plan's meta-attestations
(e.g., plan-document-exists, no-self-check-regression), and
lib/attestations/ silently drops the second attestation when two
files claim the same (decision, obligation) pair.

Concretely: in your TSV manifest, the first column is the
sub-decision's decision ID (the file under decisions/<sub-decision-id>.yaml
that you author), not the parent plan's decision ID.
```

## 1. Sub-agent prompt — per-sub-decision template

A sub-agent prompt has five sections. The first four are
binding on every sub-agent; the fifth is the sub-decision's
specific scope.

```
[1] Worktree and branch
  - Worktree-first: git worktree add ~/.paseo/worktrees/math-coding/<topic>
    -b <type>/<topic>/<YYYY-MM> <plan-integration-branch>
  - Branch naming: <type>-<topic>-<YYYY-MM>
    (Conventional Commits <type> scope; kebab-case <topic>;
    four-digit year and two-digit month, e.g. feat-bins-parser-2026-10).

[2] Decision file (P1, P2 closure)
  - decisions/<sub-decision-id>.yaml exists at the end of your work.
  - mode: minimal if docs-only;
    mode: light for non-kernel code change;
    mode: standard for any lib/ or bin/ or schemas/ edit.
  - axiom_link: must include A0 (separation) for every decision.
  - obligations: one verifier per obligation, paired with an attestation.

[3] Attestation filenames
  - See §0 above. <sub-decision-id>-<obligation>.json, NOT plan-* prefixed.
  - Generate attestations via:
      mathc attest-batch --manifest=$MATH_CODING_ATTESTATIONS_DIR/manifest.tsv
    with rows shaped:
      <sub-decision-id><TAB><obligation><TAB><kind_><TAB><producer><TAB>pass
  - kind_ for human review is "review" with producer identity
    "human:<workspace-name>".

[4] Verification gate (P6 pre-commit)
  - mathc validate decisions/<sub-decision-id>.yaml  → parse-ok
  - mathc self-check  → no NEW unknown subjects vs. the plan's baseline
  - dune build (only when scope includes lib/ or bin/ or tests/)  → exit 0
  - dune test  (only when scope adds or changes a test)  → exit 0

[5] Sub-decision-specific scope (substituted by the orchestrator)
  - Goal: <the paragraph from the plan-doc §4 sub-decision>
  - Files: <list of files in scope>
  - Acceptance: <the acceptance.items from plan-doc §4>
```

## A. P9 empty-scaffold commit (when scope spans kernel)

When a sub-decision's `scope.paths` includes `lib/`, `bin/`,
`schemas/`, or `axioms/`, ship the commit in the order:

1. **Scaffold commit first.** Decisions file lands as a
   separate commit, with body_sha / yaml_sha set to the
   all-zeros sha256 placeholder
   (`sha256:0000000000000000000000000000000000000000000000000000000000000000`).
   This is the P9 empty-scaffold pattern. The plan-decision's
   obligation to record the intent precedes the kernel edit
   the intent motivates. mathc validate accepts the zeros
   placeholder as parse-ok (the validator's pattern
   `^sha256:[0-9a-f]{64}$` matches `[0-9]{64}`).

2. **Kernel change commit(s) second.** The `lib/`, `bin/`,
   or `schemas/` edits ship after the decision is recorded.
   The body's body_sha / yaml_sha are recomputed and replaced
   in the same commit as the kernel edit (or in a follow-up
   commit if recomputation is platform-specific).

3. **Attestation commit third.** `mathc attest-batch
   --manifest=...` writes the JSONs. The attestation id is a
   sha256 of the JSON body (excluding the `id` field), so it
   is stable across re-emits as long as the manifest row is
   unchanged. Re-stamp only when the manifest row changes.

The scaffold-first ordering is enforced at the documentation
layer; `process-principles@3` P1 also enforces it at the
test layer (any change to `lib/`, `bin/`, or `schemas/` must
have a paired decision file under the active policy).

## C. Reorder principle (Batch ordering)

> Mirror of `process-principles@3` P4 (merge order, manual
> acceptance). The kernel cannot enforce this — it is an
> honest declaration of agent conduct.

When multiple sub-decisions land on the same integration
branch, integration order is:

```
sub-decisions data-only (decisions/ + attestations/ + scripts/)
  → sub-decisions touching lib/ pure helpers
    → sub-decisions touching bin/ (dispatch + subcommand body)
      → tests additions / changes
        → build + render artifacts
```

**Rationale.** A pure data-only sub-decision (F11-A1, F11-A2,
F11-B, F11-C in the F11 plan) ships without kernel change.
Pure sub-decisions can land in any order; kernel-scope
sub-decisions may have a dependency on a prior data-only
sub-decision (e.g., B1 in plan-2026-10 depends on A1's
env-var resolver). The dependency is recorded in each
sub-decision's plan-doc §4 entry; the integration order is
the topological order of those dependencies.

For a `super-seeded` situation (a sub-decision requires a
prior sub-decision's content), the orchestrator holds the
prompt for the dependent sub-decision until the dependency
merges. The sub-agent does not start work on a branch that
depends on an unmerged sibling.

## D. Atomic commits (one concern per commit)

A sub-agent's work may produce one or two commits, never
zero, never four:

- **One commit.** The sub-decision is a single concern
  (single decision file, single attestation batch, single
  kernel edit). One commit with the message
  `<type>(<sub-decision-id>): <imperative summary>`.

- **Two commits.** The first is the P9 scaffold (decision
  YAML, body_sha all-zeros); the second is the data + code
  change + recomputed body_sha + attestation batch. Both
  commits use the same `<sub-decision-id>` scope but
  different types: `scaffold(<sub-decision-id>)` and
  `feat(<sub-decision-id>)` (or `fix(<sub-decision-id>)`,
  `tweak(<sub-decision-id>)`, `attest(<sub-decision-id>)` —
  pick the type that matches the kernel change, not the
  metadata change).

- **Never zero.** A sub-decision is either implemented (one
  commit, or two, with the pair on the branch) or not.
  Never "I'll commit next session" — the orchestrator needs
  every sub-decision to land atomically to keep the
  per-sub-decision revertability guarantee in
  `process-principles@3` P4.

- **Never four or more.** Three is the hard cap (scaffold +
  data/code + attest). If a sub-decision needs four commits,
  the sub-decision is over-scoped: split it into two
  sub-decisions in the plan-doc before authorising.

## F11-B "deferred-to-followup" waiver block (pointer)

When a sub-decision obligation is partially done and the
remainder is out of scope for the current plan-doc, the
acceptance items use the
`deferred-to-followup-<YYYY-MM>` verifier as a waiver:

```yaml
  - id: <obligation-id>
    claim: |
      <one-paragraph claim that the obligation is partially
      done; the rest is recorded in the deferred plan>.
    acceptance:
      all:
        - verifier: deferred-to-followup-2026-12
          result: pass
```

The verifier string `deferred-to-followup-<YYYY-MM>` is the
single-line waiver: it asserts the obligation is deferred to
a named future plan-doc and that the current plan does not
ship the resolution. The kernel's `lib/decision.ml` accepts
the string as parse-ok (treated as a manual-style verifier
prefix). The orchestrator then opens the deferred plan in
the matching month; the obligation's verifier string carries
the month so the deferred plan can find it.

For the canonical exemplar, see
`decisions/plan-2026-11-validation-cleanup-2026-10.yaml`
obligations `b-counterexamples-filled` and `full-validate-clean`
(both deferred to plan-2026-12-validation-followup).

## 6. Commit-message convention (binding on every commit in plan work)

Every commit message subject follows Conventional Commits:

```
<type>(<scope>): <imperative summary, ≤72 chars>
```

- **type** ∈ {`feat`, `fix`, `tweak`, `docs`, `refactor`,
  `test`, `attest`, `scaffold`, `chore`, `release`, `plan`}.
  Conventional-Commits §1 lists the standard set; this
  template adds `attest`, `scaffold`, and `plan` because
  math-coding tracks the metadata-vs-data split explicitly.
- **scope** is the sub-decision ID without the date suffix
  (e.g., `attestation-namespace-meta-2026-11`,
  `verify-sandbox-hardening-2026-11`). For multi-decision
  commits, scope is the plan-decision ID
  (`plan-2026-11-validation-cleanup-2026-10`).
- **summary** is imperative mood, ≤72 chars, no trailing
  period. Examples:
  - `scaffold(verify-sandbox-2026-11): decision yaml scaffold (P9)`
  - `feat(verify-sandbox-2026-11): add --sandbox={none,minimal,strict}`
  - `attest(plan-F11-2026-11): close A1, A2, C plan-doc obligations`

A body paragraph (separated from the subject by a blank
line) explains the *why* and lists the file touched. The
body MUST name the relative file path of every file
changed in the commit, including tests and fixtures. This
keeps `git log --stat` and `git log --grep=<scope>` aligned
for the orchestrator's review pass.

## 7. Why this template

The first two plans that shipped sub-agent prompts
(`plan-2026-10-adoption-fixes`, `plan-2026-11-validation-cleanup`)
each carried their own prompt section per (sub-decision,
batch) pair. That approach does not scale: a 6-batch plan
produces 6 prompt sections of near-duplicate text, each
with the same boilerplate (worktree-first, decision file,
attestation filename, gate) but with subtle drift on
filenames and waiver strings. The drift accumulates as the
project ages; the collision-risk in §0 (the namespace rule
that motivated this template) is one symptom of the drift.

`docs/plans/plan-sub-agent-prompt-2026-11.md` (this file)
collapses the per-(sub-decision, batch) boilerplate into
five reusable sub-sections (the numbered list in §1 plus
A, C, D, and the F11-B pointer). Future plan-doc authors
copy the bullets verbatim and substitute their own scope
in §1[5].

A future plan-doc may supersede this template by archiving
the `attestation-namespace-meta-2026-11@1` decision and
filing a successor decision that moves the namespace rule
into `lib/attestations/` (a kernel-change-class follow-up,
not a docs-only change). Until that successor lands, the
rule is enforced at this documentation layer, where the
cost of enforcement is zero.
