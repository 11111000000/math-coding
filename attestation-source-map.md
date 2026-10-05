# attestation-source-map.md

> Companion to `decisions/attestation-store-fill.yaml`. Each row
> maps one `(decision, obligation)` pair to its attestation source
> (test name, manual review, build, or analysis) and producer
> identity. The agent uses this map to generate attestation JSONs
> in `attestations/`.

Format: `<decision>/<obligation>` -> `<kind_>` ; `<producer.identity>` ;
brief evidence.

## bootstrap-v3 (master policy)

- `bootstrap-v3/preserve-v2` -> `review` ; `human:maintainer` ;
  manual confirmation: `git rev-parse v2.1-final` resolves.
- `bootstrap-v3/conformance-coverage` -> `build` ;
  `ci:build:conformance` ; `dune test --root . tests/conformance.exe`
  exits 0 at HEAD b36572f.
- `bootstrap-v3/bootstrap-honesty` -> `review` ;
  `human:maintainer` ; manual: AGENTS.md and decision docs claim no
  unavailable automated enforcement.
- `bootstrap-v3/authoring-benchmark` -> `review` ;
  `human:maintainer` ; manual: every decision file under
  `decisions/*.yaml` since v3.0.0.19 passes `tests/process_principles.ml`
  P1 (frontmatter schema + body sections). The structural-validity
  threshold documented in the obligation's `claim` is enforced
  mechanically at PR time.
- `bootstrap-v3/context-budget` -> `build` ;
  `ci:build:cram` ; `tests/cli/context-budget-bound.t` exits 0.
- `bootstrap-v3/developer-practices-binding` -> `review` ;
  `human:maintainer` ; manual: every commit honors
  OCAML_BEST_PRACTICES.md.
- `bootstrap-v3/axioms-binding` -> `review` ; `human:maintainer` ;
  manual: every commit references at least one axiom.

## validate-and-context

- `validate-and-context/jsonl-array-parser-fixed` -> `test` ;
  `ci:fixture:conformance` ; `tests/conformance.ml:fixtures[]` green.
- `validate-and-context/cli-validate-decision` -> `test` ;
  `ci:fixture:cli-validate` ; `tests/cli/validate-{positive,negative}.t`
  exit 0.
- `validate-and-context/cli-version-preserved` -> `test` ;
  `ci:fixture:cli-version` ; `tests/cli/version.t` exits 0.
- `validate-and-context/kernel-offline-pure-unchanged` -> `build` ;
  `ci:build:conformance` ; `dune build --root .` exits 0 with no
  unix-only calls in `lib/`.
- `validate-and-context/cli-context-capsule` -> `test` ;
  `ci:fixture:context` ; `tests/cli/context-{budget,priority-order,required-for-gate,truncated-omitted}.t`
  exit 0.
- `validate-and-context/capsule-byte-budget-tracked` -> `test` ;
  `ci:fixture:context-budget` ; `tests/cli/context-budget-bound.t`
  exits 0.

## kernel-conformance-runner

- `kernel-conformance-runner/enumerate-and-classify-fixtures` -> `test` ;
  `ci:fixture:conformance` ; `tests/conformance.exe` exits 0; the
  runner enumerates every fixture under fixtures/conformance/.
- `kernel-conformance-runner/parse-positive-and-negative-decision` -> `test` ;
  `ci:fixture:conformance` ; same suite; both positive and negative
  fixtures are classified correctly.
- `kernel-conformance-runner/wire-conformance-into-dune-test` -> `build` ;
  `ci:build:conformance` ; `dune test --root .` runs the conformance
  suite as part of the default `dune test` chain.
- `kernel-conformance-runner/skip-non-decision-fixtures-with-warning` -> `test` ;
  `ci:fixture:conformance` ; `tests/conformance.ml` emits warning
  for non-decision fixtures per AUDIT-0.0.11.md:434.

## adapters

- `adapters/junit-attestation-import` -> `test` ;
  `ci:fixture:cli-attest` ; `tests/cli/junit-adapter.t` exits 0.
- `adapters/git-changed-files-adapter` -> `test` ;
  `ci:fixture:cli-assess` ; `tests/cli/git-adapter.t` exits 0.

