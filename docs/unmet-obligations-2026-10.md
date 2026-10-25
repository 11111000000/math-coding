# Unmet obligations - the 2026-10 re-signing

**14 obligations the re-signing refused to sign.** An unsigned obligation is a GAP, not a pass: the kernel writes no attestation for it, so the corpus claims nothing about it.

## The numbers

| recommendation | obligations |
| --- | --- |
| `fix-the-verifier` | 0 |
| `needs-a-toolchain` | 0 |
| `declare-it-manual` | 1 |
| `investigate` | 13 |
| **total** | **14** |

By class:

- `broken`: 13
- `not-executable`: 1

## The method

The unsigned obligations are read from `./sign-store-sweep.log` - the log the re-signing writes with `--keep-log`. Every one of them is then re-evaluated VERIFIER BY VERIFIER:

1. A throwaway decision is written into the project carrying exactly one obligation with exactly one verifier.
2. It is re-stamped with `mathc rehash --write` - the strict parser enforces the digest fields, so a probe carrying the original's digest is reported as having no obligations, which reads as `skipped` and is a false reading of the verifier.
3. `mathc verify` is run on it, and the kernel's verdict line and the
   kernel's own sandbox excerpt are captured. The excerpt is the verifier's output; it is what the report quotes, not the word "failed".
4. The probe is deleted.

The corpus is parsed with a deliberately narrow pattern (`[ \t]` for indentation, never `\s`), and a decision is resolved BY ITS ID rather than by its file name - sixteen decisions carry an id that differs from their file name, and the kernel resolves them by id.

**THIS REPORT IS A SNAPSHOT OF THE STATE THE SWEEP RAN ON.** The verdicts below are the verdicts of a re-run against that state, and the sweep-time evidence is the evidence of the failure itself. The mechanically repairable targets have since been repaired, so a re-run against the current tree reports that those verifiers now PASS. What the report says about them - which target was wrong and what the right one is - is what the repair was made from, and it is the part worth keeping.

## The obligations

### `ci-cram-cleanup-batch2-2026-10/tier-3c-investigated`

- decision file: `decisions/ci-cram-cleanup-batch2-2026-10.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: `text-scan-decisions/ci-cram-cleanup-batch2-gate-pass-t.yaml` does not exist and no file with that stem does either: the obligation's claim is about a file that was never written, so the repair is to WRITE the file, not to move the pointer. (The path the verifier carries is `text-scan-decisions/ci-cram-cleanup-batch2-gate-pass-t.yaml`; a `text-scan-` scheme prefix glued onto the path is not part of the path.)

Verifiers named by the obligation:

- `file-exists text-scan-decisions/ci-cram-cleanup-batch2-gate-pass-t.yaml` -> **fail**
- `file-exists text-scan-decisions/ci-cram-cleanup-batch2-gate-fail-t.yaml` -> **fail**
- `file-exists text-scan-decisions/ci-cram-cleanup-batch2-doctor-t.yaml` -> **fail**

### `decision-required-attestations/kind-projection-known-and-roundtrippable`

- decision file: `decisions/decision-required-attestations-2026-10.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: no mechanical repair applies: the verifier names a target that does not exist and no unique replacement is derivable from the repository, so the right target has to be decided by a human. The evidence is quoted below

Verifiers named by the obligation:

- `scripts/check.sh` -> **fail**
- `dune build` -> **pass**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/scripts/check.sh`:
  |   ok   3-2-cli-catalog-rows-present
  |   ok   attest-batch-run-digest
  |   ok   ci-green-batch1-fixes
  |   ok   ci-prereqs-precede-consumers
  |   ok   close-branches-runs
  |   ok   cwd-independent-self-check
  |   ok   decision-packges-spelling
  |   ok   decision-resolves-by-id
  |   ok   decisions-precommit-gate-rejects
  |   ok   decisions-precommit-path-independent
  |   ok   dev-cleanup-is-scoped
  |   ok   dune-test-wrapper-propagates-failure
  |   ok   executed-evidence-census
  |   ok   failing-subject-backlog
  |   ok   failing-verifier-is-named
  |   ok   forge-stub-read-request
  |   ok   gate-ref-validation
  |   ok   impl-pending-files-present
  |   ok   init-terminates-outside-tree
  |   ok   legacy-attestation-debt
  | (... truncated)
```

What the same verifier prints when it is re-run now:

`scripts/check.sh`:

