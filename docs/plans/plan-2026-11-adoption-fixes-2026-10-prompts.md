# Sub-agent prompts — plan-2026-11-adoption-fixes-2026-10

> One section per (sub-decision, batch) pair. The orchestrator
> substitutes the matching section into each sub-agent's prompt.
>
> Common constraints for all 11 sub-agents:
> - Worktree-first: `git worktree add ~/.paseo/worktrees/math-coding/<topic>
>   -b <type>-<topic>-2026-10 plan/2026-11-adoption-fixes-2026-10`
> - Decision file: `decisions/<sub-decision-id>.yaml` (mode `light`
>   for non-kernel, mode `standard` for kernel changes)
> - `mathc validate` must pass before commit
> - `mathc self-check` must show same 12 unknown subjects (post-v3.3.2)
>   and zero NEW unknowns
> - `dune build` + `dune test` must exit 0 for kernel changes
> - One atomic commit
> - No push, no PR — orchestrator handles that
> - Use `MATH_CODING_DECISIONS_DIR=decisions
>   MATH_CODING_ATTESTATIONS_DIR=attestations` for all mathc invocations
> - The sub-agent prompt template per F14's C2 sub-decision:
>   first action is a `wip(scaffold):` commit of the decision stub
>   BEFORE any kernel edit
> - The sub-agent prompt template per F2's C1 sub-decision:
>   pre-flight gate checks that all declared dependencies are
>   merged into `plan/2026-11-adoption-fixes-2026-10`

---

## A1 / Batch A — verify-sandbox-hardening-2026-11

Goal: add `mathc verify --sandbox=<mode>` with three modes
(`none | minimal | strict`). In `strict` mode, drop
capabilities, call `prctl(PR_SET_NO_NEW_PRIVS, 1)`, apply
RLIMITs, and refuse write-capable mathc subcommands in the
`mathc` verifier scheme.

Procedure:

1. Read `/home/az/Projects/math-coding/docs/plans/plan-2026-11-adoption-fixes-2026-10.md`
   §4 A1 for full scope and acceptance criteria.
2. Read the discriminator output for F9 at
   `/home/az/Projects/math-coding/docs/experiments/discriminator-f9-f12-2026-10.yaml`
   for the line-by-line fix recommendations.
3. **Scaffold commit first.** Per C2, write the decision stub
   `decisions/verify-sandbox-hardening-2026-11.yaml` and
   commit it BEFORE any kernel edit.
4. Read `bin/Mathc.ml` lines 2686-2830 (`do_verify`,
   `run_one_verifier`, `run_with_sandbox`, `parse_verifier_string`)
   and `lib/path_config.ml` (for the new
   `resolve_sandbox_mode` function).
5. Implement the sandbox modes. In `strict` mode:
   - call `capset(2)` to empty `cap_bset` (best-effort on
     Linux; skip silently on macOS — the `none` mode
     remains the only macOS option);
   - call `prctl(PR_SET_NO_NEW_PRIVS, 1)`;
   - apply `RLIMIT_CPU=60s`, `RLIMIT_NPROC=1`, `RLIMIT_NOFILE=64`,
     `RLIMIT_FSIZE=write_target_max` before `Unix.execve`;
   - refuse `mathc` scheme invocations of write-capable
     subcommands (`init`, `new-decision --write`,
     `import-adr --write`, `attest-batch`, `decision-state`).
     Hard-coded allowlist: `validate`, `assess`, `find`,
     `self-check`, `explain`, `explain-diagnostic`, `context`,
     `packages`.
6. Add `MATH_CODING_VERIFY_SANDBOX` env-var support in
   `lib/path_config.ml::resolve_sandbox_mode ()` with values
   `none | minimal | strict` (default `none`).
7. Update `bin/Mathc.ml::print_usage` help text to document
   the new flag.
8. Add cram fixture `tests/cli/verify-sandbox.t` covering:
   - `verifier: "rm -rf /tmp/x"` returns `Skipped` in all modes;
   - `verifier: "file-exists /etc/shadow"` returns `Pass`
     in `none`/`minimal`, `Fail` in `strict`;
   - `verifier: "mathc init"` returns `Pass` in `none`,
     `Skipped` (with the strict-scheme-deny reason) in
     `strict`.
9. Generate attestations via TSV manifest to
   `python3 scripts/generate-attestations.py`.
