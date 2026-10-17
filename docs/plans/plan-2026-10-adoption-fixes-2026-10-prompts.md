# Sub-agent prompts — plan-2026-10-adoption-fixes-2026-10

> One section per (sub-decision, batch) pair. The orchestrator
> substitutes the matching section into each sub-agent's prompt.
>
> Common constraints for all 10 sub-agents:
> - Worktree-first: `git worktree add ~/.paseo/worktrees/math-coding/<topic>
>   -b <type>-<topic>-2026-10 plan/adoption-fixes-2026-10`
> - Decision file: `decisions/<sub-decision-id>.yaml`
> - mathc validate must pass before commit
> - mathc self-check must show the same 17 unknown subjects and zero NEW unknowns
> - dune build + dune test must exit 0 for kernel changes
> - One atomic commit
> - No push, no PR — orchestrator handles that
> - Use `MATH_CODING_DECISIONS_DIR=decisions
>   MATH_CODING_ATTESTATIONS_DIR=attestations` for all mathc invocations

---

## A1 / Batch A — fix-env-var-resolver-2026-10

Goal: make `MATH_CODING_DECISIONS_DIR` and `MATH_CODING_ATTESTATIONS_DIR`
honoured by every subcommand that writes or tree-walks.

Procedure:
1. Read `lib/path_config.ml` (the v3.4-era resolver).
2. Read `bin/Mathc.ml::dispatch` and identify which subcommands
   read/write from `decisions/` or `attestations/` without
   going through the resolver:
   - `do_new_decision` (and the `--write` path)
   - `do_self_check`
   - `do_packages`
   - `do_find`
   - `do_counters`
   - `do_migrate`
   - `do_re_evaluate` (single-decision path; the axiom-walk
     `do_re_evaluate_decisions` may already use the resolver)
3. For each: route the path lookup through
   `lib/path_config.ml::resolve_with` (or whatever the
   canonical helper is in this build of math-coding).
4. Add a cram fixture at `tests/cli/env-var-resolver.t` that
   verifies each subcommand honours the env var. Reuse the
   experiment's reproduce commands from §10.5 #1 of the
   adoption report.
5. Run `dune build`, `dune test`, `mathc validate
   decisions/fix-env-var-resolver-2026-10.yaml`, `mathc
   self-check`.
6. The decision file must include a `no-self-check-regression`
   obligation that records the unknown-subject count before
   and after the change.

Hard rules: no kernel file outside the scope; no rename of
existing subcommands; no change to `mathc doctor` or
`mathc init` if those already work.

Acceptance: see
`decisions/plan-2026-10-adoption-fixes-2026-10.yaml::a1-env-var-resolver-shipped`.

---

## A2 / Batch A — fix-yaml-parser-2026-10

Goal: stop the custom YAML parser from consuming the
`counterexample:` key after multi-line `risk.declared_triggers`.

Procedure:
1. Find the parser module (likely `lib/yaml_mini.ml` or
   `lib/decision.ml::parse_yaml_field`). Read it.
2. Write a regression fixture:
   - input YAML with `risk.declared_triggers: - foo\n- bar\ncounterexample: | …`
   - expected: parser returns both keys; `mathc validate`
     returns `accept` without `MC-COUNTEREXAMPLE-MISSING`.
3. Two fix strategies:
   - (preferred) replace custom parser with `Yaml.of_yaml` or
     `ezyaml` (whichever is in `dune-project` deps).
   - (minimal) tighten the parser to detect multi-line scalar
     boundaries correctly.
4. Add `tests/cli/yaml-parser.t` covering:
   - multi-line `declared_triggers` + `counterexample` (must pass)
   - pre-existing parsing still works (no regressions)
5. Run `dune build`, `dune test`, `mathc validate
   decisions/fix-yaml-parser-2026-10.yaml`.

Acceptance: see
`decisions/plan-2026-10-adoption-fixes-2026-10.yaml::a2-yaml-parser-fixed`.

---

## A3 / Batch A — ship-attest-batch-2026-10

Goal: register the existing `do_attest_batch` function in the
`mathc` dispatch table.

Procedure:
1. Confirm `lib/attestations/batch.ml` exists and `do_attest_batch`
   is defined in `bin/Mathc.ml`.
2. Add the dispatch entry:
   ```ocaml
   | "attest-batch" -> do_attest_batch ()
   ```
3. Update `bin/Mathc.ml::print_usage` to include the new
   subcommand in the help text.
4. Add `tests/cli/attest-batch.t` covering:
   - `mathc attest-batch --help` returns usage
   - `mathc attest-batch --manifest=foo.tsv --dry-run` prints
     would-write filenames without writing
   - end-to-end (new-decision → manifest → attest-batch) flips
     verdict from `unknown` to `pass` for a 5-obligation decision.
