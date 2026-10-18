# Plan: 2026-11 Adoption-fixes, second-round

> **Status:** design draft, awaiting user sign-off. No execution.
> **Branch:** `plan/2026-11-adoption-fixes-2026-10` (off
> `release/v3.3.2-2026-10`).
> **Author:** orchestrator agent, 2026-10-18.
> **Companion decision:** `decisions/plan-2026-11-adoption-fixes-2026-10.yaml`.

## 0. Why this exists

The 2026-10-17 brownfield experiment
(`docs/experiments/adoption-2026-10.md`) surfaced 9
recommendations. Plan `plan-2026-10-adoption-fixes-2026-10`
shipped fixes for all 9 — but the fix process itself surfaced
**15 second-order findings** (F1–F15) in
`docs/experiments/adoption-fixes-discriminator-2026-10.md`.
Four parallel discriminator agents verified these findings
(2 confirmed, 5 qualified, 0 refuted per batch; details in
`docs/experiments/discriminator-*.yaml`). Of the 15, **9 are
confirmed**, **5 are qualified** (real but partially overstated
or with a less-bad scope than the orchestrator claimed), and
**0 are refuted**.

This plan turns the surviving findings into sub-decisions
under the existing `process-principles` amendment chain
(rev 2 + rev 3) and a new generation of kernel and docs
sub-decisions.

## 2. Boundaries (A3 self-application)

- All sub-decisions land in 2026-10–2026-11. A successor
  `plan-2026-12-…` may supersede.
- No change to `decisions/decision.yaml` (the active policy).
- No change to `schemas/*.json` except where a sub-decision
  is specifically about a schema field.
- Every sub-decision produces a passing `mathc self-check`
  with the same 12 unknown subjects (post-v3.3.2) and **zero
  NEW unknown subjects** attributable to this plan.
- **F15 is treated as a human-gated out-of-band action** (cut
  tag, force-tag, push). It is recorded in this plan's
  sub-decisions but is not delegated to a sub-agent.

## 3. Hypotheses

1. **The 9 confirmed findings each represent a real
   adoption-friction** that, if left unaddressed, will
   reproduce in the brownfield-experiment v2.
2. **The 5 qualified findings are real-but-narrower**: the
   orchestrator's analysis over-stated some, but each has a
   defensible kernel or docs change to make.
3. **The current 5-code `process-principles` mechanism is
   sufficient** to absorb the new sub-decisions via rev 2 + rev 3
   amendments. No new axiom links needed.
4. **F15 (release-pipeline gap) is the most urgent** because
   the v3.3.2 commit landed without a tag, so the 10 fixes in
   this plan's baseline are not yet visible to end users.

## 4. Sub-decisions

### Batch A — kernel-critical, parallel (2 sub-decisions)

**A1. `verify-sandbox-hardening-2026-11`** (F9, P1)

- **What.** Add `mathc verify --sandbox=<mode> FILE` with
  three modes (`none | minimal | strict`). In `strict` mode,
  before `Unix.execve`: drop capabilities via
  `capset(2)` to empty `cap_bset`; call
  `prctl(PR_SET_NO_NEW_PRIVS, 1)`; apply `RLIMIT_CPU=60s`,
  `RLIMIT_NPROC=1`, `RLIMIT_NOFILE=64`,
  `RLIMIT_FSIZE=write_target_max`. The `mathc` verifier scheme
  in `strict` mode is restricted to a hard-coded allowlist of
  read-only subcommands (`validate`, `assess`, `find`,
  `self-check`, `explain`, `explain-diagnostic`, `context`,
  `packages`); write-capable subcommands (`init`,
  `new-decision --write`, `import-adr --write`, `attest-batch`,
  `decision-state`) are refused.
- **Scope.** `bin/Mathc.ml` lines 2761-2796 (run_with_sandbox),
  line 2813 (mathc scheme), `lib/path_config.ml` (add
  `resolve_sandbox_mode` reading `MATH_CODING_VERIFY_SANDBOX`).