```
mathc verify: /home/az/Projects/math-coding/scripts/check.sh exited 1
mathc verify: output of `/home/az/Projects/math-coding/scripts/check.sh`:
  |   ok   3-2-cli-catalog-rows-present
  |   ok   attest-batch-run-digest
  |   ok   ci-green-batch1-fixes
  |   ok   ci-prereqs-precede-consumers
  |   ok   close-branches-runs
  |   ok   cwd-independent-self-check
  |   ok   decision-packges-spelling
  |   ok   decision-resolves-by-id
  |   ok   decisions-precommit-gate-rejects
  |   ok   decisions-precommit-path-independent
  |   ok   dev-cleanup-is-scoped
  |   ok   dune-test-wrapper-propagates-failure
  |   ok   executed-evidence-census
  |   ok   failing-subject-backlog
  |   ok   failing-verifier-is-named
  |   ok   forge-stub-read-request
  |   ok   gate-ref-validation
  |   ok   impl-pending-files-present
  |   ok   init-terminates-outside-tree
  |   ok   legacy-attestation-debt
  | (... truncated)
```

### `disable-counters-drift-test-2026-10/counters-drift-disabled`

- decision file: `decisions/disable-counters-drift-test-2026-10.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: no mechanical repair applies: the verifier names a target that does not exist and no unique replacement is derivable from the repository, so the right target has to be decided by a human. The evidence is quoted below

Verifiers named by the obligation:

- `scripts/check.sh` -> **fail**
- `manual-grep-f-counters-drift-tests-dune-grep-enabled-if` -> **skipped**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/scripts/check.sh`:
  |   ok   3-2-cli-catalog-rows-present
  |   ok   attest-batch-run-digest
  |   ok   ci-green-batch1-fixes
  |   ok   ci-prereqs-precede-consumers
  |   ok   close-branches-runs
  |   ok   cwd-independent-self-check
  |   ok   decision-packges-spelling
  |   ok   decision-resolves-by-id
  |   ok   decisions-precommit-gate-rejects
  |   ok   decisions-precommit-path-independent
  |   ok   dev-cleanup-is-scoped
  |   ok   dune-test-wrapper-propagates-failure
  |   ok   executed-evidence-census
  |   ok   failing-subject-backlog
  |   ok   failing-verifier-is-named
  |   ok   forge-stub-read-request
  |   ok   gate-ref-validation
  |   ok   impl-pending-files-present
  |   ok   init-terminates-outside-tree
  |   ok   legacy-attestation-debt
  | (... truncated)
```

What the same verifier prints when it is re-run now:

`scripts/check.sh`:

```
mathc verify: /home/az/Projects/math-coding/scripts/check.sh exited 1
mathc verify: output of `/home/az/Projects/math-coding/scripts/check.sh`:
  |   ok   3-2-cli-catalog-rows-present
  |   ok   attest-batch-run-digest
  |   ok   ci-green-batch1-fixes
  |   ok   ci-prereqs-precede-consumers
  |   ok   close-branches-runs
  |   ok   cwd-independent-self-check
  |   ok   decision-packges-spelling
  |   ok   decision-resolves-by-id
  |   ok   decisions-precommit-gate-rejects
  |   ok   decisions-precommit-path-independent
  |   ok   dev-cleanup-is-scoped
  |   ok   dune-test-wrapper-propagates-failure
  |   ok   executed-evidence-census
  |   ok   failing-subject-backlog
  |   ok   failing-verifier-is-named
  |   ok   forge-stub-read-request
  |   ok   gate-ref-validation
  |   ok   impl-pending-files-present
  |   ok   init-terminates-outside-tree
  |   ok   legacy-attestation-debt
  | (... truncated)
```

### `docker-availability-guarantee-2026-10/docker-image-healthcheck-runs`

- decision file: `decisions/docker-availability-guarantee-2026-10.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: `attestations/docker-availability-guarantee-2026-10-docker-image-healthcheck.json` does not exist and no file with that stem does either: the obligation's claim is about a file that was never written, so the repair is to WRITE the file, not to move the pointer. (The path the verifier carries is `attestations/docker-availability-guarantee-2026-10-docker-image-healthcheck.json`; a `text-scan-` scheme prefix glued onto the path is not part of the path.)

Verifiers named by the obligation:

- `manual-this-attestation-file-present` -> **skipped**
- `mathc validate attestations/docker-availability-guarantee-2026-10-docker-image-healthcheck.json` -> **fail**
- `manual-test-f-github-workflows-docker-healthcheck-yml` -> **skipped**

What the verifier printed during the re-signing:

```
mathc verify: mathc exited 2
```

What the same verifier prints when it is re-run now:

`mathc validate attestations/docker-availability-guarantee-2026-10-docker-image-healthcheck.json`:

```
[warn] input/MC-INPUT: attestations/docker-availability-guarantee-2026-10-docker-image-healthcheck.json: No such file or directory
mathc verify: mathc exited 2
```