5. Run `dune build`, `dune test`, `mathc validate
   decisions/ship-attest-batch-2026-10.yaml`.

Acceptance: see
`decisions/plan-2026-10-adoption-fixes-2026-10.yaml::a3-attest-batch-shipped`.

---

## A4 / Batch A — fix-generate-attestations-env-2026-10

Goal: `scripts/generate-attestations.py` honours
`MATH_CODING_DECISIONS_DIR` and `MATH_CODING_ATTESTATIONS_DIR`.

Procedure:
1. Read `scripts/generate-attestations.py`. Confirm the current
   path logic hard-codes the math-coding repo tree.
2. Replace the hard-coded paths with env-var lookups:
   ```python
   DECISIONS_DIR = Path(os.environ.get(
       "MATH_CODING_DECISIONS_DIR",
       str(ROOT / "decisions"),
   ))
   ATTESTATIONS_DIR = Path(os.environ.get(
       "MATH_CODING_ATTESTATIONS_DIR",
       str(ROOT / "attestations"),
   ))
   ```
3. Add `--help` output that documents the env vars.
4. Add `tests/scripts/generate-attestations-env.t`:
   - With `MATH_CODING_ATTESTATIONS_DIR=/tmp/alt/`,
     `python3 scripts/generate-attestations.py < manifest.tsv`
     writes to `/tmp/alt/` (not the math-coding tree).
5. Run `python3 -m py_compile scripts/generate-attestations.py`,
   `dune test tests/scripts/`, `mathc validate
   decisions/fix-generate-attestations-env-2026-10.yaml`.

Acceptance: see
`decisions/plan-2026-10-adoption-fixes-2026-10.yaml::a4-generate-attestations-env-honoured`.

---

## B1 / Batch B — add-verify-subcommand-2026-10

Goal: add `mathc verify <file>` that executes verifier
strings in a sandbox. Rename `mathc validate`'s verdict
from `accept` to `parse-ok` to remove the semantic load.

Depends on: A1 (env-var resolver shipped).

Procedure:
1. Add `do_verify` in `bin/Mathc.ml`. It walks
   `acceptance.all[*].verifier` strings and runs each in a
   subprocess:
   - cwd: the decision's repo root (the dir passed to mathc, or
     the env-var-resolved parent)
   - env-stripped (only `PATH`, `HOME`, `LANG`)
   - timeout: 60 seconds per verifier
   - per-obligation verdict: `pass` (exit 0) / `fail` (exit
     non-zero) / `skipped` (empty verifier string or unknown
     scheme).
2. Register in dispatch table; update help text.
3. Rename `validate`'s verdict string `accept` → `parse-ok` in
   the JSON output. Update `tests/cli/*.t` fixtures that
   assert on `accept`. Coordinate the rename via `git grep
   accept` and `git grep parse-ok` before commit.
4. Add `tests/cli/verify.t` covering:
   - simple `file-exists` verifier against a real path
   - `file-exists` against a missing path (verdict: fail)
   - sandbox: verifier that does `rm -rf /` should not run
     (subprocess is started with no privileges and `cwd` is
     not the host root).
5. Run `dune build`, `dune test`, `mathc validate
   decisions/add-verify-subcommand-2026-10.yaml`.

Acceptance: see
`decisions/plan-2026-10-adoption-fixes-2026-10.yaml::b1-verify-subcommand-shipped`.

Risk: this is a breaking rename. If a downstream fixture
fails, **do not ship**. Revert B1, mark the obligation as
blocked, escalate to the orchestrator.

---

## B2 / Batch B — tighten-counterexample-warn-2026-10

Goal: `MC-COUNTEREXAMPLE-MISSING` fires only when
`counterexample:` is genuinely absent (not when parser-ignored).

Depends on: A2 (parser fix).

Procedure:
1. Locate the diagnostic emission in
   `bin/Mathc.ml::validate_with_counts`.
2. After A2's parser fix, the only way `counterexample:` can
   be missing is when the YAML truly omits it. The warning is
   then a true positive, not a false positive.
3. Tighten the diagnostic's `occurs_when` clause in
   `lib/diagnostics.ml` (or wherever the diagnostic is
   defined) to clarify that it fires on absence, not on
   parser limitation.
4. Add `tests/cli/counterexample-warn.t`:
   - YAML with `counterexample:` → no warning
   - YAML without `counterexample:` (in `state: active`) →
     warning present
   - YAML with `counterexample:` after multi-line
     `declared_triggers` → no warning (parser-fix regression)
5. Run `dune build`, `dune test`, `mathc validate
   decisions/tighten-counterexample-warn-2026-10.yaml`.

Acceptance: see
`decisions/plan-2026-10-adoption-fixes-2026-10.yaml::b2-counterexample-warn-tightened`.

---

## C1 / Batch C — revise-friction-taxonomy-2026-10

Goal: collapse the 8-category taxonomy in the experiment
report to 4 mutually-exclusive categories.