- **Acceptance.**
  - `verifier: "rm -rf /tmp/x"` returns `Skipped` (mode
    `none`), `Skipped` (`minimal`), `Skipped` (`strict`).
  - `verifier: "file-exists /etc/shadow"` returns `Pass`
    (none, minimal) and `Fail` (strict + denylist).
  - `verifier: "mathc init"` returns `Pass` (none) and
    `Skipped-strict` (strict + mathc-scheme deny).
  - Cram fixture `tests/cli/verify-sandbox.t` exercises
    all three cases.
- **Risk.** Medium. New `OCaml` sandbox primitives (`capset`,
  `prctl`) are Linux-only; macOS users keep `none` only.
  Document the platform limitation.
- **Depends on.** None.

**A2. `path-resolver-audit-2026-11`** (F10, P1, qualified)

- **What.** Wire the 6 missed call sites in `bin/Mathc.ml`
  through `Path_config.resolve_decisions_dir ()` /
  `resolve_attestations_dir ()` / `resolve_policy_path ()`:
  1. `decision_relpath` (line 1417-1423) — special-case
     `bootstrap-v3`, `infrastructure-honesty`,
     `kernel-conformance-runner`, `validate-and-context`.
  2. `do_record` write (line 2245) — JSONL telemetry
     `decisions/execution-logs.jsonl`.
  3. `do_stats` read (line 2264) — same path.
  4. `do_re_evaluate_decisions` (line 3523-3527) — currently
     honours legacy `MATH_CODING_ATTESTATION_STORE` only;
     should honour canonical `MATH_CODING_ATTESTATIONS_DIR`.
  5. `do_render` (line 4216-4217) — `decisions` and
     `attestations` constants for `Attestations.load`.
  6. `do_decision_state` (line 5334) — read+write of
     `<id>.yaml`.
  7. `do_doctor` (line 6451, 6495) — `config` and
     `decisions` sections.
  8. `dispatch` policy loader (line 6696) — currently
     hard-codes `<root>/policies.yaml`; should honour
     `MATH_CODING_POLICY` env-var.
- **Scope.** `bin/Mathc.ml` only.
- **Acceptance.**
  - Grep `bin/Mathc.ml` for `decisions/`, `attestations/`,
    `policies.yaml` returns only literal matches inside
    comments and documentation strings, not inside
    `Filename.concat` / `let <name> =`.
  - Cram fixtures: `tests/cli/{execution-logs-env-var,
    re-evaluate-decisions-env-var, policy-env-var}.t`.
- **Risk.** Low. These are 1-line edits each; the resolver
  helpers already exist.
- **Depends on.** None.

### Batch B — kernel/docs medium, after A (3 sub-decisions)

**B1. `import-junit-rename-2026-11`** (F12, P2)

- **What.** Rename `mathc attest FILE` → `mathc import-junit
  FILE`. Keep `mathc attest` as a one-cycle deprecation alias
  (emits a one-shot stderr warning per session; removal
  planned for v3.6).
- **Scope.** `bin/Mathc.ml:6709` (dispatch), `:683-690`
  (print_usage), error-text references at `:2424, :2427,
  :2452, :2456`, `tests/cli/junit-adapter.t` (rename call
  site), new `tests/cli/attest-deprecation-alias.t`, and the
  two wrong prose claims in `adoption/SKILL.md:233, :423-424`
  (replace "writes" with the correct semantics).
- **Acceptance.**
  - `mathc import-junit FILE` exits 0 on a JUnit XML input.
  - `mathc attest FILE` exits 0 AND prints the deprecation
    warning to stderr (test asserts both).
  - `mathc --help` lists `import-junit` as the canonical
    name; the deprecation note is visible.
- **Risk.** Low. Backwards-compatible via the alias; the
  only callers in-tree are tests + docs.
- **Depends on.** None.

**B2. `scripts-env-var-audit-2026-11`** (F11, P2, qualified)

- **What.** Two real offenders (not the orchestrator-named
  ones — the discriminator caught that `slack2madr.py` and
  `confluence2madr.py` are pure transforms and DO NOT have
  the issue):
  1. `scripts/axiom-link-seed.py:64` — replace hard-coded
     `REPO_ROOT / "decisions"` with `os.environ.get`
     lookups for `MATH_CODING_REPO_ROOT` and
     `MATH_CODING_DECISIONS_DIR`.
  2. `scripts/counterexample-seed.py:75` — same pattern
     with `MATH_CODING_DECISIONS_DIR`.