### `exit-code-symmetry/constitution-14b-added`

- decision file: `decisions/exit-code-symmetry-2026-10.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: no mechanical repair applies: the verifier names a target that does not exist and no unique replacement is derivable from the repository, so the right target has to be decided by a human. The evidence is quoted below

Verifiers named by the obligation:

- `tests/cli/gate-unknown-exit-3.t` -> **pass**
- `scripts/check.sh` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/scripts/check.sh`:
  |   ok   3-2-cli-catalog-rows-present
  |   ok   attest-batch-run-digest
  |   ok   ci-green-batch1-fixes
  |   ok   ci-prereqs-precede-consumers
  |   ok   close-branches-runs
  |   ok   cwd-independent-self-check
  |   ok   decision-packges-spelling
  |   ok   decision-resolves-by-id
  |   ok   decisions-precommit-gate-rejects
  |   ok   decisions-precommit-path-independent
  |   ok   dev-cleanup-is-scoped
  |   ok   dune-test-wrapper-propagates-failure
  |   ok   executed-evidence-census
  |   ok   failing-subject-backlog
  |   ok   failing-verifier-is-named
  |   ok   forge-stub-read-request
  |   ok   gate-ref-validation
  |   ok   impl-pending-files-present
  |   ok   init-terminates-outside-tree
  |   ok   legacy-attestation-debt
  | (... truncated)
```

What the same verifier prints when it is re-run now:

`scripts/check.sh`:

```
mathc verify: /home/az/Projects/math-coding/scripts/check.sh exited 1
mathc verify: output of `/home/az/Projects/math-coding/scripts/check.sh`:
  |   ok   3-2-cli-catalog-rows-present
  |   ok   attest-batch-run-digest
  |   ok   ci-green-batch1-fixes
  |   ok   ci-prereqs-precede-consumers
  |   ok   close-branches-runs
  |   ok   cwd-independent-self-check
  |   ok   decision-packges-spelling
  |   ok   decision-resolves-by-id
  |   ok   decisions-precommit-gate-rejects
  |   FAIL decisions-precommit-path-independent
  |   ok   dev-cleanup-is-scoped
  |   ok   dune-test-wrapper-propagates-failure
  |   ok   executed-evidence-census
  |   ok   failing-subject-backlog
  |   ok   failing-verifier-is-named
  |   ok   forge-stub-read-request
  |   ok   gate-ref-validation
  |   ok   impl-pending-files-present
  |   ok   init-terminates-outside-tree
  |   ok   legacy-attestation-debt
  | (... truncated)
```

### `mathc-counters-subcommand-2026-10/dev-counters-py-deleted`

- decision file: `decisions/mathc-counters-subcommand-2026-10.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: no mechanical repair applies: the verifier names a target that does not exist and no unique replacement is derivable from the repository, so the right target has to be decided by a human. The evidence is quoted below

Verifiers named by the obligation:

- `scripts/check.sh` -> **fail**
- `tests/repo_structure.ml` -> **pass**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/scripts/check.sh`:
  |   ok   3-2-cli-catalog-rows-present
  |   ok   attest-batch-run-digest
  |   ok   ci-green-batch1-fixes
  |   ok   ci-prereqs-precede-consumers
  |   ok   close-branches-runs
  |   ok   cwd-independent-self-check
  |   ok   decision-packges-spelling
  |   ok   decision-resolves-by-id
  |   ok   decisions-precommit-gate-rejects
  |   ok   decisions-precommit-path-independent
  |   ok   dev-cleanup-is-scoped
  |   ok   dune-test-wrapper-propagates-failure
  |   ok   executed-evidence-census
  |   ok   failing-subject-backlog
  |   ok   failing-verifier-is-named
  |   ok   forge-stub-read-request
  |   ok   gate-ref-validation
  |   ok   impl-pending-files-present
  |   ok   init-terminates-outside-tree
  |   ok   legacy-attestation-debt
  | (... truncated)
```

What the same verifier prints when it is re-run now:

`scripts/check.sh`:

```
mathc verify: /home/az/Projects/math-coding/scripts/check.sh exited 1
mathc verify: output of `/home/az/Projects/math-coding/scripts/check.sh`:
  |   ok   3-2-cli-catalog-rows-present
  |   ok   attest-batch-run-digest
  |   ok   ci-green-batch1-fixes
  |   ok   ci-prereqs-precede-consumers
  |   ok   close-branches-runs
  |   ok   cwd-independent-self-check
  |   ok   decision-packges-spelling
  |   ok   decision-resolves-by-id
  |   ok   decisions-precommit-gate-rejects
  |   ok   decisions-precommit-path-independent
  |   ok   dev-cleanup-is-scoped
  |   ok   dune-test-wrapper-propagates-failure
  |   ok   executed-evidence-census
  |   ok   failing-subject-backlog
  |   ok   failing-verifier-is-named
  |   ok   forge-stub-read-request
  |   ok   gate-ref-validation
  |   ok   impl-pending-files-present
  |   ok   init-terminates-outside-tree
  |   ok   legacy-attestation-debt
  | (... truncated)
```