10. Run `dune build`, `dune test`, `mathc validate`,
    `mathc self-check` — must show same 12 unknowns, zero new.
11. Commit atomically.

Hard rules:
- No push, worktree-only, atomic commit, dune green.
- Sandbox primitives are Linux-only; macOS users keep
  `none` mode. Document the platform limitation in
  the decision's `counterexample:`.
- The orchestrator's read-only discriminator report
  (§4 A1) notes that the `mathc` scheme allowlist
  mitigates PATH-attack but write-capable subcommands
  remain a risk; your hard-coded allowlist closes the
  write-vector directly.

Acceptance: meta-decision obligation `a1-verify-sandbox-shipped`.

---

## A2 / Batch A — path-resolver-audit-2026-11

Goal: wire the 6 missed call sites in `bin/Mathc.ml` through
`Path_config.resolve_decisions_dir ()` /
`resolve_attestations_dir ()` / `resolve_policy_path ()`.

Procedure:

1. Read `/home/az/Projects/math-coding/docs/plans/plan-2026-11-adoption-fixes-2026-10.md`
   §4 A2 for the 8 call sites (the orchestrator's analysis
   lists 6, but the discriminator F10's read of `bin/Mathc.ml`
   found 8 — the audit may surface 1-2 more during execution).
2. Read the discriminator F10 at
   `/home/az/Projects/math-coding/docs/experiments/discriminator-f9-f12-2026-10.yaml`
   for the exact line numbers and replacement code.
3. **Scaffold commit first.** Per C2, write the decision stub
   and commit.
4. Read `lib/path_config.ml` to confirm the resolver
   functions exist.
5. For each of the 8 sites, replace the hard-coded path
   literal with the corresponding `Path_config.resolve_*`
   call. The discriminator F10 has the exact replacements.
6. Add 3 cram fixtures:
   - `tests/cli/execution-logs-env-var.t` — sets
     `MATH_CODING_DECISIONS_DIR=.math-coding/decisions` and
     asserts `do_record` writes the JSONL to that location.
   - `tests/cli/re-evaluate-decisions-env-var.t` — sets
     `MATH_CODING_ATTESTATIONS_DIR` and asserts the post-run
     attestations land in that dir.
   - `tests/cli/policy-env-var.t` — sets
     `MATH_CODING_POLICY=.math-coding/policy.yaml` and
     asserts `dispatch` loads from there.
7. Generate attestations.
8. Run `dune build`, `dune test`, `mathc validate`,
   `mathc self-check`.
9. Run the audit grep at the end:
   ```
   grep -nE '"decisions/"|"attestations/"|"policies.yaml"' bin/Mathc.ml
   ```
   The only matches should be inside comments / documentation
   strings, NOT inside `Filename.concat` or `let <name> =`.
   This is the meta-acceptance criterion: the fix is
   complete when this grep returns zero non-comment matches.
10. Commit atomically.

Hard rules:
- No push, worktree-only, atomic commit, dune green.
- Don't expand scope beyond the 8 sites unless the audit
  grep at the end surfaces a literal that would clearly
  benefit from a one-line resolver wire. If you find a
  9th site, file a follow-up sub-decision, do not silently
  expand this one.

Acceptance: meta-decision obligation `a2-path-resolver-audit-shipped`.

---

## B1 / Batch B — import-junit-rename-2026-11

Goal: rename `mathc attest FILE` → `mathc import-junit FILE`.
Keep `mathc attest` as a one-cycle deprecation alias.

Procedure:

1. Read `/home/az/Projects/math-coding/docs/plans/plan-2026-11-adoption-fixes-2026-10.md`
   §4 B1 for full scope.
2. Read the discriminator F12 at
   `/home/az/Projects/math-coding/docs/experiments/discriminator-f9-f12-2026-10.yaml`
   for the line-by-line replacements.
3. **Scaffold commit first.** Per C2.
4. Edit `bin/Mathc.ml:6709` dispatch arm to
   `| "import-junit" | "attest" -> do_attest ()`. The `attest`
   arm emits a one-shot stderr warning
   (gated by a static flag) saying
   `"warning: 'mathc attest' is deprecated and will be removed in 3.6; use 'mathc import-junit' instead."`.
5. Update `bin/Mathc.ml:683-690` (`print_usage`) to list
   `import-junit` as the canonical name with a deprecation
   note.
