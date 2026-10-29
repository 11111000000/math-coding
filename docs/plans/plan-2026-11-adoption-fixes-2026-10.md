# Plan: Adoption-fixes v2, 2026-11

> **Status:** active, approved 2026-10-18 by user sign-off.
> **Branch:** `plan/2026-11-adoption-fixes-2026-10` (off
> `release/v3.3.2-2026-10`).
> **Author:** orchestrator, 2026-10-18.
> **Companion decision:** `decisions/plan-2026-11-adoption-fixes-2026-10.yaml`.

## 0. Why this exists

The 2026-10-17 adoption experiment
(`docs/experiments/adoption-2026-10.md`) and the follow-on
`plan-2026-10-adoption-fixes` (closed in v3.3.2, 2026-10-18
04:09 UTC) landed 10 sub-decisions against 9 of the 9
experiment recommendations + 1 doctor-ship audit (R6/R7/R8/R4/R5/R3/R2/R1/R9/R10).

After the v3.3.2 release, four read-only **discriminator**
sub-agents (titles `Discriminator: F1–F4/F5–F8/F9–F12/F13–F15`)
audited the second-order consequences of the 10 shipped
sub-decisions and the broader 12-self-check-unknown tail.
They produced 15 findings (F1–F15) recorded in:
- `docs/experiments/discriminator-f1-f4-2026-10.yaml`
- `docs/experiments/discriminator-f5-f8-2026-10.yaml`
- `docs/experiments/discriminator-f9-f12-2026-10.yaml`
- `docs/experiments/discriminator-f13-f14-f15-2026-10.yaml`

P1 findings: F9 (verify sandbox absent), F10 (path-resolver
audit incomplete — 6–7 sites missed by A1), F14 (B1 was an
orchestrator rescue after Token Plan rate limit), F15
(shipped mathc 3.3.2 binary does not contain the fixes
because the locally-installed binary at `/home/az/.local/bin/mathc`
predates the sub-decision merges by ~4 hours).

This plan turns the 15 findings into 11 sub-decisions
(across 3 batches) plus 4 docs-only template fixes plus
1 out-of-band human-gated tag/release action.

## 2. Boundaries (A3 self-application)

- All sub-decisions land in 2026-10 → 2026-11. A successor
  plan may supersede; this one does not.
- No sub-decision modifies `lib/attestations/` or `lib/mcp/`
  beyond the strict scope of its sub-decision.
- No change to `decisions/decision.yaml` (the active policy).
- No change to `schemas/*.json` unless the sub-decision is
  specifically about a schema field.
- Every sub-decision produces a passing `mathc self-check`
  with the **same 12 pre-existing unknown subjects** as at
  HEAD `release/v3.3.2-2026-10` and zero NEW unknown
  subjects. This is the **kernel-stability precondition**.
  The 12 unknowns are owned by `audit-cleanup` (Category A
  re-attest) and the 7 waiver decisions (Category B); the
  plan zeros them out before Batch A starts.

## 3. Hypotheses

Each sub-decision must satisfy four pre-conditions, mirroring
plan-2026-10 §3:

1. The friction event or finding it addresses is recorded
   (≥ 1 of the 5 experiment reports or 4 discriminator
   YAMLs).
2. The fix does not regress any existing decision's verdict.
3. The fix produces a measurable improvement on the same
   metric that surfaced the issue (P95-attestation-noise,
   syscall-surface-isolation, env-var-coverage, etc.).
4. The fix is independently revertable in one commit.

## 4. Sub-decisions

### Batch A — kernel-critical, parallel (2 sub-decisions)

#### A1. `verify-sandbox-hardening-2026-11` (F9)

- **What.** Add `mathc verify --sandbox=<mode> <file>` with
  three modes — `none | minimal | strict`. Default
  `MATH_CODING_VERIFY_SANDBOX=none` for back-compat with
  `add-verify-subcommand-2026-10.yaml` acceptance criteria.
  In `strict`, before `Unix.execve`:
  - drop capabilities (best-effort `capset(2)` on Linux)
  - call `prctl(PR_SET_NO_NEW_PRIVS, 1)`
  - apply RLIMITs (CPU=60s, NPROC=1, NOFILE=64, FSIZE=target_max)
  - allowlist `mathc` scheme subcommands to read-only ones
    (`validate`, `assess`, `find`, `self-check`, `explain`,
    `explain-diagnostic`, `context`, `packages`, `do_pmd`)
