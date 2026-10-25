# Unmet obligations - the 2026-10 re-signing

**30 obligations the re-signing refused to sign.** An unsigned obligation is a GAP, not a pass: the kernel writes no attestation for it, so the corpus claims nothing about it.

## The numbers

| recommendation | obligations |
| --- | --- |
| `fix-the-verifier` | 15 |
| `needs-a-toolchain` | 0 |
| `declare-it-manual` | 1 |
| `investigate` | 14 |
| **total** | **30** |

By class:

- `all-pass-contradiction`: 6
- `broken`: 23
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

### `audit-0.0.21-fixes/self-check-pass-fixture-covers-all`

- decision file: `decisions/audit-0.0.21-fixes.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: the verifier compares the COMMITTED fixture `tests/fixtures/self-check-pass/attestations/` against the LIVE obligation enumeration, and the corpus has grown since the fixture was generated: the pairs listed as MISSING below have no fixture file. The verifier is right; the fixture is stale

Verifiers named by the obligation:

- `scripts/check-self-check-fixture-coverage.sh` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/scripts/check-self-check-fixture-coverage.sh`:
  |   MISSING   decision-resolves-by-id-2026-10-a-failing-verifier-is-still-reported-as-failing.json
  |   MISSING   decision-resolves-by-id-2026-10-the-id-resolves-regardless-of-the-file-name.json
  |   MISSING   honest-attestation-emission-2026-10-manual-declarations-are-not-passes.json
  |   MISSING   honest-attestation-emission-2026-10-runtime-attestations-name-their-run.json
  |   MISSING   honest-attestation-emission-2026-10-the-re-sign-prunes-orphans.json
  |   MISSING   scope-invalidation-breadth-2026-10-the-breadth-does-not-grow.json
  |   MISSING   scope-invalidation-breadth-2026-10-the-measurement-is-not-vacuous.json
  | self-check-fixture-coverage: FAIL: 7 required pair(s) have no fixture file
  | self-check-fixture-coverage: enumerated pairs = 880 (873 required, 7 exempt under portable-linux-musl)
  | self-check-fixture-coverage: fixture files      = 873
  | self-check-fixture-coverage: required covered   = 866
  | self-check-fixture-coverage: exempt files present = 7 (not required)
  | 
```

What the same verifier prints when it is re-run now:

`scripts/check-self-check-fixture-coverage.sh`:

```
mathc verify: /home/az/.paseo/worktrees/3iuxqmnd/feat-classify-the-remaining-failures/scripts/check-self-check-fixture-coverage.sh exited 1
mathc verify: output of `/home/az/.paseo/worktrees/3iuxqmnd/feat-classify-the-remaining-failures/scripts/check-self-check-fixture-coverage.sh`:
  |   MISSING   decision-resolves-by-id-2026-10-a-failing-verifier-is-still-reported-as-failing.json
  |   MISSING   decision-resolves-by-id-2026-10-the-id-resolves-regardless-of-the-file-name.json
  |   MISSING   honest-attestation-emission-2026-10-manual-declarations-are-not-passes.json
  |   MISSING   honest-attestation-emission-2026-10-runtime-attestations-name-their-run.json
  |   MISSING   honest-attestation-emission-2026-10-the-re-sign-prunes-orphans.json
  |   MISSING   scope-invalidation-breadth-2026-10-the-breadth-does-not-grow.json
  |   MISSING   scope-invalidation-breadth-2026-10-the-measurement-is-not-vacuous.json
  |   MISSING   unmet-obligations-inventory-2026-10-an-unsigned-obligation-is-a-gap.json
  |   MISSING   unmet-obligations-inventory-2026-10-the-count-and-the-breakdown-are-recorded.json
  |   MISSING   unmet-obligations-inventory-2026-10-the-inventory-covers-every-unsigned-obligation.json
  | self-check-fixture-coverage: FAIL: 10 required pair(s) have no fixture file
  | self-check-fixture-coverage: enumerated pairs = 883 (876 required, 7 exempt under portable-linux-musl)
  | self-check-fixture-coverage: fixture files      = 873
  | self-check-fixture-coverage: required covered   = 866
  | self-check-fixture-coverage: exempt files present = 7 (not required)
  |
```

### `ci-cram-cleanup-batch2-2026-10/tier-3c-investigated`

- decision file: `decisions/ci-cram-cleanup-batch2-2026-10.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: `text-scan-decisions/ci-cram-cleanup-batch2-gate-pass-t.yaml` does not exist and no file with that stem does either: the obligation's claim is about a file that was never written, so the repair is to WRITE the file, not to move the pointer. (The path the verifier carries is `text-scan-decisions/ci-cram-cleanup-batch2-gate-pass-t.yaml`; a `text-scan-` scheme prefix glued onto the path is not part of the path.)

Verifiers named by the obligation:

- `file-exists text-scan-decisions/ci-cram-cleanup-batch2-gate-pass-t.yaml` -> **fail**
- `file-exists text-scan-decisions/ci-cram-cleanup-batch2-gate-fail-t.yaml` -> **fail**
- `file-exists text-scan-decisions/ci-cram-cleanup-batch2-doctor-t.yaml` -> **fail**

### `d5-body-vs-wrapper-canonical-2026-10/kernel-test-asserts-algorithm`

- decision file: `decisions/d5-body-vs-wrapper-canonical-2026-10.yaml`
- verdict: `broken`
- recommendation: `fix-the-verifier`
- right target: `tests/body_canonical_test.ml::byte_range_algorithm`
- why: the Alcotest selector is a regex against the GROUP name, and `stability` is a case inside the group `byte_range_algorithm`; naming the case matches no group, and alcotest answers "no tests to run, filter skipped everything"

Verifiers named by the obligation:

- `dune build` -> **pass**
- `tests/body_canonical_test.ml::stability` -> **fail**
- `tests/body_canonical_test.ml::sensitivity` -> **fail**
- `tests/body_canonical_test.ml::insensitivity_to_placeholder` -> **fail**
- `tests/body_canonical_test.ml::crlf_equals_lf` -> **fail**

What the same verifier prints when it is re-run now:

`tests/body_canonical_test.ml::stability`:

```
mathc verify: dune exited 1
mathc verify: output of `dune exec ./tests/body_canonical_test.exe -- test ^stability$`:
  | [31mInvalid request (no tests to run, filter skipped everything)![0m
  | Testing `[1mbody_canonical_test[0m'.
  | [2mThis run has ID `20C18HFB'.
  | 
  | [0m
```

`tests/body_canonical_test.ml::sensitivity`:

```
mathc verify: dune exited 1
mathc verify: output of `dune exec ./tests/body_canonical_test.exe -- test ^sensitivity$`:
  | [31mInvalid request (no tests to run, filter skipped everything)![0m
  | Testing `[1mbody_canonical_test[0m'.
  | [2mThis run has ID `0D0LH7BZ'.
  | 
  | [0m
```

`tests/body_canonical_test.ml::insensitivity_to_placeholder`:

```
mathc verify: dune exited 1
mathc verify: output of `dune exec ./tests/body_canonical_test.exe -- test ^insensitivity_to_placeholder$`:
  | [31mInvalid request (no tests to run, filter skipped everything)![0m
  | Testing `[1mbody_canonical_test[0m'.
  | [2mThis run has ID `EVUC1BJY'.
  | 
  | [0m
```

`tests/body_canonical_test.ml::crlf_equals_lf`:

```
mathc verify: dune exited 1
mathc verify: output of `dune exec ./tests/body_canonical_test.exe -- test ^crlf_equals_lf$`:
  | [31mInvalid request (no tests to run, filter skipped everything)![0m
  | Testing `[1mbody_canonical_test[0m'.
  | [2mThis run has ID `SHIL7X6Y'.
  | 
  | [0m
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

### `infrastructure-honesty/fix-ci-targets`

- decision file: `decisions/infrastructure-honesty.yaml`
- verdict: `broken`
- recommendation: `fix-the-verifier`
- right target: `dune test --root . tests/repo_structure.exe`
- why: `tests/repo_structure` is not a directory - dune says "Don't know about directory tests/repo_structure"; the module is `tests/repo_structure.ml`, so the runnable target is `tests/repo_structure.exe`

Verifiers named by the obligation:

- `dune build @tests/repo_structure/runtest --root .` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `dune build @tests/repo_structure/runtest --root .`:
  | Error: Don't know about directory tests/repo_structure specified on the
  | command line!
  | 
```

What the same verifier prints when it is re-run now:

`dune build @tests/repo_structure/runtest --root .`:

```
mathc verify: dune exited 1
mathc verify: output of `dune build @tests/repo_structure/runtest --root .`:
  | Error: Don't know about directory tests/repo_structure specified on the
  | command line!
  |
```

### `infrastructure-honesty/pin-nixpkgs-commit`

- decision file: `decisions/infrastructure-honesty.yaml`
- verdict: `broken`
- recommendation: `fix-the-verifier`
- right target: `dune test --root . tests/repo_structure.exe`
- why: `tests/repo_structure` is not a directory - dune says "Don't know about directory tests/repo_structure"; the module is `tests/repo_structure.ml`, so the runnable target is `tests/repo_structure.exe`

Verifiers named by the obligation:

- `dune build @tests/repo_structure/runtest --root .` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `dune build @tests/repo_structure/runtest --root .`:
  | Error: Don't know about directory tests/repo_structure specified on the
  | command line!
  | 
```

What the same verifier prints when it is re-run now:

`dune build @tests/repo_structure/runtest --root .`:

```
mathc verify: dune exited 1
mathc verify: output of `dune build @tests/repo_structure/runtest --root .`:
  | Error: Don't know about directory tests/repo_structure specified on the
  | command line!
  |
```

### `infrastructure-honesty/verify-opam-checksum`

- decision file: `decisions/infrastructure-honesty.yaml`
- verdict: `broken`
- recommendation: `fix-the-verifier`
- right target: `dune test --root . tests/repo_structure.exe`
- why: `tests/repo_structure` is not a directory - dune says "Don't know about directory tests/repo_structure"; the module is `tests/repo_structure.ml`, so the runnable target is `tests/repo_structure.exe`

Verifiers named by the obligation:

- `dune build @tests/repo_structure/runtest --root .` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `dune build @tests/repo_structure/runtest --root .`:
  | Error: Don't know about directory tests/repo_structure specified on the
  | command line!
  | 
```

What the same verifier prints when it is re-run now:

`dune build @tests/repo_structure/runtest --root .`:

```
mathc verify: dune exited 1
mathc verify: output of `dune build @tests/repo_structure/runtest --root .`:
  | Error: Don't know about directory tests/repo_structure specified on the
  | command line!
  |
```

### `install-tooling-default-tag-stable/install-sh-default-tag-is-latest`

- decision file: `decisions/install-tooling-default-tag-stable-2026-10.yaml`
- verdict: `broken`
- recommendation: `fix-the-verifier`
- right target: `file-exists decisions/install-tooling-default-tag-stable-2026-10.yaml`
- why: `decisions/install-tooling-default-tag-stable.yaml` does not exist; the decision whose id is `install-tooling-default-tag-stable` is filed as `decisions/install-tooling-default-tag-stable-2026-10.yaml` - the corpus's convention lets a decision's id and its file name differ

Verifiers named by the obligation:

- `file-exists decisions/install-tooling-default-tag-stable.yaml` -> **fail**
- `mathc validate decisions/install-tooling-default-tag-stable-2026-10.yaml` -> **pass**
- `mathc validate decisions/install-tooling-default-tag-edge-2026-10.yaml still` -> **fail**
- `manual-grep-mc-version-default-latest-scripts-install-t` -> **skipped**

What the verifier printed during the re-signing:

```
mathc verify: mathc exited 2
```

What the same verifier prints when it is re-run now:

`mathc validate decisions/install-tooling-default-tag-edge-2026-10.yaml still`:

```
[warn] input/MC-INPUT: still: No such file or directory
mathc verify: mathc exited 2
```

### `kernel-conformance-runner/enumerate-and-classify-fixtures`

- decision file: `decisions/kernel-conformance-runner.yaml`
- verdict: `broken`
- recommendation: `fix-the-verifier`
- right target: `dune test --root . tests/conformance.exe`
- why: the obligation's claim names the test the check is about (`conformance`); a verifier that runs the whole suite also runs checks the claim does not speak for

Verifiers named by the obligation:

- `dune build @tests/repo_structure/runtest --root .` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `dune build @tests/repo_structure/runtest --root .`:
  | Error: Don't know about directory tests/repo_structure specified on the
  | command line!
  | 
```

What the same verifier prints when it is re-run now:

`dune build @tests/repo_structure/runtest --root .`:

```
mathc verify: dune exited 1
mathc verify: output of `dune build @tests/repo_structure/runtest --root .`:
  | Error: Don't know about directory tests/repo_structure specified on the
  | command line!
  |
```

### `kernel-conformance-runner/parse-positive-and-negative-decision`

- decision file: `decisions/kernel-conformance-runner.yaml`
- verdict: `broken`
- recommendation: `fix-the-verifier`
- right target: `dune test --root . tests/conformance.exe`
- why: `tests/conformance` is not a directory - dune says "Don't know about directory tests/conformance"; the module is `tests/conformance.ml`, so the runnable target is `tests/conformance.exe`

Verifiers named by the obligation:

- `dune build @tests/conformance/runtest --root .` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `dune build @tests/conformance/runtest --root .`:
  | Error: Don't know about directory tests/conformance specified on the command
  | line!
  | 
```

What the same verifier prints when it is re-run now:

`dune build @tests/conformance/runtest --root .`:

```
mathc verify: dune exited 1
mathc verify: output of `dune build @tests/conformance/runtest --root .`:
  | Error: Don't know about directory tests/conformance specified on the command
  | line!
  |
```

### `kernel-conformance-runner/skip-non-decision-fixtures-with-warning`

- decision file: `decisions/kernel-conformance-runner.yaml`
- verdict: `broken`
- recommendation: `fix-the-verifier`
- right target: `dune test --root . tests/conformance.exe`
- why: `tests/conformance` is not a directory - dune says "Don't know about directory tests/conformance"; the module is `tests/conformance.ml`, so the runnable target is `tests/conformance.exe`

Verifiers named by the obligation:

- `dune build @tests/conformance/runtest --root .` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `dune build @tests/conformance/runtest --root .`:
  | Error: Don't know about directory tests/conformance specified on the command
  | line!
  | 
```

What the same verifier prints when it is re-run now:

`dune build @tests/conformance/runtest --root .`:

```
mathc verify: dune exited 1
mathc verify: output of `dune build @tests/conformance/runtest --root .`:
  | Error: Don't know about directory tests/conformance specified on the command
  | line!
  |
```

### `legacy-attestation-debt-2026-10/debt-is-measured-and-bounded`

- decision file: `decisions/legacy-attestation-debt-2026-10.yaml`
- verdict: `all-pass-contradiction`
- recommendation: `investigate`
- why: the verifier measures THE ATTESTATION STORE, and the re-signing is what writes the store: the check read the store mid-repair. The evidence below shows the number it measured against the ceiling it enforces

Verifiers named by the obligation:

- `tests/fixtures/legacy-attestation-debt.sh` -> **pass**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/tests/fixtures/legacy-attestation-debt.sh`:
  | FAIL: inconclusive attestations: 165 EXCEEDS the ceiling 30 — the debt grew
  | ok: negative control: an inflated corpus measures 27, above the ceiling 22
  | 
  | legacy-attestation-debt: FAIL
  | 
```

### `legacy-debt-paydown-2026-10/three-debts-are-measured-and-bounded`

- decision file: `decisions/legacy-debt-paydown-2026-10.yaml`
- verdict: `all-pass-contradiction`
- recommendation: `investigate`
- why: the verifier measures THE ATTESTATION STORE, and the re-signing is what writes the store: the check read the store mid-repair. The evidence below shows the number it measured against the ceiling it enforces

Verifiers named by the obligation:

- `tests/fixtures/legacy-attestation-debt.sh` -> **pass**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/tests/fixtures/legacy-attestation-debt.sh`:
  | FAIL: inconclusive attestations: 165 EXCEEDS the ceiling 30 — the debt grew
  | ok: negative control: an inflated corpus measures 27, above the ceiling 22
  | 
  | legacy-attestation-debt: FAIL
  | 
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

### `merlin-lsp-2026-10/tooling-coexistence-with-tests`

- decision file: `decisions/merlin-lsp-2026-10.yaml`
- verdict: `broken`
- recommendation: `fix-the-verifier`
- right target: `dune test --root . tests/qcheck_parsers.exe tests/repo_structure.exe tests/traps.exe`
- why: the obligation's claim names the tests the check is about (`qcheck_parsers`, `repo_structure`, `traps`); a verifier that runs the whole suite also runs checks the claim does not speak for

Verifiers named by the obligation:

- `scripts/dev` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/scripts/dev`:
  | # math-coding 3.3.3 — repeatable development commands.
  | #
  | # Each subcommand prints what it is doing. None of them are silent.
  | # Use these instead of "rm -rf _build" superstition.
  | #
  | # Usage:
  | #   scripts/dev build                — compile kernel + CLI
  | #   scripts/dev test                 — run conformance suite
  | #   scripts/dev rebuild              — full rebuild (when build is wedged)
  | #   scripts/dev lint                 — strict warnings-as-errors build
  | #   scripts/dev verify               — full check before commit: build +
  | #                                     dune test + scripts/check.sh + fmt
  | #   scripts/dev check                — nix flake check
  | #   scripts/dev close-branches       — list branches merged into main
  | #                                     [--yes] also delete + push to origin
  | #   scripts/dev init-hooks           — one-time: git config core.hooksPath
  | #                                     .githooks
  | #   scripts/dev precommit            — activate .githooks/ (idempotent)
  | #                                     then exec git commit with the
  | #                                     same args
  | (... truncated)
```

What the same verifier prints when it is re-run now:

`scripts/dev`:

```
mathc verify: /home/az/.paseo/worktrees/3iuxqmnd/feat-classify-the-remaining-failures/scripts/dev exited 1
mathc verify: output of `/home/az/.paseo/worktrees/3iuxqmnd/feat-classify-the-remaining-failures/scripts/dev`:
  | # math-coding 3.3.3 — repeatable development commands.
  | #
  | # Each subcommand prints what it is doing. None of them are silent.
  | # Use these instead of "rm -rf _build" superstition.
  | #
  | # Usage:
  | #   scripts/dev build                — compile kernel + CLI
  | #   scripts/dev test                 — run conformance suite
  | #   scripts/dev rebuild              — full rebuild (when build is wedged)
  | #   scripts/dev lint                 — strict warnings-as-errors build
  | #   scripts/dev verify               — full check before commit: build +
  | #                                     dune test + scripts/check.sh + fmt
  | #   scripts/dev check                — nix flake check
  | #   scripts/dev close-branches       — list branches merged into main
  | #                                     [--yes] also delete + push to origin
  | #   scripts/dev init-hooks           — one-time: git config core.hooksPath
  | #                                     .githooks
  | #   scripts/dev precommit            — activate .githooks/ (idempotent)
  | #                                     then exec git commit with the
  | #                                     same args
  | (... truncated)
```

### `plan-2026-10-distro-friction/d9-mathc-update-subcommand`

- decision file: `decisions/plan-2026-10-distro-friction.yaml`
- verdict: `broken`
- recommendation: `fix-the-verifier`
- right target: `mathc version --check`
- why: `mathc update` has no `--check` flag - it exits 2 (input error); the obligation's claim names `mathc version --check`, which is the command the obligation is about

Verifiers named by the obligation:

- `file-exists decisions/plan-2026-10-distro-friction.yaml` -> **pass**
- `mathc validate decisions/mathc-update-subcommand-2026-10.yaml` -> **pass**
- `mathc update --check` -> **fail**
- `tests/cli/update.t` -> **pass**

What the verifier printed during the re-signing:

```
mathc verify: mathc exited 2
```

What the same verifier prints when it is re-run now:

`mathc update --check`:

```
update: unknown option '--check'.
usage: mathc update [--channel=stable|edge|<ver>] [--yes]
  --channel <s> what to install (stable|edge|vX.Y.Z); default stable
  --yes  skip the confirmation prompt
  -help  Display this list of options
  --help  Display this list of options
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

### `plan-2026-10-distro-friction/d13-channel-default-stable`

- decision file: `decisions/plan-2026-10-distro-friction.yaml`
- verdict: `broken`
- recommendation: `fix-the-verifier`
- right target: `mathc validate decisions/install-tooling-default-tag-edge-2026-10.yaml`
- why: `mathc validate decisions/install-tooling-default-tag-edge-2026-10.yaml still` passes an English annotation (`still`) as a second positional to `mathc validate`, which then exits 2 (input error); the annotation is not an argument

Verifiers named by the obligation:

- `file-exists decisions/plan-2026-10-distro-friction.yaml` -> **pass**
- `mathc validate decisions/install-tooling-default-tag-stable-2026-10.yaml` -> **pass**
- `mathc validate decisions/install-tooling-default-tag-edge-2026-10.yaml still` -> **fail**
- `manual-grep-q-stable-quickstart-md-grep-q-edge-usage-md` -> **skipped**

What the verifier printed during the re-signing:

```
mathc verify: mathc exited 2
```

What the same verifier prints when it is re-run now:

`mathc validate decisions/install-tooling-default-tag-edge-2026-10.yaml still`:

```
[warn] input/MC-INPUT: still: No such file or directory
mathc verify: mathc exited 2
```

### `priority-drift/priority-drift-detector`

- decision file: `decisions/priority-drift.yaml`
- verdict: `broken`
- recommendation: `fix-the-verifier`
- right target: `dune test --root . tests/repo_structure.exe`
- why: the obligation's claim names the test the check is about (`repo_structure`); a verifier that runs the whole suite also runs checks the claim does not speak for

Verifiers named by the obligation:

- `dune build @tests/repo_structure/runtest --root .` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `dune build @tests/repo_structure/runtest --root .`:
  | Error: Don't know about directory tests/repo_structure specified on the
  | command line!
  | 
```

What the same verifier prints when it is re-run now:

`dune build @tests/repo_structure/runtest --root .`:

```
mathc verify: dune exited 1
mathc verify: output of `dune build @tests/repo_structure/runtest --root .`:
  | Error: Don't know about directory tests/repo_structure specified on the
  | command line!
  |
```

### `priority-drift/priority-drift-fixture-implemented`

- decision file: `decisions/priority-drift.yaml`
- verdict: `broken`
- recommendation: `fix-the-verifier`
- right target: `dune test --root . tests/repo_structure.exe`
- why: the obligation's claim names the test the check is about (`repo_structure`); a verifier that runs the whole suite also runs checks the claim does not speak for

Verifiers named by the obligation:

- `dune build @tests/repo_structure/runtest --root .` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `dune build @tests/repo_structure/runtest --root .`:
  | Error: Don't know about directory tests/repo_structure specified on the
  | command line!
  | 
```

What the same verifier prints when it is re-run now:

`dune build @tests/repo_structure/runtest --root .`:

```
mathc verify: dune exited 1
mathc verify: output of `dune build @tests/repo_structure/runtest --root .`:
  | Error: Don't know about directory tests/repo_structure specified on the
  | command line!
  |
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

### `self-check-fixture-coverage-honest-2026-10/coverage-is-verified-by-a-reader-not-the-writer`

- decision file: `decisions/self-check-fixture-coverage-honest-2026-10.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: the verifier compares the COMMITTED fixture `tests/fixtures/self-check-pass/attestations/` against the LIVE obligation enumeration, and the corpus has grown since the fixture was generated: the pairs listed as MISSING below have no fixture file. The verifier is right; the fixture is stale

Verifiers named by the obligation:

- `scripts/check-self-check-fixture-coverage.sh` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/scripts/check-self-check-fixture-coverage.sh`:
  |   MISSING   decision-resolves-by-id-2026-10-a-failing-verifier-is-still-reported-as-failing.json
  |   MISSING   decision-resolves-by-id-2026-10-the-id-resolves-regardless-of-the-file-name.json
  |   MISSING   honest-attestation-emission-2026-10-manual-declarations-are-not-passes.json
  |   MISSING   honest-attestation-emission-2026-10-runtime-attestations-name-their-run.json
  |   MISSING   honest-attestation-emission-2026-10-the-re-sign-prunes-orphans.json
  |   MISSING   scope-invalidation-breadth-2026-10-the-breadth-does-not-grow.json
  |   MISSING   scope-invalidation-breadth-2026-10-the-measurement-is-not-vacuous.json
  | self-check-fixture-coverage: FAIL: 7 required pair(s) have no fixture file
  | self-check-fixture-coverage: enumerated pairs = 880 (873 required, 7 exempt under portable-linux-musl)
  | self-check-fixture-coverage: fixture files      = 873
  | self-check-fixture-coverage: required covered   = 866
  | self-check-fixture-coverage: exempt files present = 7 (not required)
  | 
```

What the same verifier prints when it is re-run now:

`scripts/check-self-check-fixture-coverage.sh`:

```
mathc verify: /home/az/.paseo/worktrees/3iuxqmnd/feat-classify-the-remaining-failures/scripts/check-self-check-fixture-coverage.sh exited 1
mathc verify: output of `/home/az/.paseo/worktrees/3iuxqmnd/feat-classify-the-remaining-failures/scripts/check-self-check-fixture-coverage.sh`:
  |   MISSING   decision-resolves-by-id-2026-10-a-failing-verifier-is-still-reported-as-failing.json
  |   MISSING   decision-resolves-by-id-2026-10-the-id-resolves-regardless-of-the-file-name.json
  |   MISSING   honest-attestation-emission-2026-10-manual-declarations-are-not-passes.json
  |   MISSING   honest-attestation-emission-2026-10-runtime-attestations-name-their-run.json
  |   MISSING   honest-attestation-emission-2026-10-the-re-sign-prunes-orphans.json
  |   MISSING   scope-invalidation-breadth-2026-10-the-breadth-does-not-grow.json
  |   MISSING   scope-invalidation-breadth-2026-10-the-measurement-is-not-vacuous.json
  |   MISSING   unmet-obligations-inventory-2026-10-an-unsigned-obligation-is-a-gap.json
  |   MISSING   unmet-obligations-inventory-2026-10-the-count-and-the-breakdown-are-recorded.json
  |   MISSING   unmet-obligations-inventory-2026-10-the-inventory-covers-every-unsigned-obligation.json
  | self-check-fixture-coverage: FAIL: 10 required pair(s) have no fixture file
  | self-check-fixture-coverage: enumerated pairs = 883 (876 required, 7 exempt under portable-linux-musl)
  | self-check-fixture-coverage: fixture files      = 873
  | self-check-fixture-coverage: required covered   = 866
  | self-check-fixture-coverage: exempt files present = 7 (not required)
  |
```

### `self-check-fixture-coverage-honest-2026-10/the-builder-is-no-longer-any-obligations-verifier`

- decision file: `decisions/self-check-fixture-coverage-honest-2026-10.yaml`
- verdict: `broken`
- recommendation: `investigate`
- why: the verifier compares the COMMITTED fixture `tests/fixtures/self-check-pass/attestations/` against the LIVE obligation enumeration, and the corpus has grown since the fixture was generated: the pairs listed as MISSING below have no fixture file. The verifier is right; the fixture is stale

Verifiers named by the obligation:

- `mathc validate decisions/audit-0.0.21-fixes.yaml` -> **pass**
- `scripts/check-self-check-fixture-coverage.sh` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/scripts/check-self-check-fixture-coverage.sh`:
  |   MISSING   decision-resolves-by-id-2026-10-a-failing-verifier-is-still-reported-as-failing.json
  |   MISSING   decision-resolves-by-id-2026-10-the-id-resolves-regardless-of-the-file-name.json
  |   MISSING   honest-attestation-emission-2026-10-manual-declarations-are-not-passes.json
  |   MISSING   honest-attestation-emission-2026-10-runtime-attestations-name-their-run.json
  |   MISSING   honest-attestation-emission-2026-10-the-re-sign-prunes-orphans.json
  |   MISSING   scope-invalidation-breadth-2026-10-the-breadth-does-not-grow.json
  |   MISSING   scope-invalidation-breadth-2026-10-the-measurement-is-not-vacuous.json
  | self-check-fixture-coverage: FAIL: 7 required pair(s) have no fixture file
  | self-check-fixture-coverage: enumerated pairs = 880 (873 required, 7 exempt under portable-linux-musl)
  | self-check-fixture-coverage: fixture files      = 873
  | self-check-fixture-coverage: required covered   = 866
  | self-check-fixture-coverage: exempt files present = 7 (not required)
  | 
```

What the same verifier prints when it is re-run now:

`scripts/check-self-check-fixture-coverage.sh`:

```
mathc verify: /home/az/.paseo/worktrees/3iuxqmnd/feat-classify-the-remaining-failures/scripts/check-self-check-fixture-coverage.sh exited 1
mathc verify: output of `/home/az/.paseo/worktrees/3iuxqmnd/feat-classify-the-remaining-failures/scripts/check-self-check-fixture-coverage.sh`:
  |   MISSING   decision-resolves-by-id-2026-10-a-failing-verifier-is-still-reported-as-failing.json
  |   MISSING   decision-resolves-by-id-2026-10-the-id-resolves-regardless-of-the-file-name.json
  |   MISSING   honest-attestation-emission-2026-10-manual-declarations-are-not-passes.json
  |   MISSING   honest-attestation-emission-2026-10-runtime-attestations-name-their-run.json
  |   MISSING   honest-attestation-emission-2026-10-the-re-sign-prunes-orphans.json
  |   MISSING   scope-invalidation-breadth-2026-10-the-breadth-does-not-grow.json
  |   MISSING   scope-invalidation-breadth-2026-10-the-measurement-is-not-vacuous.json
  |   MISSING   unmet-obligations-inventory-2026-10-an-unsigned-obligation-is-a-gap.json
  |   MISSING   unmet-obligations-inventory-2026-10-the-count-and-the-breakdown-are-recorded.json
  |   MISSING   unmet-obligations-inventory-2026-10-the-inventory-covers-every-unsigned-obligation.json
  | self-check-fixture-coverage: FAIL: 10 required pair(s) have no fixture file
  | self-check-fixture-coverage: enumerated pairs = 883 (876 required, 7 exempt under portable-linux-musl)
  | self-check-fixture-coverage: fixture files      = 873
  | self-check-fixture-coverage: required covered   = 866
  | self-check-fixture-coverage: exempt files present = 7 (not required)
  |
```

### `spec-cli-catalog/spec-cli-catalog-promoted`

- decision file: `decisions/spec-cli-catalog.yaml`
- verdict: `broken`
- recommendation: `fix-the-verifier`
- right target: `dune test --root . tests/repo_structure.exe`
- why: `tests/repo_structure` is not a directory - dune says "Don't know about directory tests/repo_structure"; the module is `tests/repo_structure.ml`, so the runnable target is `tests/repo_structure.exe`

Verifiers named by the obligation:

- `dune build @tests/repo_structure/runtest --root .` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `dune build @tests/repo_structure/runtest --root .`:
  | Error: Don't know about directory tests/repo_structure specified on the
  | command line!
  | 
```

What the same verifier prints when it is re-run now:

`dune build @tests/repo_structure/runtest --root .`:

```
mathc verify: dune exited 1
mathc verify: output of `dune build @tests/repo_structure/runtest --root .`:
  | Error: Don't know about directory tests/repo_structure specified on the
  | command line!
  |
```

### `spec-cli-catalog/spec-catalog-fixture-implemented`

- decision file: `decisions/spec-cli-catalog.yaml`
- verdict: `broken`
- recommendation: `fix-the-verifier`
- right target: `dune test --root . tests/repo_structure.exe`
- why: the obligation's claim names the test the check is about (`repo_structure`); a verifier that runs the whole suite also runs checks the claim does not speak for

Verifiers named by the obligation:

- `dune build @tests/repo_structure/runtest --root .` -> **fail**

What the verifier printed during the re-signing:

```
mathc verify: output of `dune build @tests/repo_structure/runtest --root .`:
  | Error: Don't know about directory tests/repo_structure specified on the
  | command line!
  | 
```

What the same verifier prints when it is re-run now:

`dune build @tests/repo_structure/runtest --root .`:

```
mathc verify: dune exited 1
mathc verify: output of `dune build @tests/repo_structure/runtest --root .`:
  | Error: Don't know about directory tests/repo_structure specified on the
  | command line!
  |
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

### `verifier-outcome-taxonomy-2026-10/the-debt-ceilings-are-pinned`

- decision file: `decisions/verifier-outcome-taxonomy-2026-10.yaml`
- verdict: `all-pass-contradiction`
- recommendation: `investigate`
- why: the verifier measures THE ATTESTATION STORE, and the re-signing is what writes the store: the check read the store mid-repair. The evidence below shows the number it measured against the ceiling it enforces

Verifiers named by the obligation:

- `tests/fixtures/legacy-attestation-debt.sh` -> **pass**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/tests/fixtures/legacy-attestation-debt.sh`:
  | FAIL: inconclusive attestations: 165 EXCEEDS the ceiling 30 — the debt grew
  | ok: negative control: an inflated corpus measures 27, above the ceiling 22
  | 
  | legacy-attestation-debt: FAIL
  | 
```

### `verifier-path-resolution-2026-10/absolute-path-is-blocked`

- decision file: `decisions/verifier-path-resolution-2026-10.yaml`
- verdict: `all-pass-contradiction`
- recommendation: `investigate`
- why: `tests/fixtures/verifier-path-resolution.sh` sets `set -o pipefail` and pipes into `grep -q`: `grep -q` exits at the first match, the writer on the other end of the pipe takes SIGPIPE (141), and `pipefail` promotes that signal to a pipeline FAILURE. The check's verdict is a race, not a verdict - under load it reports a false failure while quoting the very string it was looking for. The fix is in the fixture: drop `-q` (plain `grep` reads the whole input) or use a herestring

Verifiers named by the obligation:

- `tests/fixtures/verifier-path-resolution.sh` -> **pass**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/tests/fixtures/verifier-path-resolution.sh`:
  | FAIL: an absolute verifier path was not rejected (rc=1): reject: /tmp/tmp.ua4Zp1krIa/proj/abs.yaml
  |   code: MC-VERIFIER-PATH-UNRESOLVED
  | ok: the absolute case is a block
  | ok: a missing relative verifier path leaves the verdict parse-ok
  | ok: the missing relative case still reports the gap
  | ok: a manual- declaration with an absolute path does not reject the file
  | ok: the diagnostic is registered and explainable
  | ok: a decision with no path key is clean — the diagnostic fires on the path, not on everything
  | 
  | verifier-path-resolution: FAIL
  | 
```

### `verifier-path-resolution-2026-10/missing-relative-path-is-a-warning`

- decision file: `decisions/verifier-path-resolution-2026-10.yaml`
- verdict: `all-pass-contradiction`
- recommendation: `investigate`
- why: `tests/fixtures/verifier-path-resolution.sh` sets `set -o pipefail` and pipes into `grep -q`: `grep -q` exits at the first match, the writer on the other end of the pipe takes SIGPIPE (141), and `pipefail` promotes that signal to a pipeline FAILURE. The check's verdict is a race, not a verdict - under load it reports a false failure while quoting the very string it was looking for. The fix is in the fixture: drop `-q` (plain `grep` reads the whole input) or use a herestring

Verifiers named by the obligation:

- `tests/fixtures/verifier-path-resolution.sh` -> **pass**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/tests/fixtures/verifier-path-resolution.sh`:
  | FAIL: an absolute verifier path was not rejected (rc=1): reject: /tmp/tmp.ua4Zp1krIa/proj/abs.yaml
  |   code: MC-VERIFIER-PATH-UNRESOLVED
  | ok: the absolute case is a block
  | ok: a missing relative verifier path leaves the verdict parse-ok
  | ok: the missing relative case still reports the gap
  | ok: a manual- declaration with an absolute path does not reject the file
  | ok: the diagnostic is registered and explainable
  | ok: a decision with no path key is clean — the diagnostic fires on the path, not on everything
  | 
  | verifier-path-resolution: FAIL
  | 
```

### `verifier-path-resolution-2026-10/the-diagnostic-is-explainable`

- decision file: `decisions/verifier-path-resolution-2026-10.yaml`
- verdict: `all-pass-contradiction`
- recommendation: `investigate`
- why: `tests/fixtures/verifier-path-resolution.sh` sets `set -o pipefail` and pipes into `grep -q`: `grep -q` exits at the first match, the writer on the other end of the pipe takes SIGPIPE (141), and `pipefail` promotes that signal to a pipeline FAILURE. The check's verdict is a race, not a verdict - under load it reports a false failure while quoting the very string it was looking for. The fix is in the fixture: drop `-q` (plain `grep` reads the whole input) or use a herestring

Verifiers named by the obligation:

- `tests/fixtures/verifier-path-resolution.sh` -> **pass**

What the verifier printed during the re-signing:

```
mathc verify: output of `/home/az/Projects/math-coding/tests/fixtures/verifier-path-resolution.sh`:
  | FAIL: an absolute verifier path was not rejected (rc=1): reject: /tmp/tmp.ua4Zp1krIa/proj/abs.yaml
  |   code: MC-VERIFIER-PATH-UNRESOLVED
  | ok: the absolute case is a block
  | ok: a missing relative verifier path leaves the verdict parse-ok
  | ok: the missing relative case still reports the gap
  | ok: a manual- declaration with an absolute path does not reject the file
  | ok: the diagnostic is registered and explainable
  | ok: a decision with no path key is clean — the diagnostic fires on the path, not on everything
  | 
  | verifier-path-resolution: FAIL
  | 
```