6. Update `bin/Mathc.ml` error/help text references at
   lines 2424, 2427, 2452, 2456 to use `mathc import-junit`.
7. Update `tests/cli/junit-adapter.t` to invoke
   `mathc import-junit`. Add `tests/cli/attest-deprecation-alias.t`
   that asserts `mathc attest` still exits 0 AND prints the
   deprecation warning.
8. Update `decisions/adapters.yaml:99-111` (junit-attestation-import
   outcome) to refer to `mathc import-junit` as the
   canonical name.
9. Update `adoption/SKILL.md:233` and `:423-424` to remove
   the false "writes" claim.
10. Generate attestations.
11. Run `dune build`, `dune test`, `mathc validate`,
    `mathc self-check`.
12. Commit atomically.

Hard rules:
- No push, worktree-only, atomic commit, dune green.
- The `attest` alias is BACKWARDS-COMPATIBLE. Existing
  scripts calling `mathc attest` continue to work, just
  with a stderr warning. Do not remove the alias.

Acceptance: meta-decision obligation `b1-import-junit-rename-shipped`.

---

## B2 / Batch B — scripts-env-var-audit-2026-11

Goal: fix two real offenders (`axiom-link-seed.py`,
`counterexample-seed.py`); drop the orchestrator's mistaken
naming of `slack2madr.py`/`confluence2madr.py` (they are
pure transforms with no resolver issue).

Procedure:

1. Read `/home/az/Projects/math-coding/docs/plans/plan-2026-11-adoption-fixes-2026-10.md`
   §4 B2.
2. Read the discriminator F11 for the exact replacements.
3. **Scaffold commit first.** Per C2.
4. Edit `scripts/axiom-link-seed.py:63-65`: replace
   `REPO_ROOT = Path(__file__).parent.parent` with
   `REPO_ROOT = Path(os.environ.get("MATH_CODING_REPO_ROOT", str(Path(__file__).parent.parent)))`,
   and `DECISIONS_DIR = REPO_ROOT / "decisions"` with
   `DECISIONS_DIR = REPO_ROOT / os.environ.get("MATH_CODING_DECISIONS_DIR", "decisions")`.
   Same for `TIER_DIR`. Add `import os`.
5. Edit `scripts/counterexample-seed.py:75` with the same
   `os.environ.get` pattern.
6. Add `tests/cli/scripts-env-var.t` covering: set
   `MATH_CODING_DECISIONS_DIR=.math-coding/decisions`,
   run each script in `--dry-run` mode, assert the resolved
   dir is reported correctly.
7. Generate attestations.
8. Run `python3 -m py_compile` on each script, `dune test`,
   `mathc validate`, `mathc self-check`.
9. Commit atomically.

Hard rules:
- No push, worktree-only, atomic commit.
- Do NOT touch `slack2madr.py` or `confluence2madr.py` —
  they have no issue.

Acceptance: meta-decision obligation `b2-scripts-env-var-audit-shipped`.

---

## B3 / Batch B — attestation-namespace-meta-2026-11

Goal: codify the "plan-decision-named filenames are reserved
for plan-decision attestations only" convention. Option (b)
from the F1–F4 discriminator — quick 5-line edit to the
plan-prompts file + light decision file. Option (a) (full
`_plan-meta/` namespace + scanner change) is deferred to
plan-2026-12.

Procedure:

1. Read `/home/az/Projects/math-coding/docs/plans/plan-2026-11-adoption-fixes-2026-10.md`
   §4 B3.
2. Read the discriminator F3 for context.
3. **Scaffold commit first.** Per C2.
4. Write `decisions/attestation-namespace-meta-2026-11.yaml`
   (light) recording the rule.
5. Edit `docs/plans/plan-2026-11-adoption-fixes-2026-10-prompts.md`
   (the to-be-created prompts file for this plan, see
   `<this file>`): add a 5-line paragraph to the per-task
   template specifying the rule.
6. Run `mathc validate` on the new decision, generate
   attestations.
7. Commit atomically.

Hard rules:
- No push, worktree-only, atomic commit.
- The `_plan-meta/` namespace option is explicitly out of
  scope for this sub-decision. Defer to plan-2026-12.

Acceptance: meta-decision obligation `b3-attestation-namespace-meta-shipped`.

---

## C1 / Batch C — process-principles-2026-10-2