- **Scope.** `bin/Mathc.ml::run_with_sandbox` lines 2761–2796,
  `bin/Mathc.ml::do_mathc_scheme` line 2813,
  `lib/path_config.ml::resolve_sandbox_mode`,
  `tests/cli/verify-sandbox.t` (new cram fixture).
- **Acceptance.** Cram fixture passes 3 cases:
  - `verifier: "rm -rf /tmp/x"` returns Skipped on `none`
  - `verifier: "file-exists /etc/shadow"` returns Pass on
    `none`, Fail on `strict+denylist`
  - `verifier: "mathc init"` returns Pass on `none`,
    Skipped on `strict+mathc-scheme-deny`
- **Risk.** Medium. OS-level sandboxing requires kernel +
  libcap-dev on Linux; macOS users keep `none`. The
  allowlist for `mathc` scheme (read-only subcommands only)
  is the minimum viable hardening.
- **Depends on.** None (orthogonal to A2).

#### A2. `path-resolver-audit-2026-11` (F10)

- **What.** One commit that fixes the 6–7 sites in
  `bin/Mathc.ml` that the original A1 (env-var resolver)
  missed:
  - L1417 `decision_relpath` — hard-codes
    `"decisions/decision.yaml"` and special-case ids
  - L2245/L2264 `do_record`/`do_stats` — hard-codes
    `decisions/execution-logs.jsonl`
  - L3523 `do_re_evaluate_decisions` — honours only legacy
    `MATH_CODING_ATTESTATION_STORE`, not canonical
    `MATH_CODING_ATTESTATIONS_DIR`
  - L4216 `do_render` — let bindings `decisions_root` /
    `attestations_root`
  - L5334 `do_decision_state` — hard-codes
    `<root>/decisions/<id>.yaml`
  - L6451/L6495 `do_doctor` config + decisions sections
  - L6696 `Policy.load_policies` — hard-codes
    `<root>/policies.yaml`, ignores `MATH_CODING_POLICY`
- **Scope.** `bin/Mathc.ml` only. Each site routes through
  `lib/path_config.ml::resolve_*` helpers.
- **Acceptance.** A grep for `decisions/`, `attestations/`,
  `policies.yaml` in `bin/Mathc.ml` returns no literal
  matches inside `Filename.concat` or `let <name> =`.
  Hermetic cram fixtures `tests/cli/execution-logs-env-var.t`,
  `tests/cli/re-evaluate-decisions-env-var.t`,
  `tests/cli/policy-env-var.t` exit 0.
- **Risk.** Medium. The `Policy.load_policies` site is
  highest-impact: enabling the documented three-tier
  precedence (env > `.math-coding/policy.yaml` > legacy
  `decisions/decision.yaml`) changes call ordering at
  startup.
- **Depends on.** None.

### Batch B — kernel+docs, after A (3 sub-decisions)

#### B1. `import-junit-rename-2026-11`

- **What.** `mathc attest FILE` currently parses JUnit XML
  on read but reads conflicting documentation that suggests
  writing JSON. Rename to `mathc import-junit FILE` for
  clarity; keep `mathc attest` as a deprecation alias
  emitting a one-shot stderr warning.
- **Scope.** `bin/Mathc.ml::dispatch` (one-line rename),
  `lib/attestations/import_junit.ml` (rename module if
  present), help text, `tests/cli/attest-deprecation-alias.t`.
- **Acceptance.** Fresh `mathc attest FILE` exit 0 with
  stderr `warning: 'mathc attest FILE' is deprecated; use
  'mathc import-junit FILE' for JUnit XML parsing`. The
  JSON-write path remains under a different subcommand.
- **Risk.** Low.
- **Depends on.** None.

#### B2. `scripts-env-var-audit-2026-11` (R5-continuation)

- **What.** `scripts/axiom-link-seed.py` and
  `scripts/counterexample-seed.py` (per R5 follow-on) write
  to math-coding's own tree and ignore
  `MATH_CODING_DECISIONS_DIR`. Add env-var support matching
  the kernel's behaviour.
- **Scope.** Two Python scripts.
- **Acceptance.** With `MATH_CODING_DECISIONS_DIR=/tmp/alt`,
  both scripts write to `/tmp/alt` instead of the math-coding
  tree.
- **Risk.** Trivial.
- **Depends on.** A2 (env-var semantics unified across Python + OCaml).

#### B3. `attestation-namespace-meta-2026-11` (F3)