- **Scope.** Two `scripts/*.py` files only.
- **Acceptance.**
  - Cram probe `tests/cli/scripts-env-var.t` sets
    `MATH_CODING_DECISIONS_DIR=.math-coding/decisions`,
    runs each script in `--dry-run` mode, asserts the
    resolved dir is reported correctly.
- **Risk.** Very low.
- **Depends on.** None.

**B3. `attestation-namespace-meta-2026-11`** (F3, P2)

- **What.** Resolve the F3 naming-collision via option (b)
  from the F1–F4 discriminator: codify the convention that
  "plan-decision-named filenames are reserved for
  plan-decision attestations only". Sub-decision agents
  writing about a sub-decision obligation do not write
  to a filename starting with `plan-*-*`. Option (a) — full
  `_plan-meta/` namespace + scanner update — is deferred to
  plan-2026-12.
- **Scope.** `docs/plans/plan-2026-10-adoption-fixes-2026-10-prompts.md`
  (5-line addition); new `decisions/attestation-namespace-meta-2026-11.yaml`
  (light) records the rule.
- **Acceptance.**
  - Plan-doc v-next prompts include the rule.
  - A grep across `decisions/` for filenames matching
    `plan-*-*.json` returns 0 results (the new plan uses
    `<plan-id>-<obligation>.json` only via this sub-decision's
    own attestations).
- **Risk.** Trivial.
- **Depends on.** None.

### Batch C — process / docs, parallel (6 sub-decisions)

**C1. `process-principles-2026-10-2.yaml`** (F2, P2, light)

- **What.** Process-principles rev 2 amendment. Add
  principle P8.5: "no sub-agent launches until all declared
  dependencies are merged into the integration branch".
  Pre-flight gate in the sub-agent template:
  ```
  1. Resolve declared dependencies: <list-of-deps>
  2. For each <dep>: `git merge-base --is-ancestor
     <dep-branch> <integration-branch>` exits 0
  3. ONLY THEN: `git worktree add …`
  ```
- **Scope.** `decisions/process-principles.yaml` (one-line
  addition); `docs/plans/plan-2026-11-…-prompts.md`
  (5-line addition).
- **Risk.** Trivial. Process-only.
- **Depends on.** None.

**C2. `process-principles-2026-10-3.yaml`** (F14, P1, light)

- **What.** Process-principles rev 3 amendment. Add
  principle P9: "Sub-agents MUST commit a `wip(scaffold):`
  draft at task start and `wip(checkpoint):` commits every
  5 minutes of active work. The orchestrator MUST verify
  these are present in the worktree's reflog before accepting
  the sub-agent's `pass` claim." Add the scaffold-commit
  block to every per-task prompt template.
- **Scope.** `decisions/process-principles.yaml` (one
  paragraph addition); prompt template update; one-line
  sub-agent prompt prefix.
- **Acceptance.**
  - Five-agent run completes 100% of obligations without
    manual orchestrator rescue (acceptance criterion
    recorded; measured over the next plan-2026-11 cycle).
- **Risk.** Trivial. Process-only.
- **Depends on.** None.

**C3. `attest-handshake-rescue-2026-11.yaml`** (F14, P3, light)

- **What.** Codify the orchestrator-rescue recipe: when a
  sub-agent dies mid-work and the orchestrator completes the
  remaining work, the rescue is first-class workflow. Rules:
  (i) when rescue is permitted (rate-limit-induced failure
  with partial work present, evidenced by worktree last-commit
  SHA and agent log tail); (ii) minimum evidence to record
  (worktree SHA, agent log tail, recovered file paths);
  (iii) the obligation it closes (the `<id>-<obligation>`
  matching the partial work).
- **Scope.** `decisions/attest-handshake-rescue-2026-11.yaml`
  (light, scope: docs + ad-hoc).
- **Risk.** Trivial.
- **Depends on.** C2 (the scaffold-commit pattern is the
  prerequisite for rescue to be safe).

**C4. `release-cadence-2026-11.yaml`** (F15, P1, light)