Goal: add principle P8.5 to `decisions/process-principles.yaml`
— "no sub-agent launches until all declared dependencies are
merged into the integration branch".

Procedure:

1. Read `/home/az/Projects/math-coding/docs/plans/plan-2026-11-adoption-fixes-2026-10.md`
   §4 C1.
2. Read the discriminator F2 for the exact gate text.
3. **Scaffold commit first.** Per C2.
4. Read the existing `decisions/process-principles.yaml` to
   see the amendment format.
5. Add P8.5 as a new principle paragraph, following the
   same `id`, `claim`, `acceptance` shape as the existing
   principles.
6. Add the pre-flight gate to the prompt template
   `<this file>`'s "Workflow" section.
7. Generate attestations.
8. Run `mathc validate`, `mathc self-check`.
9. Commit atomically.

Hard rules:
- No push, worktree-only, atomic commit.
- The amendment must be backwards-compatible: existing
  process-principles.yaml must validate without breakage.

Acceptance: meta-decision obligation `c1-process-principles-rev-2-shipped`.

---

## C2 / Batch C — process-principles-2026-10-3

Goal: add principle P9 to `decisions/process-principles.yaml`
— sub-agents MUST commit a `wip(scaffold):` draft at task
start and `wip(checkpoint):` commits every 5 minutes of
active work. The orchestrator MUST verify these are present
in the worktree's reflog before accepting the sub-agent's
`pass` claim.

Procedure:

1. Read `/home/az/Projects/math-coding/docs/plans/plan-2026-11-adoption-fixes-2026-10.md`
   §4 C2.
2. Read the discriminator F14 for the exact scaffold-commit
   block.
3. **Scaffold commit first.** Per C2 (this is meta).
4. Add P9 as a new principle paragraph.
5. Update `<this file>`'s per-task prompt template to
   prepend the scaffold-commit block as step 0.
6. Generate attestations.
7. Run `mathc validate`, `mathc self-check`.
8. Commit atomically.

Hard rules:
- No push, worktree-only, atomic commit.
- The acceptance criterion "five-agent run completes 100% of
  obligations without manual rescue" is recorded but not
  tested by this sub-decision. It is measured over the next
  plan-2026-11 cycle (or successor).

Acceptance: meta-decision obligation `c2-process-principles-rev-3-shipped`.

---

## C3 / Batch C — attest-handshake-rescue-2026-11

Goal: codify the orchestrator-rescue recipe as a first-class
workflow.

Procedure:

1. Read `/home/az/Projects/math-coding/docs/plans/plan-2026-11-adoption-fixes-2026-10.md`
   §4 C3.
2. Read the discriminator F14 for the rescue-recipe
   rules (i)/(ii)/(iii).
3. **Scaffold commit first.** Per C2.
4. Write `decisions/attest-handshake-rescue-2026-11.yaml`
   (light) recording: (i) when rescue is permitted;
   (ii) minimum evidence to record (worktree last-commit
   SHA, agent log tail, recovered file paths);
   (iii) the obligation it closes.
5. Generate attestations.
6. Run `mathc validate`, `mathc self-check`.
7. Commit atomically.

Hard rules:
- No push, worktree-only, atomic commit.
- This decision is a codification, not a code change.

Acceptance: meta-decision obligation `c3-attest-handshake-rescue-shipped`.

---

## C4 / Batch C — release-cadence-2026-11

Goal: record the release-cadence rule. Every release
commit on a `release/vX.Y.Z-YYYY-MM` branch MUST be followed
by (i) `git push origin vX.Y.Z` to trigger `release.yml`;
(ii) `scripts/sync-version.sh --write` to update
`MC_VERSION_DEFAULT` and `compatible_with`; (iii) `scripts/dev
ready` to confirm CI green, within 24 hours.

Plus: implement the `release-pending` CI gate that fails
when `VERSION` is ahead of the latest tag.

Procedure:

1. Read `/home/az/Projects/math-coding/docs/plans/plan-2026-11-adoption-fixes-2026-10.md`
   §4 C4.
2. Read the discriminator F15 for the exact CI gate
   implementation.
3. **Scaffold commit first.** Per C2.
4. Write `decisions/release-cadence-2026-11.yaml` (light)
   recording the rule.