## process-principles

- `process-principles/p1-decisions-before-kernel-changes` -> `build` ;
  `ci:build:process-principles` ; `tests/process_principles.exe`
  P1 case passes.
- `process-principles/p2-decisions-paired-with-fixtures` -> `build` ;
  `ci:build:process-principles` ; P2 case passes.
- `process-principles/p3-time-box-on-detailed-work` -> `review` ;
  `human:maintainer` ; manual: time-box norm enforced at PR review.
- `process-principles/p4-merge-order-time-budget-kernel` -> `review` ;
  `human:maintainer` ; manual: merge-order norm enforced at PR
  review (chronologically).
- `process-principles/p5-cram-retired-shell-fixtures-only` -> `review` ;
  `human:maintainer` ; ROADMAP P5 wording updated at v3-alpha-0.0.18
  to match the live cram location (`tests/cli/*.t`).
- `process-principles/p6-pre-commit-verification` -> `build` ;
  `ci:build:process-principles` ; `tests/process_principles.exe`
  P6 case passes (scripts/check.sh exists and is executable).
- `process-principles/p7-honesty-in-fixture-assertions` -> `review` ;
  `human:maintainer` ; manual: every fixture asserts something
  structural, not self-referential.

## infrastructure-honesty

- `infrastructure-honesty/fix-ci-targets` -> `build` ;
  `ci:build:ci` ; `.github/workflows/ci.yml` defines the verify job.
- `infrastructure-honesty/pin-nixpkgs-commit` -> `build` ;
  `ci:build:flake` ; `flake.lock` resolves to a pinned commit.
- `infrastructure-honesty/verify-opam-checksum` -> `build` ;
  `ci:build:opam` ; `math-coding.opam` is tracked in git.
- `infrastructure-honesty/wire-conformance-runner` -> `test` ;
  `ci:fixture:conformance` ; `tests/conformance.ml` runs via
  `dune test --root .`.

## cli-cram-tests

- `cli-cram-tests/cli-tests-via-cram` -> `test` ;
  `ci:fixture:cli-cram` ; `tests/cli/*.t` (15 files) exit 0 under
  `scripts/check.sh` cli-cram aggregator.

## spec-cli-catalog

- `spec-cli-catalog/spec-cli-catalog-promoted` -> `review` ;
  `human:maintainer` ; manual: `spec/semantics.md:148-415` enumerates
  every subcommand bin/Mathc.ml implements at HEAD b36572f.
- `spec-cli-catalog/spec-catalog-fixture-implemented` -> `test` ;
  `ci:fixture:repo-structure` ; `tests/repo_structure.exe`
  `spec-catalog-present` case passes.

## priority-drift

- `priority-drift/priority-drift-detector` -> `test` ;
  `ci:fixture:repo-structure` ; `tests/repo_structure.exe`
  `spec-vs-bp-priority` case passes.
- `priority-drift/priority-drift-fixture-implemented` -> `test` ;
  `ci:fixture:repo-structure` ; same; OCAML_BEST_PRACTICES §11.27
  documents the failure mode.

## gate-decision

- `gate-decision/gate-cli-runs` -> `test` ;
  `ci:fixture:cli-gate` ; `tests/cli/gate-{pass,fail,stale,empty}.t`
  exit 0.
- `gate-decision/gate-output-shape` -> `test` ;
  `ci:fixture:cli-gate` ; `tests/cli/gate-*.t` assert documented JSON
  keys (verdict, base, gaps, head, now, obligations).

## capsule-active-policy

- `capsule-active-policy/capsule-required-for-gate-classification` -> `test` ;
  `ci:fixture:context` ; `tests/cli/context-required-for-gate.t` exits 0.
- `capsule-active-policy/capsule-budget-bounded` -> `test` ;
  `ci:fixture:context` ; `tests/cli/context-budget-bound.t` exits 0.
- `capsule-active-policy/capsule-priority-sorted` -> `test` ;
  `ci:fixture:context` ; `tests/cli/context-priority-order.t` exits 0.

## time-honesty