Procedure:
1. Re-read `docs/experiments/adoption-2026-10.md` §7.
2. Define the new taxonomy:
   - **F-INSTALL** — install, env, paths, dependencies.
   - **F-SCHEMA** — schema field, required-field, parser.
   - **F-WORKFLOW** — when-to-do-what confusion.
   - **F-SEMANTIC** — kernel behaviour that surprises the user.
3. Update §7 with the new taxonomy table.
4. Walk all 55 recorded friction events in the 5 reports and
   re-classify each. Verify counts still sum to 55.
5. Update §10.4 (the by-category table).
6. Run `mathc validate decisions/revise-friction-taxonomy-2026-10.yaml`.

Acceptance: see
`decisions/plan-2026-10-adoption-fixes-2026-10.yaml::c1-friction-taxonomy-revised`.

---

## C2 / Batch C — axiom-link-inference-2026-10

Goal: `mathc new-decision` emits a soft-warn naming the
top-3 candidate axioms based on `scope.paths` when
`axiom_link` is absent.

Procedure:
1. Read `bin/Mathc.ml::do_new_decision` and `lib/decision.ml`.
2. Define a small inference table:
   - `lib/**` → A0, A1
   - `tests/**` → A1
   - `decisions/**` → A0, A4
   - `spec/**` → A0, A3
   - (fallback) → A0 (always)
3. When the user runs `mathc new-decision --write` and the
   produced YAML has `axiom_link: TODO`, emit a soft-warn:
   `deficit/MC-AXIOM-LINK-INFERENCE-EMPTY: scope.paths includes lib/;
    top candidates: A0 (separation), A1 (feedback); add axiom_link`.
4. Add `tests/cli/new-decision-axiom-warn.t` covering the
   inference for `lib/`, `tests/`, `decisions/`, `spec/`,
   and empty paths.
5. Run `dune build`, `dune test`, `mathc validate
   decisions/axiom-link-inference-2026-10.yaml`.

Acceptance: see
`decisions/plan-2026-10-adoption-fixes-2026-10.yaml::c2-axiom-link-inference-shipped`.

---

## C3 / Batch C — verify-mathc-doctor-ships-2026-10

Goal: confirm `mathc doctor` ships in the binary and is
documented in the experiment prompt.

Procedure:
1. Check if `mathc doctor --help` works on the shipped binary.
2. If yes:
   - Update `docs/experiments/adoption-2026-10.md` §11.1 to
     note that the subcommand shipped during the experiment
     window (find the exact binary timestamp).
   - Verify `decisions/verify-mathc-doctor-ships-2026-10.yaml`
     records the ship status.
3. If no:
   - Register `do_doctor` in the dispatch table (look for
     the existing `Mathc-doctor-subcommand-2026-10` decision).
   - Update the experiment prompt and the SKILL.md to
     mention it.
4. Add `tests/cli/doctor.t` if not already present.
5. Run `dune build`, `dune test`, `mathc validate
   decisions/verify-mathc-doctor-ships-2026-10.yaml`.

Acceptance: see
`decisions/plan-2026-10-adoption-fixes-2026-10.yaml::c3-mathc-doctor-ship-status-verified`.

---

## C4 / Batch C — plan-brownfield-experiment-v2-2026-10

Goal: design a future brownfield experiment that picks projects
shipping ADRs in `docs/adr/`, `adr/`, or similar.

Procedure:
1. Re-read `docs/experiments/adoption-2026-10.md` §10.7
   (the methodology correction).
2. Choose 5 candidate projects that ship ADRs in-tree. From
   §10.7: `open-telemetry/opentelemetry-go`, `open-policy-agent/opa`,
   `cncf/toc`, `kubernetes-sigs/kustomize`, `grafana/loki`.
   Verify each project actually ships ADRs (use `git ls-tree
   -- docs/adr/` over a shallow clone).
3. Write `docs/experiments/brownfield-experiment-v2-2026-10.md`
   following the structure of the original
   `adoption-2026-10.md`:
   - §0 Why this exists
   - §2 Dialectic (what makes a brownfield experiment
     different from the original)
   - §3 Hypotheses (specifically about the brownfield
     path: `mathc adopt` detection, `mathc import-adr`
     fidelity, etc.)
   - §4 Selection (5 projects)
   - §5 Tasks per project
   - §6 Metrics (extend with brownfield-specific ones)
   - §7 Friction taxonomy revision (use the C1 revision)
   - §8 Procedure
4. Write the planning decision
   `decisions/plan-brownfield-experiment-v2-2026-10.yaml`.
5. Run `mathc validate decisions/plan-brownfield-experiment-v2-2026-10.yaml`.

Acceptance: see
`decisions/plan-2026-10-adoption-fixes-2026-10.yaml::c4-brownfield-experiment-v2-planned`.