5. Add `.github/workflows/release-pending.yml` that:
   - reads `VERSION`;
   - runs `git ls-remote --tags --sort=-v:refname | head -1`
     to find the latest tag;
   - if VERSION is ahead, exits 1 with the message
     "release pending: tag vX.Y.Z has not been published".
6. Add 5-line §"Release protocol" to `CONTRIBUTING.md`.
7. Add `scripts/release.sh` template script that runs the
   three steps in sequence.
8. Add 5-line "Local binary freshness" section to
   `adoption/SKILL.md`.
9. Generate attestations.
10. Run `mathc validate`, `mathc self-check`.
11. Commit atomically.

Hard rules:
- No push, worktree-only, atomic commit.
- This sub-decision does NOT cut the v3.3.2 tag. That is
  the OOB F15 block, treated separately.
- The release-pending CI gate is a NEW workflow file; it
  must not break existing CI.

Acceptance: meta-decision obligation `c4-release-cadence-shipped`.

---

## C5 / Batch C — verifier-scheme-convention-2026-11

Goal: record the verifier-scheme rule. Verifier strings MUST
be either one of the 3 built-in schemes (`file-exists`,
`dir-exists`, `mathc`) OR a documented command that an
external runner executes; placeholder strings that match
neither pattern are warned on by `mathc validate`.

Procedure:

1. Read `/home/az/Projects/math-coding/docs/plans/plan-2026-11-adoption-fixes-2026-10.md`
   §4 C5.
2. Read the discriminator F4 for context.
3. **Scaffold commit first.** Per C2.
4. Edit `lib/decision.ml` to add a soft-warn when an
   acceptance item's `verifier` field does not match any
   known scheme. The warn is `MC-VERIFIER-SCHEME-UNKNOWN`
   (Block) and exits 0 (soft-warn, not reject). Reference
   the 3-scheme allowlist from `bin/Mathc.ml::parse_verifier_string`.
5. Add cram fixture `tests/cli/verifier-scheme-warning.t`
   covering: known scheme (no warn), unknown scheme (warn).
6. Add an `OCAML_KERNEL_CONVENTIONS.md` §11 trap log entry
   documenting the convention.
7. Replace the 4 placeholder verifier strings in
   `add-verify-subcommand-2026-10.yaml` and the
   `plan-2026-10-adoption-fixes-2026-10.yaml` decision
   with `mathc self-check --format=json` invocations.
8. Write `decisions/verifier-scheme-convention-2026-11.yaml`
   (light) recording the rule.
9. Generate attestations.
10. Run `dune build`, `dune test`, `mathc validate`,
    `mathc self-check`.
11. Commit atomically.

Hard rules:
- No push, worktree-only, atomic commit, dune green.
- The soft-warn is NOT a reject. Existing decisions with
  unknown schemes continue to validate; they just emit a
  warning.

Acceptance: meta-decision obligation `c5-verifier-scheme-convention-shipped`.

---

## C6 / Batch C — experiment-doctor-instrumentation-2026-11

Goal: add `mathc doctor --json` exercise to the brownfield
experiment v2 task templates.

Procedure:

1. Read `/home/az/Projects/math-coding/docs/plans/plan-2026-11-adoption-fixes-2026-10.md`
   §4 C6.
2. Read the discriminator F13 for the exact edits.
3. **Scaffold commit first.** Per C2.
4. Edit `docs/experiments/brownfield-experiment-v2-2026-10.md`
   §5 T1: add a 6th step: "Run `mathc doctor --json` and
   capture output to `experiment-report.md` §T1. Record
   any section with `status: fail` as a friction event id
   `<session>-F-DOCTOR-<n>` under F-INSTALL."
5. Edit §8 Phase 0: insert one line at the top: "Verify
   `mathc doctor` returns exit 0 on a fresh cwd; capture
   the JSON output and save as
   `experiments/brownfield-v2/preflight-doctor.json`."
6. Edit §3 Hypotheses: add BH9 ("mathc doctor reports ≥ 7
   healthy sections on a fresh install on ≥ 4 of 5 projects").
7. Write `decisions/experiment-doctor-instrumentation-2026-11.yaml`
   (light) recording the convention.
8. Generate attestations.
9. Run `mathc validate`, `mathc self-check`.
10. Commit atomically.

Hard rules:
- No push, worktree-only, atomic commit.
- Docs-only.

Acceptance: meta-decision obligation `c6-experiment-doctor-instrumentation-shipped`.