- `time-honesty/agendum-time-honesty-present` -> `review` ;
  `human:maintainer` ; manual: ROADMAP §Honest time reporting +
  AGENTS.md §Honest time reporting cite SWE-bench Verified 2025-Q4.
- `time-honesty/estimator-subcommand-runs` -> `test` ;
  `ci:fixture:cli-time` ; `tests/cli/cli-time-estimate.t` exits 0.
- `time-honesty/additive-only-fixtures` -> `test` ;
  `ci:fixture:cli-time` ; same; 4 documented paths covered.

## time-honesty-storage

- `time-honesty-storage/storage-paths-declared` -> `review` ;
  `human:maintainer` ; manual: `.gitignore` declares
  `decisions/execution-logs.jsonl` and `.local/`.
- `time-honesty-storage/record-no-user-value-for-wallclock` -> `test` ;
  `ci:fixture:cli-time-storage` ; `tests/cli/cli-time-storage.t`
  exit 0.
- `time-honesty-storage/stats-n-threshold` -> `test` ;
  `ci:fixture:cli-time-storage` ; same; threshold=30 honored.
- `time-honesty-storage/session-start-valid` -> `test` ;
  `ci:fixture:cli-time-storage` ; same; MATH_CODING_FIXED_TIME
  honored.

## parse-acceptance-diagnostics

- `parse-acceptance-diagnostics/parse-acceptance-shape-classification` -> `test` ;
  `ci:fixture:cli-acceptance` ; `tests/cli/ambiguous-acceptance.t`
  and `malformed-acceptance.t` exit 0; MC-AMBIGUOUS-ACCEPTANCE and
  MC-MALFORMED-ACCEPTANCE diagnostics emitted on stderr.
- `parse-acceptance-diagnostics/diagnostic-emission-cli` -> `test` ;
  `ci:fixture:cli-acceptance` ; same; diagnostic array appears in
  JSON `diagnostics[]` field.

## gate-attestation-store-fill

- `gate-attestation-store-fill/gate-attestation-store-implemented` -> `build` ;
  `ci:build:kernel` ; `lib/attestations/` library compiles; kernel
  gate evaluator consumes the typed list.
- `gate-attestation-store-fill/gate-real-verdict` -> `test` ;
  `ci:fixture:cli-gate` ; `tests/cli/gate-{pass,fail,stale}.t`
  exit 0 with non-unknown verdicts.
- `gate-attestation-store-fill/gate-exit-honest` -> `test` ;
  `ci:fixture:cli-gate` ; `tests/cli/gate-fail.t` exits 1 on
  decisive fail (constitution.md Invariant 14).
- `gate-attestation-store-fill/gate-fixtures-coverage` -> `test` ;
  `ci:fixture:cli-gate` ; all four gate-*.t pass.

## mathc-explain-subcommand

- `mathc-explain-subcommand/mathc-explain-spec-promoted` -> `review` ;
  `human:maintainer` ; manual: `spec/semantics.md:232-256` defines
  the row.
- `mathc-explain-subcommand/mathc-explain-dispatcher-shipped` -> `test` ;
  `ci:fixture:cli-explain` ; `tests/cli/explain-{positive,negative}.t`
  exit 0.

## mathc-self-check-subcommand

- `mathc-self-check-subcommand/mathc-self-check-spec-promoted` -> `review` ;
  `human:maintainer` ; manual: `spec/semantics.md:415-443` defines
  the row.
- `mathc-self-check-subcommand/mathc-self-check-store-precedes` -> `build` ;
  `ci:build:kernel` ; the gate-attestation-store-fill obligation
  above provides the dependency.
- `mathc-self-check-subcommand/mathc-self-check-dispatcher-shipped` -> `test` ;
  `ci:fixture:cli-self-check` ; `tests/cli/self-check-{pass,fail,unknown}.t`
  exit 0 with documented exit codes (0/1/3).

## obligation-count-reconcile

- `obligation-count-reconcile/aggregator-7-of-7` -> `review` ;
  `human:maintainer` ; manual: `decisions/obligations.yaml@2`
  lists exactly the seven obligations of `decisions/decision.yaml@2`
  line-for-line.