- **What.** Codify the rule that **plan-decision-named
  attestation filenames are reserved for plan-decision
  attestations**. Sub-decisions may not use the same
  filename pattern; the sub-agent prompt template enforces
  this and the validator rejects collisions.
- **Scope.** `decisions/attestation-namespace-meta-2026-11.yaml`
  (process decision); update
  `decisions/plan-2026-10-adoption-fixes-2026-10.yaml`
  lines 122–290 (replace placeholder verifiers with real
  file-exists checks against the sub-decisions' attestation
  files).
- **Acceptance.** Future plan-doc-template enforces the
  rule in §6 below.
- **Risk.** Low (process / docs).
- **Depends on.** A2 (the plan's body uses the
  `file-exists path:` verifier scheme).

### Batch C — process+docs, parallel (6 sub-decisions)

#### C1. `process-principles-2026-10-2` (F2 → P8.5)

- **What.** Amend `decisions/process-principles.yaml` with a
  new principle P8.5: **no sub-agent launches until all
  declared dependencies are merged into the integration
  branch**. Sub-agents whose worktree base lacks a
  dependency must abort with a clear error message
  identifying the missing dep.
- **Scope.** `decisions/process-principles.yaml` rev 2 file.
- **Acceptance.** Decision file has rev 2; `git merge-base
  --is-ancestor <dep-branch> <integration-branch>` is the
  canonical pre-flight check documented.
- **Risk.** Trivial.

#### C2. `process-principles-2026-10-3` (F1 → P9)

- **What.** Amend `decisions/process-principles.yaml` with
  a new principle P9: **scaffold-commit + checkpoint
  cadence**. Sub-agents must commit an empty scaffold
  (`decisions/<id>.yaml` with `state: drafting` + a single
  `plan-stub` attestation) as the FIRST action, before
  writing any kernel code. Resumable from checkpoint on
  rate-limit interrupts.
- **Scope.** `decisions/process-principles.yaml` rev 3 file.
- **Acceptance.** Decision file has rev 3; P9 documented
  with concrete reproduce for Token Plan rate-limit case
  observed in B1 retry agent `3a90dc2b`.
- **Risk.** Trivial.

#### C3. `attest-handshake-rescue-2026-11` (F14)

- **What.** Codify the orchestrator-rescue recipe as a
  first-class workflow. When a sub-agent dies mid-task from
  Token Plan rate-limit, the parent must (a) archive the
  dead agent, (b) inspect worktree for uncommitted work,
  (c) commit that work as a single atomic change on the
  topic branch, (d) emit attestations with
  `producer.identity: human:opencode-agent` and a
  `rescue_reason: token-plan-rate-limit`
  marker, (e) re-record `body_sha`/`yaml_sha` correctly
  via `mathc validate` (not literal zeros).
- **Scope.** `decisions/attest-handshake-rescue-2026-11.yaml`.
- **Acceptance.** Decision file exists with rescue recipe
  §1–§5 and acceptance criteria mirroring B1's actual
  rescue (`add-verify-subcommand-2026-10.yaml`).
- **Risk.** Trivial (process recording).

#### C4. `release-cadence-2026-11` (F15)

- **What.** Add `.github/workflows/release-pending.yml`:
  a CI gate that blocks merge of any commit touching
  `bin/Mathc.ml`, `lib/*`, or `scripts/install-tooling/*`
  if a tagged release on that branch has not been re-built
  with the merged code. Also update
  `MC_VERSION_DEFAULT="3.3.2"` in
  `scripts/install-tooling/install.sh` to gate against the
  next tagged release.
- **Scope.** `.github/workflows/release-pending.yml` (new),
  `scripts/install-tooling/install.sh` (one-line bump).
- **Acceptance.** Triggered on PR open; emits
  `release-pending` status check; gate enforced in the
  repo's branch protection rule.
- **Risk.** Low (CI-only).
- **Depends on.** C2 (P9) so sub-agent commits trigger the
  gate.

#### C5. `verifier-scheme-convention-2026-11`

- **What.** `mathc validate` warns on unknown verifier
  schemes (anything not in
  `file-exists|dir-exists|mathc|shell-grep|bash`). The warn
  is a soft warning at validate time; the verifier is
  still accepted (Phase 0) but the operator is told the
  scheme is non-standard.
- **Scope.** `bin/Mathc.ml::validate_with_counts` (the
  diagnostic-emission site).