### `mathc-doctor-subcommand-2026-10/doctor-subcommand-dispatched`

- decision file: `decisions/mathc-doctor-subcommand-2026-10.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: the verifier is a SHELL PIPELINE, and `mathc verify` never spawns a shell: the pipe is handed to the command as ordinary arguments, so the command exits 2 (input error). Expressing this check needs a fixture or a kernel subcommand that performs the assertion - not a pipeline in a decision file

Verifiers named by the obligation:

- `file-exists decisions/mathc-doctor-subcommand-2026-10.yaml` -> **pass**
- `mathc validate decisions/mathc-doctor-subcommand-2026-10.yaml` -> **pass**
- `dune build bin/mathc.exe` -> **pass**
- `mathc doctor` -> **pass**
- `mathc doctor --json | jq .sections | jq 'length >= 5'` -> **fail**
- `manual-target-missing-tests-cli-doctor-t-runs-via-dune-` -> **skipped**
- `manual-target-missing-scripts-dev-lint-no-mathc-library` -> **skipped**
- `manual-git-grep-lib-bin-mathc-ml-returns-only-the-exist` -> **skipped**

What the verifier printed during the re-signing:

```
mathc verify: mathc exited 2
```

What the same verifier prints when it is re-run now:

`mathc doctor --json | jq .sections | jq 'length >= 5'`:

```
mathc doctor: unexpected argument: |
mathc verify: mathc exited 2
```

### `plan-2026-10-distro-friction/d10-mathc-doctor-subcommand`

- decision file: `decisions/plan-2026-10-distro-friction.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: the verifier is a SHELL PIPELINE, and `mathc verify` never spawns a shell: the pipe is handed to the command as ordinary arguments, so the command exits 2 (input error). Expressing this check needs a fixture or a kernel subcommand that performs the assertion - not a pipeline in a decision file

Verifiers named by the obligation:

- `file-exists decisions/plan-2026-10-distro-friction.yaml` -> **pass**
- `mathc validate decisions/mathc-doctor-subcommand-2026-10.yaml` -> **pass**
- `mathc doctor` -> **pass**
- `mathc doctor --json | jq .sections | jq 'length >= 5'` -> **fail**
- `tests/cli/doctor.t` -> **pass**

What the verifier printed during the re-signing:

```
mathc verify: mathc exited 2
```

What the same verifier prints when it is re-run now:

`mathc doctor --json | jq .sections | jq 'length >= 5'`:

```
mathc doctor: unexpected argument: |
mathc verify: mathc exited 2
```

### `plan-2026-10-improvements/t6-1-no-stub-without-tracking`

- decision file: `decisions/plan-2026-10-improvements.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: no mechanical repair applies: the verifier names a target that does not exist and no unique replacement is derivable from the repository, so the right target has to be decided by a human. The evidence is quoted below

Verifiers named by the obligation:

- `scripts/check.sh` -> **fail**
- `manual-target-missing-tests-process-principles-ml-p8-no` -> **skipped**
- `manual-decisions-plan-2026-10-improvements-t6-1-yaml-1-` -> **skipped**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/scripts/check.sh`:
  |   ok   3-2-cli-catalog-rows-present
  |   ok   attest-batch-run-digest
  |   ok   ci-green-batch1-fixes
  |   ok   ci-prereqs-precede-consumers
  |   ok   close-branches-runs
  |   ok   cwd-independent-self-check
  |   ok   decision-packges-spelling
  |   ok   decision-resolves-by-id
  |   ok   decisions-precommit-gate-rejects
  |   ok   decisions-precommit-path-independent
  |   ok   dev-cleanup-is-scoped
  |   ok   dune-test-wrapper-propagates-failure
  |   ok   executed-evidence-census
  |   ok   failing-subject-backlog
  |   ok   failing-verifier-is-named
  |   ok   forge-stub-read-request
  |   ok   gate-ref-validation
  |   ok   impl-pending-files-present
  |   ok   init-terminates-outside-tree
  |   ok   legacy-attestation-debt
  | (... truncated)