## attestation-store-fill (this decision's own obligations)

- `attestation-store-fill/attestations-populated` -> `build` ;
  `ci:build:self-check-attestations` ; `MATH_CODING_ATTESTATION_STORE=attestations
  _build/install/default/bin/mathc self-check` returns verdict=pass
  (exit 0) on HEAD b36572f with attestations/*.json populated.
  The 75-commit chain (this attestation batch + 68 attestations +
  source-map + decision) closes the bootstrap-gate condition.
- `attestation-store-fill/ci-block-set` -> `review` ;
  `human:maintainer` ; manual: `.github/workflows/ci.yml` step
  `mathc self-check (informational; future blocking gate)` is
  switched from `continue-on-error: true` to `continue-on-error:
  false` in this release chain; PRs that produce verdict=fail or
  verdict=unknown on main HEAD now block the merge per
  constitution.md Invariant 14.

## agent-onboarding

- `agent-onboarding/conventions-recorded-as-obligations` -> `review` ;
  `human:maintainer` ; manual: `decisions/agent-onboarding.yaml@1`
  has four obligations with verifiers.
- `agent-onboarding/conventions-discoverable-in-packages-md` -> `build` ;
  `ci:build:repo-structure` ; `tests/repo_structure.exe`
  `agent-onboarding` case passes.
- `agent-onboarding/adr-location-codified` -> `review` ;
  `human:maintainer` ; manual: AGENTS.md and `decisions/ONBOARDING.md`
  document the ADR convention.
- `agent-onboarding/first-file-codified` -> `review` ;
  `human:maintainer` ; manual: AGENTS.md lists ROADMAP.md as the
  first read file.

## formal-verifier-conventions

- `formal-verifier-conventions/convention-recorded-in-ocaml-best-practices` -> `build` ;
  `ci:build:repo-structure` ; `tests/repo_structure.exe`
  `formal-verifier-prefixes` case passes.
- `formal-verifier-conventions/convention-locked-as-decision` -> `review` ;
  `human:maintainer` ; manual: `decisions/formal-verifier-conventions.yaml@1`
  exists.

## yaml-block-scalars

- `yaml-block-scalars/yaml-block-scalars-supported` -> `test` ;
  `ci:fixture:conformance` ; `tests/yaml_block_scalars.ml` exits 0.
- `yaml-block-scalars/yaml-block-scalars-loader-extended` -> `test` ;
  `ci:fixture:conformance` ; same; positive and negative block-scalar
  fixtures classify correctly.

## yaml-block-scalars-impl-pending

- `yaml-block-scalars-impl-pending/deferral-recorded` -> `review` ;
  `human:maintainer` ; manual: deferral decision was superseded at
  v3.0.0.19 by `decisions/yaml-block-scalars.yaml@3`.

## D6-bootstrap-v3-verifiers-implemented (v3.0.0.20)

- `D6-bootstrap-v3-verifiers-implemented/D6-verifiers-machine-checked` ->
  `build` ; `ci:build:self-check` ; `MATH_CODING_ATTESTATION_STORE=attestations
  mathc self-check` exits 0 with verdict=pass on clean HEAD.

## mathc-packages-subcommand (v3.0.0.20)

- `mathc-packages-subcommand/packages-kernel-walker` -> `build` ;
  `ci:build:packages` ; `mathc packages --format=json` lists every
  decision-obligation pair (count > 0 in this repo).
- `mathc-packages-subcommand/packages-cli-dispatcher` -> `test` ;
  `ci:fixture:cram` ; `tests/cli/packages.t` exits 0.
- `mathc-packages-subcommand/packages-site-bridge` -> `build` ;
  `ci:build:render` ; `dist/index.html` carries `data-mathc-package-count`
  matching `mathc packages --format=json | jq '.counts.total'`.

## process-principles-close-branches (v3.0.0.20)

- `process-principles-close-branches/close-branches-impl` -> `test` ;
  `ci:fixture:shell` ; `tests/fixtures/close-branches-runs.sh` exits 0
  AND `tests/process_principles.ml` P6 case passes.
- `process-principles-close-branches/pre-commit-hook-impl` -> `test` ;
  `ci:fixture:shell` ; `tests/fixtures/pre-commit-hook-installed.sh`
  exits 0 AND `bash -n .githooks/pre-commit` exits 0.

## site-deploy (v3.0.0.20)

- `site-deploy/render-kernel-impl` -> `build` ; `ci:build:render` ;
  `scripts/render.sh` exits 0 AND `tests/cli/render.t` exits 0.
- `site-deploy/site-content-self-referential` -> `test` ;
  `ci:fixture:shell` ; `grep -l "mathc packages" dist/*.html | wc -l`
  returns >= 3 (every site page that documents a kernel feature
  references `mathc packages`).
- `site-deploy/site-deploy-pipeline` -> `build` ; `ci:workflow:site` ;
  `.github/workflows/site.yml` runs `scripts/render.sh` on every
  push to main and publishes `dist/` to GitHub Pages.
- `site-deploy/site-pinned-ubuntu` -> `review` ; `human:maintainer` ;
  manual: `.github/workflows/site.yml` pins `runs-on: ubuntu-22.04`
  in both `build` and `deploy` jobs.

## algebra-3.2 (v3.1.0-alpha; algebra 3.2-ideal implementation)

- `algebra-3.2/spec-file-exists` -> `build` ; `ci:build:docs` ;
  `spec/algebra-3.2.md` exists at HEAD and contains 30 sections
  (per the v3.2-ideal formal spec).
- `algebra-3.2/cross-references-correct` -> `build` ; `ci:build:docs` ;
  spec cross-references resolve to existing files
  (axioms/, spec/constitution.md, spec/algebra-3.2.md).
- `algebra-3.2/applicability-documented` -> `build` ;
  `ci:build:docs` ; USAGE.md "Choose your adoption path" section
  (lines 39-105) describes the §28 envelope.
- `algebra-3.2/kernel-conformance-baseline` -> `test` ;
  `ci:test:self-check` ; `_build/install/default/bin/mathc self-check`
  exits 0 with verdict=pass on clean HEAD (28/28 subjects green).
- `algebra-3.2/adoption-path-documented` -> `build` ;
  `ci:build:docs` ; USAGE.md "Path A" / "Path B" sections present.
- `algebra-3.2/backward-compat-test` -> `test` ;
  `ci:test:fixtures` ; all 28 existing decisions/*.yaml files parse
  under the extended schema (state, body_sha, yaml_sha added as
  optional fields with defaults; no breaking change).
- `algebra-3.2/implementation-roadmap` -> `build` ;
  `ci:build:docs` ; ROADMAP.md Tier 3.5 enumerates 13 implementation
  tasks, all marked landed.

## Notes for the generating agent

- Set `kind_` per the row above.
- Set `producer.identity` per the row above.
- Set `result: "pass"` for everything in this map EXCEPT
  `bootstrap-v3/authoring-benchmark`, which is `inconclusive` (no
  benchmark corpus; waiver-style attestation).
- `candidate_tree` field: set to `"HEAD"` for everything.
- `materials_digest`: empty string (the loader passes it through;
  the gate evaluator does not require it when `candidate_tree` is
  not compared — see `lib/gate.ml:166-171`).
- `issued_at`: use `2026-09-29T18:00:00Z` for every file (atomic
  batch; reduces churn on next refresh).
- `id`: compute as `sha256:` + SHA-256 of the canonical JSON
  serialisation of the rest of the file (sorted keys, no
  whitespace). The agent can use `lib/digest.ml:sha256_hex` (now
  RFC 6234-conformant) or the system's `sha256sum` on a normalised
  string. Validate against `schemas/attestation.json` before
  committing.
- File naming convention: `<decision>-<obligation>.json` (matches
  the fixture-store pattern in `tests/fixtures/self-check-pass/attestations/`).
- After generation, run `MATH_CODING_ATTESTATION_STORE=attestations
  _build/install/default/bin/mathc self-check` and confirm the
  verdict is `pass` (exit 0). If it returns `unknown` or `fail`,
  inspect `attestations/` for the offending subject and re-emit.