- **Acceptance.** `tests/cli/verifier-scheme-warning.t`
  passes — known scheme `file-exists` no warn; unknown
  scheme `false-positive` warns with
  `MC-VERIFIER-SCHEME-UNKNOWN` (soft).
- **Risk.** Trivial.

#### C6. `experiment-doctor-instrumentation-2026-11` (F13)

- **What.** Three docs-only changes to make `mathc doctor`
  a first-class experiment instrument:
  1. `docs/experiments/brownfield-experiment-v2-2026-10.md`
     §5 T1 — add step "Run `mathc doctor --json` and record
     status:fail sections".
  2. Same file §8 Phase 0 — insert preflight
     `Verify mathc doctor returns exit 0`.
  3. Same file §3 Hypotheses — add `BH9: doctor reports ≥
     7 healthy sections on ≥ 4 of 5 projects`.
  Plus a `decisions/experiment-doctor-instrumentation-2026-11.yaml`
  recording the convention for future experiment templates.
- **Scope.** One Markdown file + one decision YAML.
- **Acceptance.** Markdown edits apply; new decision validates.
- **Risk.** None (docs).

### §10 Template-fixes (docs-only, absorbed into plan-doc commit)

These four are pure Markdown/usage edits, no decision YAML:

- **F5.** Update `adoption/SKILL.md` Step 3.5 — note that
  the minimal-form template now emits `axiom_link: [A0]`
  default but operators should override after first edit.
- **F6.** Update `OCAML_KERNEL_CONVENTIONS.md` §11 trap log —
  add `§11.35` documenting the "literal-zero body_sha on
  rescue" pattern (cross-ref to F14).
- **F7.** Update `ROADMAP.md` Tier 2 — add row for
  `path-resolver-audit-2026-11` closing the F10 deficit.
- **F8.** Update `QUICKSTART.md` — mention `MATH_CODING_VERIFY_SANDBOX=strict`
  as a brownfield-bootstrap safety option.

### §11 Out-of-band human-gated (F15 OOB)

- **`oob-f15-tag-cut`** obligation:
  - `git tag v3.3.2` already exists at `f33b712` (cut 2026-10-18).
  - `git push origin v3.3.2` already executed.
  - `MC_VERSION_DEFAULT="3.3.2"` confirmed in
    `scripts/install-tooling/install.sh`.
  - `release-pending` CI gate implemented via C4 sub-decision.
- The next tag (`v3.3.3` or `v3.4.0-alpha`) will be cut
  after Batch A + first half of Batch B lands.

## 6. Sub-agent worktree protocol

Each sub-decision lands in its own worktree.

### Worktree naming

`<type>-<topic>-2026-MM` per the project's worktree-first
convention. Examples:
- `feat/verify-sandbox-2026-11`
- `fix/path-resolver-audit-2026-11`
- `feat/import-junit-rename-2026-11`
- `fix/scripts-env-var-audit-2026-11`
- `process/attestation-namespace-meta-2026-11`
- `process/process-principles-rev-2-2026-11`
- `process/process-principles-rev-3-2026-11`
- `process/attest-handshake-rescue-2026-11`
- `feat/release-cadence-2026-11`
- `feat/verifier-scheme-convention-2026-11`
- `docs/experiment-doctor-instrumentation-2026-11`

### Branch ordering

- **Batch A (A1 + A2):** launch in parallel in two
  worktrees from `plan/2026-11-adoption-fixes-2026-10`.
  Each PR lands independently.
- **Batch B (B1 + B2 + B3):** B2 depends on A2 landing;
  B1 and B3 independent. Launch after relevant A.
- **Batch C (C1–C6):** all six launch in parallel;
  independent of A and B (except C4 references C2 in
  docs).

### Common sub-agent instructions (P9 scaffold-commit)

Each sub-agent prompt enforces:

1. **P9 scaffold commit.** Sub-agent's FIRST action is
   `git commit --allow-empty -m "scaffold(<id>)"`
   followed by `git commit -m "feat(<id>): decision file
   and attestation"` after `mathc validate`. This makes
   the worktree resumable from any checkpoint.
2. **Worktree-first.** Sub-agent creates its own worktree
   via `git worktree add ~/.paseo/worktrees/math-coding/<topic>
   -b <type>-<topic>-2026-11 plan/2026-11-adoption-fixes-2026-10`.