```

What the same verifier prints when it is re-run now:

`scripts/check.sh`:

```
mathc verify: /home/az/Projects/math-coding/scripts/check.sh exited 1
mathc verify: output of `/home/az/Projects/math-coding/scripts/check.sh`:
  |   ok   3-2-cli-catalog-rows-present
  |   ok   attest-batch-run-digest
  |   ok   ci-green-batch1-fixes
  |   ok   ci-prereqs-precede-consumers
  |   ok   close-branches-runs
  |   ok   cwd-independent-self-check
  |   ok   decision-packges-spelling
  |   ok   decision-resolves-by-id
  |   ok   decisions-precommit-gate-rejects
  |   ok   decisions-precommit-path-independent
  |   ok   dev-cleanup-is-scoped
  |   ok   dune-test-wrapper-propagates-failure
  |   ok   executed-evidence-census
  |   ok   failing-subject-backlog
  |   ok   failing-verifier-is-named
  |   ok   forge-stub-read-request
  |   ok   gate-ref-validation
  |   ok   impl-pending-files-present
  |   ok   init-terminates-outside-tree
  |   ok   legacy-attestation-debt
  | (... truncated)
```

### `render-ordered-lists-2026-10/ordered-list-negative`

- decision file: `decisions/render-ordered-lists-2026-10.yaml`
- verdict: `not-executable`
- recommendation: `declare-it-manual`
- why: every verifier of this obligation is a `manual-` declaration; the kernel does not execute them and records them as `review`/`inconclusive`. The declaration must name the file and the needle a human is to look for - and 1 of the 3 declarations are the SAME string (`manual-target-missing-tests-render-kernel-ml-ordered-li`), so they cannot name 3 different things. The name points at `tests/render_kernel.ml`; the case the claim is about is `ordered_list_invalid_marker_stays_paragraph`

Verifiers named by the obligation:

- `manual-target-missing-tests-render-kernel-ml-ordered-li` -> **skipped**
- `manual-target-missing-tests-render-kernel-ml-ordered-li` -> **skipped**
- `manual-target-missing-tests-render-kernel-ml-ordered-li` -> **skipped**

### `unmet-obligations-inventory-2026-10/the-inventory-covers-every-unsigned-obligation`

- decision file: `decisions/unmet-obligations-inventory-2026-10.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: no mechanical repair applies: the verifier names a target that does not exist and no unique replacement is derivable from the repository, so the right target has to be decided by a human. The evidence is quoted below

Verifiers named by the obligation:

- `tests/fixtures/unmet-obligations-are-inventoried.sh` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/tests/fixtures/unmet-obligations-are-inventoried.sh`:
  | FAIL: the inventory does not cover every unsigned obligation:
  |     antithesis-mode-considered-2026-10/dune-build-and-tests-green is unsigned in the sweep log and absent from the inventory
  |     audit-0.0.21-fixes/schema-supports-yaml-decision-form is unsigned in the sweep log and absent from the inventory
  |     audit-0.0.21-fixes/parser-accepts-yaml-form is unsigned in the sweep log and absent from the inventory
  |     ci-cram-cleanup-batch2-2026-10/tier-3b-fixed is unsigned in the sweep log and absent from the inventory
  |     cli-cram-tests/cli-tests-via-cram is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/corpus-scan-is-reproducible is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/offender-set-is-an-exact-set is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/kernel-holes-are-empty is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/cosmetic-markers-lose-nothing is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/a-wrong-fold-is-caught-not-just-a-wrong-stop is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/every-pin-is-mutation-checked is unsigned in the sweep log and absent from the inventory
  |     counters-schema-introspection-fix-2026-10/schema-enum-non-empty-after-rebuild is unsigned in the sweep log and absent from the inventory
  |     counters-schema-introspection-fix-2026-10/intent-oneof-true-after-rebuild is unsigned in the sweep log and absent from the inventory
  |     counters-schema-introspection-fix-2026-10/scope-oneof-true-after-rebuild is unsigned in the sweep log and absent from the inventory
  |     counters-schema-introspection-fix-2026-10/required-fields-still-correct is unsigned in the sweep log and absent from the inventory
  |     counters-schema-introspection-fix-2026-10/dune-test-clean is unsigned in the sweep log and absent from the inventory
  |     d5-body-vs-wrapper-canonical-2026-10/spec-formalises-byte-range is unsigned in the sweep log and absent from the inventory
  |     d5-body-vs-wrapper-canonical-2026-10/kernel-comment-references-decision is unsigned in the sweep log and absent from the inventory
  |     d5-body-vs-wrapper-canonical-2026-10/cram-fixture-integration is unsigned in the sweep log and absent from the inventory
  | (... truncated)
```

What the same verifier prints when it is re-run now:

`tests/fixtures/unmet-obligations-are-inventoried.sh`:

```
mathc verify: /home/az/Projects/math-coding/tests/fixtures/unmet-obligations-are-inventoried.sh exited 1
mathc verify: output of `/home/az/Projects/math-coding/tests/fixtures/unmet-obligations-are-inventoried.sh`:
  | FAIL: the inventory does not cover every unsigned obligation:
  |     decision-required-attestations/kind-projection-known-and-roundtrippable is unsigned in the sweep log and absent from the inventory
  |     disable-counters-drift-test-2026-10/counters-drift-disabled is unsigned in the sweep log and absent from the inventory
  |     exit-code-symmetry/constitution-14b-added is unsigned in the sweep log and absent from the inventory
  |     mathc-counters-subcommand-2026-10/dev-counters-py-deleted is unsigned in the sweep log and absent from the inventory
  |     plan-2026-10-improvements/t6-1-no-stub-without-tracking is unsigned in the sweep log and absent from the inventory
  |     unmet-obligations-inventory-2026-10/the-inventory-covers-every-unsigned-obligation is unsigned in the sweep log and absent from the inventory
  |     unmet-obligations-inventory-2026-10/the-count-and-the-breakdown-are-recorded is unsigned in the sweep log and absent from the inventory
  |     unmet-obligations-inventory-2026-10/an-unsigned-obligation-is-a-gap is unsigned in the sweep log and absent from the inventory
  |     audit-0.0.21-fixes/self-check-pass-fixture-covers-all is in the inventory but the sweep log does not name it
  |     d5-body-vs-wrapper-canonical-2026-10/kernel-test-asserts-algorithm is in the inventory but the sweep log does not name it
  |     infrastructure-honesty/fix-ci-targets is in the inventory but the sweep log does not name it
  |     infrastructure-honesty/pin-nixpkgs-commit is in the inventory but the sweep log does not name it
  |     infrastructure-honesty/verify-opam-checksum is in the inventory but the sweep log does not name it
  |     install-tooling-default-tag-stable/install-sh-default-tag-is-latest is in the inventory but the sweep log does not name it
  |     kernel-conformance-runner/enumerate-and-classify-fixtures is in the inventory but the sweep log does not name it
  |     kernel-conformance-runner/parse-positive-and-negative-decision is in the inventory but the sweep log does not name it
  |     kernel-conformance-runner/skip-non-decision-fixtures-with-warning is in the inventory but the sweep log does not name it
  |     legacy-attestation-debt-2026-10/debt-is-measured-and-bounded is in the inventory but the sweep log does not name it
  |     legacy-debt-paydown-2026-10/three-debts-are-measured-and-bounded is in the inventory but the sweep log does not name it
  | (... truncated)
```

### `unmet-obligations-inventory-2026-10/the-count-and-the-breakdown-are-recorded`

- decision file: `decisions/unmet-obligations-inventory-2026-10.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: no mechanical repair applies: the verifier names a target that does not exist and no unique replacement is derivable from the repository, so the right target has to be decided by a human. The evidence is quoted below

Verifiers named by the obligation:

- `tests/fixtures/unmet-obligations-are-inventoried.sh` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/tests/fixtures/unmet-obligations-are-inventoried.sh`:
  | FAIL: the inventory does not cover every unsigned obligation:
  |     antithesis-mode-considered-2026-10/dune-build-and-tests-green is unsigned in the sweep log and absent from the inventory
  |     audit-0.0.21-fixes/schema-supports-yaml-decision-form is unsigned in the sweep log and absent from the inventory
  |     audit-0.0.21-fixes/parser-accepts-yaml-form is unsigned in the sweep log and absent from the inventory
  |     ci-cram-cleanup-batch2-2026-10/tier-3b-fixed is unsigned in the sweep log and absent from the inventory
  |     cli-cram-tests/cli-tests-via-cram is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/corpus-scan-is-reproducible is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/offender-set-is-an-exact-set is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/kernel-holes-are-empty is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/cosmetic-markers-lose-nothing is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/a-wrong-fold-is-caught-not-just-a-wrong-stop is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/every-pin-is-mutation-checked is unsigned in the sweep log and absent from the inventory
  |     counters-schema-introspection-fix-2026-10/schema-enum-non-empty-after-rebuild is unsigned in the sweep log and absent from the inventory
  |     counters-schema-introspection-fix-2026-10/intent-oneof-true-after-rebuild is unsigned in the sweep log and absent from the inventory
  |     counters-schema-introspection-fix-2026-10/scope-oneof-true-after-rebuild is unsigned in the sweep log and absent from the inventory
  |     counters-schema-introspection-fix-2026-10/required-fields-still-correct is unsigned in the sweep log and absent from the inventory
  |     counters-schema-introspection-fix-2026-10/dune-test-clean is unsigned in the sweep log and absent from the inventory
  |     d5-body-vs-wrapper-canonical-2026-10/spec-formalises-byte-range is unsigned in the sweep log and absent from the inventory
  |     d5-body-vs-wrapper-canonical-2026-10/kernel-comment-references-decision is unsigned in the sweep log and absent from the inventory
  |     d5-body-vs-wrapper-canonical-2026-10/cram-fixture-integration is unsigned in the sweep log and absent from the inventory
  | (... truncated)