- **What.** Record the release-cadence rule. Every release
  commit on a `release/vX.Y.Z-YYYY-MM` branch MUST be
  followed by: (i) `git push origin vX.Y.Z` to trigger
  `release.yml`; (ii) `scripts/sync-version.sh --write` to
  update `MC_VERSION_DEFAULT` and `compatible_with`;
  (iii) `scripts/dev ready` to confirm CI green, within 24
  hours of the release commit landing on main. Otherwise
  the `release-pending` CI gate fails.
- **Scope.** `decisions/release-cadence-2026-11.yaml`
  (light); `CONTRIBUTING.md` §Release protocol (5-line
  addition); new `scripts/release.sh` template script.
- **Acceptance.** The rule is documented; the
  `release-pending` CI step is implemented.
- **Risk.** Low. Process-only, with one small CI change.
- **Depends on.** None.

**C5. `verifier-scheme-convention-2026-11.yaml`** (F4, P3, light)

- **What.** Record the verifier-scheme rule. Verifier
  strings MUST be either one of the 3 built-in schemes
  (`file-exists`, `dir-exists`, `mathc`) OR a documented
  command that an external runner executes; placeholder
  strings that match neither pattern are warned on by
  `mathc validate` (not rejected — may be valid in the
  runner sense). Plus: replace the one placeholder verifier
  in the plan-2026-11-decision's obligations with a
  `mathc self-check` invocation.
- **Scope.** `lib/decision.ml` (warn-on-unknown-scheme,
  ~30 lines); new cram fixture `tests/cli/verifier-scheme-warning.t`;
  `OCAML_BEST_PRACTICES.md` §11 trap log entry.
- **Acceptance.**
  - `mathc validate` on a decision with `verifier: "foo-bar"`
    emits a soft-warn (not reject).
  - The 4 placeholder verifier strings in
    `add-verify-subcommand-2026-10.yaml` and the plan-decision
    are replaced.
- **Risk.** Trivial.
- **Depends on.** None.

**C6. `experiment-doctor-instrumentation-2026-11.yaml`** (F13, P3, light)

- **What.** Add `mathc doctor --json` exercise to the
  brownfield-experiment v2 task templates. T1: capture
  doctor output; any `status: fail` section is a friction
  event id `<session>-F-DOCTOR-<n>` under F-INSTALL. Add
  BH9 hypothesis: "mathc doctor reports ≥ 7 healthy sections
  on a fresh install on ≥ 4 of 5 projects".
- **Scope.** `docs/experiments/brownfield-experiment-v2-2026-10.md`
  (3 doc edits); decision `experiment-doctor-instrumentation-2026-11.yaml`
  (light) records the convention.
- **Risk.** Trivial. Docs-only.
- **Depends on.** None.

### Out-of-band (orchestrator-immediate, F15)

**OOB. v3.3.2 tag cut + version sync + CI gate** (F15)

These are not sub-agent tasks. They are human-gated actions
the orchestrator performs in the order:

1. **Tag the v3.3.2 commit on `release/v3.3.2-2026-10`:**
   `git tag -s v3.3.2 fe83284 -m "v3.3.2 — adoption-fixes +
   audit-cleanup" && git push origin v3.3.2`. Requires
   explicit human approval (tag-push is a release-pipeline
   action).
2. **Run `scripts/sync-version.sh --write`** to update
   `MC_VERSION_DEFAULT` (`scripts/install-tooling/install.sh`)
   and `compatible_with` (`adoption/SKILL.md`). Verify with
   `scripts/sync-version.sh --check`.
3. **Merge `release/v3.3.2-2026-10` → `main`** via
   `git merge --no-ff release/v3.3.2-2026-10 main`. This
   triggers `.github/workflows/ci.yml` for the merge.
4. **Add `release-pending` CI gate** (a new
   `.github/workflows/release-pending.yml`) that fails
   when `VERSION` is ahead of the latest tag. This makes
   "release commit but no tag" visible in CI.

If the user prefers not to cut the v3.3.2 tag now (e.g.
because the plan-2026-11 work is also targeting v3.3.3),
this OOB block can be deferred and a `v3.3.2.1` patch
released instead. Decision left to user.

## 5. Sequencing