3. **Pre-flight (P8.5).** For B/C sub-decisions with
   declared deps, run `git merge-base --is-ancestor
   <dep-branch> plan/2026-11-adoption-fixes-2026-10`;
   abort with dependency-missing error if not.
4. **Decision file.** Sub-agent writes
   `decisions/<sub-decision-id>.yaml` (mode `light` for
   docs-only; mode `standard` for kernel changes).
5. **mathc validate.** Sub-agent runs
   `mathc validate decisions/<id>.yaml` and fixes any
   `MC-*` diagnostic before commit.
6. **mathc self-check.** Sub-agent runs `mathc self-check`
   and verifies the verdict contains the same 12 pre-existing
   unknown subjects (already closed by Category A+B cleanup)
   and zero NEW unknown subjects attributable to this plan.
7. **Tests.** Sub-agent adds or extends a cram test in
   `tests/cli/<feature>.t` exercising the fix.
8. **No kernel regression.** Sub-agent runs `dune build`
   and `dune test`; both must exit 0.
9. **Atomic commit.** Sub-agent's change is one commit on
   the topic branch.
10. **No push.** Sub-agent does not push or open a PR.
    The orchestrator does that after the experiment reports.

## 7. Outcomes

The plan closes when, for every obligation below, the
sub-decision exists at `decisions/<id>.yaml` with
`state: active` and at least one matching attestation in
`attestations/` whose `kind_` is appropriate; the surface
change the sub-decision commits to has landed on `main` (or
`release/v3.3.x`); the change is exercised by a cram or
conformance test; and `mathc self-check` returns
`verdict: "pass"` or returns `verdict: "unknown"` with the
**same 12 pre-existing unknown subjects** (closed by the
Category A re-attestation + Category B waivers which are
in-scope preparation) and zero NEW unknown subjects.

The 11 sub-decisions cover the 15 findings F1–F15 plus
the 4 template fixes (F5–F8). Each sub-decision is
independently revertable in one commit; the plan survives
any single sub-revert.

## 8. Out of scope

- Changes to `lib/attestations/` or `lib/mcp/` beyond each
  sub-decision's strict scope.
- Changes to `decisions/decision.yaml`.
- Kernel changes that are not in the 11 sub-decisions above.
- The brownfield-experiment v2 *execution* (only the
  plan-doc updates are in scope for C6; the actual run is
  a separate future worktree).
- Push to upstream of any external project (this plan
  makes no changes to external projects).
- More than 11 sub-decisions or a longer time horizon than
  2026-10 → 2026-11.

## 9. Risks

- **kernel-stability precondition** (A1, A2, C4, C5 in
  particular): any kernel change risks regressing the
  self-check verdict. Mitigated by the per-sub-decision
  `no-self-check-regression` obligation.
- **A1 sandbox Linux-only**: macOS keeps `none` mode.
  Brownfield-v2 agents on macOS would not benefit; the
  threat model primarily applies to Linux CI runners.
- **A2 path-resolver scope**: missing even one site causes
  silent split-brain (read vs write dirs). The grep-absence
  test (`bin/Mathc.ml` has no `decisions/` literal in
  `Filename.concat` or `let <name> =`) is the safety net.
- **C4 release-pending gate**: this CI gate changes the
  PR-merge experience; reviewers must adopt the new
  status check before merge.
- **B3 attestation namespace**: changing the verifier
  pattern on the plan-decision may regress already-passing
  attestations if not tested in isolation. Coordinate with
  A2.
- **Sub-agent Token Plan rate limit (F14 replay risk)**:
  if C2 P9 lands before agent deployment, the B1 failure
  pattern is prevented; if not, we are one rate-limit away
  from another rescue.

## 13. Recommendations (post-plan)

After all 11 sub-decisions land and the plan closes, a
follow-up plan (`plan-2026-12-adoption-fixes` or successor)
should consider:

- Whether `mathc verify` should default to `minimal` mode
  after one or two release cycles (currently `none`).
- Whether `MATH_CODING_VERIFY_SANDBOX` enforcement should
  move from opt-in to always-on for the `mathc` scheme.
- Whether the brownfield-experiment v2 results (post-v2 plan)
  suggest further changes to `mathc adopt` (F10 finding
  already covered the kernel side, but the surface UX
  deserves a follow-up).
- Whether to bump version to `v3.4.0-alpha` (instead of
  `v3.3.3`) given the surface change scope.

The post-plan recommendations are *not* in this plan's
scope. They belong to a successor plan.