```

What the same verifier prints when it is re-run now:

`tests/fixtures/unmet-obligations-are-inventoried.sh`:

```
mathc verify: /home/az/Projects/math-coding/tests/fixtures/unmet-obligations-are-inventoried.sh exited 1
mathc verify: output of `/home/az/Projects/math-coding/tests/fixtures/unmet-obligations-are-inventoried.sh`:
  | FAIL: the inventory does not cover every unsigned obligation:
  |     decision-required-attestations/kind-projection-known-and-roundtrippable is unsigned in the sweep log and absent from the inventory
  |     disable-counters-drift-test-2026-10/counters-drift-disabled is unsigned in the sweep log and absent from the inventory
  |     exit-code-symmetry/constitution-14b-added is unsigned in the sweep log and absent from the inventory
  |     mathc-counters-subcommand-2026-10/dev-counters-py-deleted is unsigned in the sweep log and absent from the inventory
  |     plan-2026-10-improvements/t6-1-no-stub-without-tracking is unsigned in the sweep log and absent from the inventory
  |     unmet-obligations-inventory-2026-10/the-inventory-covers-every-unsigned-obligation is unsigned in the sweep log and absent from the inventory
  |     unmet-obligations-inventory-2026-10/the-count-and-the-breakdown-are-recorded is unsigned in the sweep log and absent from the inventory
  |     unmet-obligations-inventory-2026-10/an-unsigned-obligation-is-a-gap is unsigned in the sweep log and absent from the inventory
  |     audit-0.0.21-fixes/self-check-pass-fixture-covers-all is in the inventory but the sweep log does not name it
  |     d5-body-vs-wrapper-canonical-2026-10/kernel-test-asserts-algorithm is in the inventory but the sweep log does not name it
  |     infrastructure-honesty/fix-ci-targets is in the inventory but the sweep log does not name it
  |     infrastructure-honesty/pin-nixpkgs-commit is in the inventory but the sweep log does not name it
  |     infrastructure-honesty/verify-opam-checksum is in the inventory but the sweep log does not name it
  |     install-tooling-default-tag-stable/install-sh-default-tag-is-latest is in the inventory but the sweep log does not name it
  |     kernel-conformance-runner/enumerate-and-classify-fixtures is in the inventory but the sweep log does not name it
  |     kernel-conformance-runner/parse-positive-and-negative-decision is in the inventory but the sweep log does not name it
  |     kernel-conformance-runner/skip-non-decision-fixtures-with-warning is in the inventory but the sweep log does not name it
  |     legacy-attestation-debt-2026-10/debt-is-measured-and-bounded is in the inventory but the sweep log does not name it
  |     legacy-debt-paydown-2026-10/three-debts-are-measured-and-bounded is in the inventory but the sweep log does not name it
  | (... truncated)
```

### `unmet-obligations-inventory-2026-10/an-unsigned-obligation-is-a-gap`

- decision file: `decisions/unmet-obligations-inventory-2026-10.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: no mechanical repair applies: the verifier names a target that does not exist and no unique replacement is derivable from the repository, so the right target has to be decided by a human. The evidence is quoted below

Verifiers named by the obligation:

- `tests/fixtures/unmet-obligations-are-inventoried.sh` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/tests/fixtures/unmet-obligations-are-inventoried.sh`:
  | FAIL: the inventory does not cover every unsigned obligation:
  |     antithesis-mode-considered-2026-10/dune-build-and-tests-green is unsigned in the sweep log and absent from the inventory
  |     audit-0.0.21-fixes/schema-supports-yaml-decision-form is unsigned in the sweep log and absent from the inventory
  |     audit-0.0.21-fixes/parser-accepts-yaml-form is unsigned in the sweep log and absent from the inventory
  |     ci-cram-cleanup-batch2-2026-10/tier-3b-fixed is unsigned in the sweep log and absent from the inventory
  |     cli-cram-tests/cli-tests-via-cram is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/corpus-scan-is-reproducible is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/offender-set-is-an-exact-set is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/kernel-holes-are-empty is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/cosmetic-markers-lose-nothing is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/a-wrong-fold-is-caught-not-just-a-wrong-stop is unsigned in the sweep log and absent from the inventory
  |     corpus-silent-drop-inventory-2026-10/every-pin-is-mutation-checked is unsigned in the sweep log and absent from the inventory
  |     counters-schema-introspection-fix-2026-10/schema-enum-non-empty-after-rebuild is unsigned in the sweep log and absent from the inventory
  |     counters-schema-introspection-fix-2026-10/intent-oneof-true-after-rebuild is unsigned in the sweep log and absent from the inventory
  |     counters-schema-introspection-fix-2026-10/scope-oneof-true-after-rebuild is unsigned in the sweep log and absent from the inventory
  |     counters-schema-introspection-fix-2026-10/required-fields-still-correct is unsigned in the sweep log and absent from the inventory
  |     counters-schema-introspection-fix-2026-10/dune-test-clean is unsigned in the sweep log and absent from the inventory
  |     d5-body-vs-wrapper-canonical-2026-10/spec-formalises-byte-range is unsigned in the sweep log and absent from the inventory
  |     d5-body-vs-wrapper-canonical-2026-10/kernel-comment-references-decision is unsigned in the sweep log and absent from the inventory
  |     d5-body-vs-wrapper-canonical-2026-10/cram-fixture-integration is unsigned in the sweep log and absent from the inventory
  | (... truncated)
```

What the same verifier prints when it is re-run now:

`tests/fixtures/unmet-obligations-are-inventoried.sh`:

```
mathc verify: /home/az/Projects/math-coding/tests/fixtures/unmet-obligations-are-inventoried.sh exited 1
mathc verify: output of `/home/az/Projects/math-coding/tests/fixtures/unmet-obligations-are-inventoried.sh`:
  | FAIL: the inventory does not cover every unsigned obligation:
  |     decision-required-attestations/kind-projection-known-and-roundtrippable is unsigned in the sweep log and absent from the inventory
  |     disable-counters-drift-test-2026-10/counters-drift-disabled is unsigned in the sweep log and absent from the inventory
  |     exit-code-symmetry/constitution-14b-added is unsigned in the sweep log and absent from the inventory
  |     mathc-counters-subcommand-2026-10/dev-counters-py-deleted is unsigned in the sweep log and absent from the inventory
  |     plan-2026-10-improvements/t6-1-no-stub-without-tracking is unsigned in the sweep log and absent from the inventory
  |     unmet-obligations-inventory-2026-10/the-inventory-covers-every-unsigned-obligation is unsigned in the sweep log and absent from the inventory
  |     unmet-obligations-inventory-2026-10/the-count-and-the-breakdown-are-recorded is unsigned in the sweep log and absent from the inventory
  |     unmet-obligations-inventory-2026-10/an-unsigned-obligation-is-a-gap is unsigned in the sweep log and absent from the inventory
  |     audit-0.0.21-fixes/self-check-pass-fixture-covers-all is in the inventory but the sweep log does not name it
  |     d5-body-vs-wrapper-canonical-2026-10/kernel-test-asserts-algorithm is in the inventory but the sweep log does not name it
  |     infrastructure-honesty/fix-ci-targets is in the inventory but the sweep log does not name it
  |     infrastructure-honesty/pin-nixpkgs-commit is in the inventory but the sweep log does not name it
  |     infrastructure-honesty/verify-opam-checksum is in the inventory but the sweep log does not name it
  |     install-tooling-default-tag-stable/install-sh-default-tag-is-latest is in the inventory but the sweep log does not name it
  |     kernel-conformance-runner/enumerate-and-classify-fixtures is in the inventory but the sweep log does not name it
  |     kernel-conformance-runner/parse-positive-and-negative-decision is in the inventory but the sweep log does not name it
  |     kernel-conformance-runner/skip-non-decision-fixtures-with-warning is in the inventory but the sweep log does not name it
  |     legacy-attestation-debt-2026-10/debt-is-measured-and-bounded is in the inventory but the sweep log does not name it
  |     legacy-debt-paydown-2026-10/three-debts-are-measured-and-bounded is in the inventory but the sweep log does not name it
  | (... truncated)
```

### `validator-actionable-error/existing-decisions-still-parse`

- decision file: `decisions/validator-actionable-error.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: the verifier is a GLOB, and `mathc verify` never spawns a shell, so the glob is not expanded: it reaches the command as a literal file name and the command exits 2 (input error). The check needs a verifier that takes one concrete target

Verifiers named by the obligation:

- `mathc validate decisions/*.yaml` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: mathc exited 2
```

What the same verifier prints when it is re-run now:

`mathc validate decisions/*.yaml`:

```
[warn] input/MC-INPUT: decisions/*.yaml: No such file or directory
mathc verify: mathc exited 2
```