```
OOB (F15: tag, sync, merge, CI gate)
  │
  ├── Batch A (parallel, kernel) ────────────────────
  │   A1: verify-sandbox-hardening
  │   A2: path-resolver-audit
  │
  ├── Batch B (parallel, kernel+docs) ──────────────
  │   B1: import-junit-rename
  │   B2: scripts-env-var-audit
  │   B3: attestation-namespace-meta
  │
  └── Batch C (parallel, process+docs) ──────────────
      C1: process-principles-2026-10-2 (F2)
      C2: process-principles-2026-10-3 (F14)
      C3: attest-handshake-rescue
      C4: release-cadence
      C5: verifier-scheme-convention
      C6: experiment-doctor-instrumentation
```

A, B, and C are independent. B and C do not depend on A.
The OOB (F15) is a precondition for **claiming adoption-
fixes shipped** but is not a precondition for any sub-decision
in A, B, C landing.

## 6. Docs-only template fixes (no sub-agent needed)

Four findings (F5, F6, F7, F8) reduce to documentation edits
in `docs/experiments/brownfield-experiment-v2-2026-10.md` and
`docs/experiments/adoption-2026-10-agent-template.md`. The
orchestrator applies these as part of the plan-doc commit:

- **F5**: brownfield-v2 §3 — explicitly note why
  `opentelemetry-go`, `opa`, `cncf/toc` were rejected (the
  `docs/decision/` singular directory check was missed;
  the substitution picks are validated). Add a
  `Pre-flight: verified-by-clone` section to the agent
  template.
- **F6**: agent template — add a "Per-session smoke test"
  section requiring `mathc doctor --json` capture.
- **F7**: agent template — replace the orchestrator's
  vague "prefer upstream" rule with the discriminator's
  precise "if removing the feature would eliminate the
  confusion, it's F-SEMANTIC; if a better onboarding doc
  would eliminate it, it's F-WORKFLOW" rule. File
  `decisions/refine-friction-disambiguation-2026-10.yaml`
  (light).
- **F8**: agent template — add an "Implementation vs
  acceptance" disambiguation block.

## 7. Outcomes

The plan closes when, for every obligation below, the
sub-decision exists in `decisions/<id>.yaml` with `state:
active` and at least one matching attestation; the surface
change is exercised by a cram or conformance test; and
`mathc self-check` returns `verdict: "unknown"` with the
same 12 pre-existing unknown subjects (post-v3.3.2) and
**zero NEW unknown subjects** attributable to this plan.

The 11 sub-decisions cover the 9 confirmed + 5 qualified
findings; 4 of the qualified findings (F5, F6, F7, F8) are
absorbed into template fixes (§6) without a separate
sub-decision.

## 8. Out of scope

- Push to upstream of any external project.
- Changes to `decisions/decision.yaml` (the active policy).
- Kernel changes not in the 11 sub-decisions above.
- Cut + push of v3.3.2 git tag (this is the OOB F15 block;
  separate from the sub-decision flow).
- Force-push of any tag (always human-gated).
- More than 11 sub-decisions; this plan is bounded by the
  15 findings, not by ad-hoc task creep.

## 9. Risks

- **kernel-stability precondition** (A1, A2, B1 in
  particular): any kernel change risks regressing the
  self-check verdict. Mitigated by the per-sub-decision
  `no-self-check-regression` obligation.
- **A1 sandbox primitives are Linux-only**: macOS users
  keep `none` mode. Documented in the decision's
  counterexample.
- **A2 path-resolver audit may surface 1-2 more sites**
  beyond the 8 listed. The audit is a one-shot pass;
  follow-up audits are filed as separate sub-decisions if
  the grep at acceptance-time returns unexpected literals.
- **B3 attestation namespace is a quick fix, not a durable
  one.** Option (a) — full `_plan-meta/` namespace + scanner
  change — is deferred to plan-2026-12.
- **C4 release cadence depends on the human reviewing and
  cutting the v3.3.2 tag.** Without that, the rule is
  documentation-only.
- **F14 sub-agent rate limits may re-occur** in plan-2026-11.
  C2 + C3 codify the protocol; the empirical signal is the
  five-agent run acceptance criterion.

## 10. Acceptance

This plan is accepted when the user reviews §3 hypotheses,
§4 sub-decisions, §5 sequencing, §6 docs-only template
fixes, and §7 outcomes; confirms or revises the priorities;
and explicitly authorises execution. **No execution is
performed until then.**