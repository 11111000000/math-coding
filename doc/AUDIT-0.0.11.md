# Foundation audit — math-coding 3.0-alpha-0.0.11

> Author: subagent on behalf of Petr Kosov <p.b.kosov@yandex.ru>
> Branch: main, HEAD 1b48db2 (tag `v3-alpha-0.0.10`)
> Date: 2026-09-27
> Status: research-only. This document does not modify any decision,
> obligation, fixture, schema, or kernel. It is a snapshot of the
> repository as it stands, intended for human review prior to tagging
> `v3-alpha-0.0.11`.
>
> Scope: foundation audit. Per `AGENTS.md` §Self-application, the
> audit verifies existing decisions; it does not create a new one. No
> new `bootstrap/*.yaml` file is added, no fixture is touched, no
> `OCAML_BEST_PRACTICES.md` rule is changed. The audit is appended to
> `doc/` and is itself protected by A3 only insofar as it is a
> reflection of the source-of-truth files (spec/, axioms/, bootstrap/,
> lib/, bin/, tests/).

This document is structured as a series of snapshots. Each section
records what is true at HEAD `1b48db2` and how that fact was
established. Evidence is declared in the evidence-source column;
assertions are not stronger than the source supports
(`AGENTS.md` §Evidence).

---

## Status

### Tag chain

The `v3-alpha-*` tag series, oldest first, from
`git tag --list | grep v3-alpha`:

| Tag | Bound to commit | What it represents |
|---|---|---|
| `v3-alpha-0.0.1` | c3630f1 | bootstrap 3.0-alpha (spec/, schemas/, axioms/, README, lib/ skeleton) |
| `v3-alpha-0.0.1-final` | a5bd186 | README links to axioms |
| `v3-alpha-0.0.2` | dcce935 | dev shell extended with test dependencies |
| `v3-alpha-0.0.3` | 1f0ec3a | AGENTS.md surfaces OCAML_BEST_PRACTICES §11 in agent workflow |
| `v3-alpha-0.0.4` | 0617b59 | wire kernel-conformance-runner (enumerate) |
| `v3-alpha-0.0.5` | 9cd19a4 | kernel-conformance-runner waiver-parser wired |
| `v3-alpha-0.0.6` | 01d5832 | `mc validate FILE` (cli-validate-decision) |
| `v3-alpha-0.0.7` | f0f80a9 | `mc context BASE HEAD --budget N` (cli-context-capsule) |
| `v3-alpha-0.0.8` | 9f6d595 | record adapters decision (junit-attestation-import) |
| `v3-alpha-0.0.9` | 95da194 | dune cram tests for mc CLI (cli-integration-cram) |
| `v3-alpha-0.0.10` | 1b48db2 | ocamlformat-fmt-clean (dune fmt + pre-commit-hooks.nix) |

Source: `git tag --list | grep v3-alpha` (declared); commit graph
matched by `git log --tags --simplify-by-decoration --pretty="%h %d"`.

### All 15 fixtures green

`./scripts/check.sh` (exit code 0; stdout captured):

```text
  ok   attestation-skip-message
  ok   ci-targets-exist
  ok   context-budget
  ok   cram-runs
  ok   decision-parses
  ok   dune-runs-conformance
  ok   enumerate
  ok   flake-lock-changes-record-decision
  ok   flake-ref-is-commit
  ok   fmt-clean
  ok   git-adapter
  ok   junit-adapter
  ok   validate-negative
  ok   validate-positive
  ok   waiver-parser

summary: 15 passed, 0 failed
```

Source: `./scripts/check.sh` (observed). Coverage:

- 4 obligations from `bootstrap/infrastructure-honesty.yaml`
  (ci-targets-exist, flake-lock-changes-record-decision,
  flake-ref-is-commit, dune-runs-conformance-via-the-runner);
- 4 obligations from `bootstrap/kernel-conformance-runner.yaml`
  (enumerate, decision-parses, attestation-skip-message,
  waiver-parser);
- 3 obligations from `bootstrap/validate-and-context.md`
  (cli-validate via validate-positive/validate-negative,
  cli-context-capsule + capsule-byte-budget-tracked via
  context-budget);
- 2 obligations from `bootstrap/adapters.md`
  (git-changed-files-adapter, junit-attestation-import);
- 1 obligation from the parent `bootstrap/decision.yaml`
  (conformance-coverage, exercised by enumerate and
  dune-runs-conformance);
- 1 fmt-clean obligation from v3-alpha-0.0.10
  (ocamlformat-fmt-clean).

15 fixtures, 15 obligations effectively exercised.

### dune build clean

`nix develop .#test --command bash -c 'dune build --root .'`
produced no warnings, no errors. Output is the nix shell banner
only; dune emits nothing on a clean build.

### dune test summary

`nix develop .#test --command bash -c 'dune test --root . --force'`:

```text
Testing `kernel conformance'.
  [OK]          fixtures          0   decision/negative-empty-obligations.jso...
  [OK]          fixtures          1   decision/negative-duplicate-outcomes.js...
  [OK]          fixtures          2   decision/positive-minimal.yaml [expects...
  [OK]          fixtures          3   decision/negative-missing-commitment.js...
  [OK]          fixtures          4   decision/positive-minimal.json [expects...
  [OK]          fixtures          5   attestation/positive-pass.json [expects...
  [OK]          fixtures          6   attestation/negative-unknown-result.jso...
  [OK]          fixtures          7   waiver/negative-missing-expiry.json [ex...
  [OK]          fixtures          8   waiver/positive-active-window.json [exp...

Test Successful in 0.000s. 9 tests run.

Testing `digest conformance'.
  [OK]          rfc6234 vectors (xfail until Digest is fixed)          0   sh...
  [OK]          rfc6234 vectors (xfail until Digest is fixed)          1   sh...
  [OK]          rfc6234 vectors (xfail until Digest is fixed)          2   sh...

Test Successful in 0.000s. 3 tests run.
```

12 tests total, all green. Note: the three `digest_vectors` cases
are marked `xfail until Digest is fixed` — they are RFC 6234
vectors that the hand-rolled SHA-256 has not been proven against
yet. The conformance runner skips them as expected; this is a
known, declared deficit (see Diagnostics below).

### CLI smoke checks

`mathc version` (exit 0):
```text
math-coding 3.0-alpha: bootstrap
```

`mathc validate fixtures/conformance/decision/positive-minimal.json`
(exit 0):
```text
accept: fixtures/conformance/decision/positive-minimal.json
  decision: redis-origin-fallback
  revision: rev:41aa92
  obligations: 1
  assumptions: 1
```

`mathc context main HEAD --budget 2000` (exit 0, head -5): the
first five non-shell-hook lines of stdout are the JSON object. The
shell hook banner is interleaved by `nix develop`; the JSON itself
starts after the blank line. Sample of the capsule:

```json
{"base":"main","change":{...},"decisions":[{...4 entries...}],
 "head":"HEAD","items":[...10 entries, priority order
 RequiredForGate > Changed > HighRisk > Unresolved > Supporting >
 Historical..."],
 "now":"2026-09-27T06:21:24Z","obligations":[],
 "omitted":[{"detail_ref":"axiom:self-application.md", ...},
            {"detail_ref":"axiom:care.md", ...}],
 "total_bytes":1888,"truncated":true}
```

The capsule emits `total_bytes` and `truncated` as required by the
obligation `capsule-byte-budget-tracked`
(`bootstrap/validate-and-context.md`).

---

## Architecture

The 3.0-alpha tree is a single OCaml project with three layers.
The kernel is the offline, pure, side-effect-free core. Adapters
are separate libraries that may use `Unix`, `Printf`, or shell
tools. The CLI is the only I/O boundary.

The kernel (`lib/`) declares one library `mathcoding_core` with
13 modules: `domain`, `canonical`, `jsonl`, `schema`, `diagnostic`,
`identifier`, `digest`, `scope`, `reference`, `codec`, `decision`,
`memory`, `capsule`. Adapters live in subdirectories: `lib/git/`
declares `mathcoding_git` with module `git_diff`; `lib/junit/`
declares `mathcoding_junit` with module `junit`. The CLI
(`bin/`) declares an executable `mathc` with module `Mathc` and
imports `mathcoding_core`, `mathcoding_junit`, `mathcoding_git`,
`str`, `unix`. `lib/dune` uses `(wrapped false)` so kernel types
(`Domain.t`, `Diagnostic.t`, `Jsonl.value`) are exposed flat —
without it, `bin/Mathc.ml` would have to write
`Mathcoding_core.Domain.Pass` everywhere (OCAML_BEST_PRACTICES
§1.2).

The adapter split follows OCAML_BEST_PRACTICES §10.1: each
adapter's `dune` lists only its own deps; the kernel `lib/dune` is
unchanged by adapter additions; adapters may pull in dependencies
the kernel cannot.

### Kernel invariants (from `spec/constitution.md` §Kernel Invariants)

The constitution lists 14 invariants. They are the gate the kernel
MUST enforce; the 3.0-alpha bootstrap has them declared but cannot
yet enforce them — that is what the bootstrap gate (`AGENTS.md`
§Bootstrap gate) names "until `mathc self-check` passes":

1. **Determinism** — equal canonical inputs and equal evaluation
   time produce equal verdicts.
2. **Referential integrity** — every relation endpoint MUST
   resolve.
3. **Type safety** — every relation MUST use an allowed source and
   target type.
4. **Identity** — `(kind, id, revision)` MUST be globally unique.
5. **Immutability** — an accepted artifact revision MUST retain
   its canonical digest.
6. **Revision DAG** — revisions MUST have parent digests and form
   a DAG.
7. **Supersession order** — `supersedes` MUST be irreflexive and
   acyclic.
8. **Evidence binding** — an attestation MUST name exact artifact
   revisions and material digests.
9. **Freshness** — a changed material digest MUST invalidate
   dependent attestations unless the method proves digest
   independence.
10. **Honest status** — missing, stale, failed, inconclusive,
    infrastructure error, waived and passed states MUST remain
    distinguishable.
11. **Waiver bounds** — a waiver MUST apply only to its named
    gap, scope, revisions, gate and validity interval.
12. **Prior authority** — a protected transition MUST be
    authorized by the previously active policy.
13. **Fixture coverage** — every kernel-enforced MUST MUST have
    at least one accepting and one rejecting conformance fixture.
14. **Exit honesty** — a blocking verdict MUST produce nonzero
    exit code.

### Axioms (from `axioms/`)

Five normative axioms, each linked from `axioms/index.md` to the
kernel properties that enforce it:

- **A0 — Separation** (`axioms/separation.md`). The seven object
  kinds (`intent`, `decision`, `obligation`, `change`,
  `attestation`, `observation`, `revision`) are pairwise distinct
  and the chain is one-way. Enforced by `Domain.kind` variants and
  per-kind schema constraints in `schemas/*.json`.
- **A1 — Feedback** (`axioms/feedback.md`). Every commitment has
  an observation path. Enforced by `Domain.result` variant
  including `Inconclusive` and `InfrastructureError` distinctly
  from `Pass`, and by the `expires_at` requirement on waivers.
- **A2 — Invariants and Recovery** (`axioms/invariants.md`).
  Every invariant is paired with an authorized recovery. Enforced
  by `Domain.gate` (`Open` / `Open_with_waiver` / `Blocked`),
  `Diagnostic.t` carrying `remedies`, and the 4 exit codes
  (`OCAML_BEST_PRACTICES.md` §4.3).
- **A3 — Self-application** (`axioms/self-application.md`).
  Rules govern themselves. Enforced by
  `bootstrap/decision.yaml` obligations `conformance-coverage`
  and `developer-practices-binding`, both of which must pass
  under current rules before the next rules take effect.
- **A4 — Care** (`axioms/care.md`). The four "who/when" fields
  are not negotiable. Enforced by required (not optional) fields:
  `decision.risk.owner`, `assumption.owner`,
  `obligation.decision`, `waiver.issuer`,
  `attestation.producer_identity`.

---

## Code metrics

Measured at HEAD `1b48db2`, files `*.ml` only (no `.mli` files
exist yet):

| Metric | Value | Source |
|---|---|---|
| Total `.ml` files | 19 | `find lib bin tests -name '*.ml' \| wc -l` |
| Total lines of OCaml | 3,606 | `find lib bin tests -name '*.ml' -exec wc -l {} +` (tail -1) |
| `.ml` files in `lib/` (kernel + adapters) | 15 | 13 in `mathcoding_core` (`lib/dune`) + 1 in `lib/git/` + 1 in `lib/junit/` |
| `.ml` files in `bin/` | 2 | `bin/Mathc.ml` (570 lines), `bin/mathc_main.ml` (1 line, stale — see Diagnostics) |
| `.ml` files in `tests/` | 2 | `tests/conformance.ml` (368), `tests/digest_vectors.ml` (67) |
| Cram test files (`tests/cram/*.t`) | 3 | `validate.t`, `assess.t`, `attest.t` |
| Modules in `mathcoding_core` | 13 | declared in `lib/dune` |
| Modules in `mathcoding_git` | 1 | `git_diff` (`lib/git/dune`) |
| Modules in `mathcoding_junit` | 1 | `junit` (`lib/junit/dune`) |
| `bootstrap/` decisions | 5 | `decision.yaml`, `infrastructure-honesty.yaml`, `kernel-conformance-runner.yaml`, `validate-and-context.md`, `adapters.md` |
| `bootstrap/` support files | 2 | `obligations.yaml`, `rationale.md` |

Per-file line counts (rounded):

| File | Lines |
|---|---|
| `lib/canonical.ml` | 57 |
| `lib/capsule.ml` | 263 |
| `lib/codec.ml` | 448 |
| `lib/decision.ml` | 297 |
| `lib/diagnostic.ml` | 86 |
| `lib/digest.ml` | 176 |
| `lib/domain.ml` | 161 |
| `lib/identifier.ml` | 64 |
| `lib/jsonl.ml` | 208 |
| `lib/memory.ml` | 294 |
| `lib/reference.ml` | 46 |
| `lib/schema.ml` | 31 |
| `lib/scope.ml` | 8 |
| `lib/git/git_diff.ml` | 79 |
| `lib/junit/junit.ml` | 382 |
| `bin/Mathc.ml` | 570 |
| `bin/mathc_main.ml` | 1 (stale) |
| `tests/conformance.ml` | 368 |
| `tests/digest_vectors.ml` | 67 |
| **Total** | **3,606** |

---

## Decisions and obligations

| `bootstrap/` file | Revision | Obligations | Verification status |
|---|---|---|---|
| `decision.yaml` | 2 | 8 (preserve-v2, conformance-coverage, bootstrap-honesty, authoring-benchmark, context-budget, developer-practices-binding, axioms-binding, …) | All **manual** today; the kernel that would auto-verify them does not exist. The bootstrap protocol explicitly names these as manual declarations (`AGENTS.md` §Bootstrap gate, `bootstrap/rationale.md`). |
| `infrastructure-honesty.yaml` | 1 | 4: fix-ci-targets, pin-nixpkgs-commit, verify-opam-checksum, wire-conformance-runner | **All 4 done** at v3-alpha-0.0.3. Fixtures: `tests/fixtures/ci-targets-exist.sh`, `tests/fixtures/flake-ref-is-commit.sh`, `tests/fixtures/flake-lock-changes-record-decision.sh`, `tests/fixtures/dune-runs-conformance.sh`. All four pass under `./scripts/check.sh`. |
| `kernel-conformance-runner.yaml` | 1 | 4: enumerate-and-classify-fixtures, parse-positive-and-negative-decision, wire-conformance-into-dune-test, skip-non-decision-fixtures-with-warning | **All 4 done** between v3-alpha-0.0.3 and v3-alpha-0.0.5. Fixtures: `enumerate.sh`, `decision-parses.sh`, `dune-runs-conformance.sh`, `attestation-skip-message.sh`, `waiver-parser.sh` (5 fixtures for 4 obligations because `skip-non-decision-fixtures-with-warning` is exercised by both attestation and waiver cases). |
| `validate-and-context.md` | 2 | 6: jsonl-array-parser-fixed, cli-validate-decision, cli-version-preserved, kernel-offline-pure-unchanged, cli-context-capsule, capsule-byte-budget-tracked | **All 6 done** at v3-alpha-0.0.6 (jsonl-array-parser-fixed, cli-validate-decision, cli-version-preserved, kernel-offline-pure-unchanged) and v3-alpha-0.0.7 (cli-context-capsule, capsule-byte-budget-tracked). Fixtures: `validate-positive.sh`, `validate-negative.sh`, `context-budget.sh`. The kernel-offline-pure-unchanged obligation is verified by the build itself (any Unix-only call in `lib/` would fail to link). |
| `adapters.md` | 1 | 2: git-changed-files-adapter, junit-attestation-import | **Both done** at v3-alpha-0.0.9. Fixtures: `tests/fixtures/git-adapter.sh`, `tests/fixtures/junit-adapter.sh`, plus cram tests `tests/cram/assess.t`, `tests/cram/attest.t`. Cram coverage is also asserted by `tests/fixtures/cram-runs.sh`. |

### `bootstrap/decision.yaml` obligations, in detail

| Obligation | Verifier | Status |
|---|---|---|
| `preserve-v2` | `mathc-tag-exists` | **Manual**: the `v2.1-final` tag is reachable; the conformance runner does not assert this. |
| `conformance-coverage` | `mathc-conformance-run` | **Manual + 9 conformance cases green** (`dune test --force` shows 9 passing; this is observed evidence, not the kernel-auto-verified form the obligation names). |
| `bootstrap-honesty` | `mathc-text-scan` | **Manual**: AGENTS.md and bootstrap documents claim no automated enforcement beyond fixtures; this is reviewed, not auto-verified. |
| `authoring-benchmark` | `mathc-benchmark` | **Manual**: no benchmark exists; documented as outstanding in the bootstrap rationale. |
| `context-budget` | `mathc-context-budget` | **Manual + `context-budget.sh` green**: the fixture asserts `total_bytes` + `truncated` are emitted; `mc context main HEAD --budget 2000` does emit them (`total_bytes`:1888, `truncated`:true observed). |
| `developer-practices-binding` | `practice-review` | **Manual**: enforced through code review and the trap log; no automated linter. `fmt-clean.sh` and the shellcheck pre-commit hook are partial automation. |
| `axioms-binding` | `axiom-link-review` | **Manual**: every change is supposed to reference at least one axiom; this is reviewed, not auto-verified. |

Per `bootstrap/rationale.md`: *"acceptance predicates refer to
verifiers that become available only as the kernel is implemented.
Until then, the predicates describe requirements, not guarantees."*

---

## Conformance status

### Conformance runner

`tests/conformance.ml` (368 lines) walks
`fixtures/conformance/{decision,attestation,waiver}/` and asserts
per-fixture verdicts. Wired into `tests/dune` as `(test (name
conformance))`. Runs as `dune test` against 9 cases:

- `decision/negative-empty-obligations.json` — expects reject, got
  rejected.
- `decision/negative-duplicate-outcomes.json` — expects reject,
  got rejected.
- `decision/positive-minimal.yaml` — expects accept, got accepted.
- `decision/negative-missing-commitment.json` — expects reject,
  got rejected.
- `decision/positive-minimal.json` — expects accept, got accepted.
- `attestation/positive-pass.json` — expects accept, got accepted.
- `attestation/negative-unknown-result.json` — expects reject, got
  rejected.
- `waiver/negative-missing-expiry.json` — expects reject, got
  rejected.
- `waiver/positive-active-window.json` — expects accept, got
  accepted.

(Source: `dune test --root . --force` output, observed at audit
time.)

The runner accepts/rejects based on `Decision.parse_decision`,
`Codec.parse_attestation`, `Codec.parse_waiver`. It does not
transitively inspect array contents (OCAML_BEST_PRACTICES §11.15
explains why the `parse_array` bug was undetected by the runner for
two years: every fixture's array fields happen to be single-element
under the keys the runner inspects, and the runner's verdict is on
`Some _ | None`, not on `length`.

### Cram tests

3 cram tests in `tests/cram/*.t`, declared in `tests/dune` as
`(cram (deps validate.t assess.t attest.t ../bin/mathc.exe))`:

- `validate.t` — invokes `mc validate` against
  `positive-minimal.json`, asserts the accept verdict.
- `assess.t` — sets up a temp git repo with two commits, invokes
  `mc assess HEAD~1 HEAD`, asserts the JSON array of changed
  paths.
- `attest.t` — writes a minimal JUnit XML to `$TMPDIR`, invokes
  `mc attest`, asserts the JSON summary keys.

(Source: `tests/dune` and `tests/cram/*.t`; observed by
`./scripts/check.sh` → `cram-runs` fixture.)

### Kernel unchanged (pure modules)

The kernel — `lib/codec.ml`, `lib/decision.ml`, `lib/diagnostic.ml`,
`lib/domain.ml`, `lib/canonical.ml`, `lib/jsonl.ml`,
`lib/identifier.ml`, `lib/digest.ml`, `lib/scope.ml`,
`lib/reference.ml`, `lib/schema.ml`, `lib/memory.ml`, `lib/capsule.ml`
— exposes no I/O. None import `Unix`, none call `exit`, none write
to a channel. (Source: visual inspection of `lib/*.ml`; corroborated
by the v3-alpha-0.0.6 obligation `kernel-offline-pure-unchanged`,
whose acceptance criterion is "the binary builds without pulling in
unix-only functions for `bin/`'s use".)

### Adapters are separate libraries

- `lib/git/` declares `mathcoding_git` as a library that depends
  only on `mathcoding_core`. `lib/git/git_diff.ml` exposes
  `changed_files : cwd:string -> base:string -> head:string ->
  (string list, string) result`; it runs `git -C cwd diff --name-only
  base..head` via `Sys.command` with stdout redirected to a temp
  file (avoids the `in_channel_length` on pipes trap, OCAML_BEST_PRACTICES
  §11.16).
- `lib/junit/` declares `mathcoding_junit` as a library that
  depends only on `mathcoding_core`. `lib/junit/junit.ml` is a
  pure module: `parse_junit : string -> t`. No new runtime
  dependency. (Source: `lib/git/dune`, `lib/git/git_diff.ml`,
  `lib/junit/dune`, `lib/junit/junit.ml`.)

This split matches `OCAML_BEST_PRACTICES.md` §10.1 ("when we add
the 12th-and-onward, split"). The 12th module triggered the split
into subdirectories.

---

## Diagnostics from subagents (since v0.0.6)

Deficits reported in the `Notes:` sections of commits since the
v0.0.5 cut. None are blocking; each is recorded for the next
release.

**Resolution status (updated 2026-09-27 at v3-alpha-0.0.14)**: D3
was closed between v0.0.11 and v0.0.12 by the
`bootstrap/priority-drift.yaml` decision and the
`tests/fixtures/spec-vs-bp-priority.sh` fixture. D1 and D2 were
also closed by `bootstrap/yaml-block-scalars.md` (rev 2) and
`tests/fixtures/yaml-block-scalars.sh`. The new D4 (CLI
subcommand catalog; recommendation §Process improvements item
13) was closed at v3-alpha-0.0.13 by `bootstrap/spec-cli-catalog.md`
and `tests/fixtures/spec-catalog-present.sh`. D7 (single
decision file covering two adapters) was closed at
v3-alpha-0.0.14 by `bootstrap/adapters.md@2`, which adds the
git-changed-files-adapter obligation as a parallel obligation
to the existing junit-attestation-import obligation (audit
remedy (b)). The original D4 (SHA-256 RFC vectors, listed as
`D4`) remains open; the two deficits share a label by
coincidence (the parent v0.0.13 task instruction labelled the
new deficit "D4" while the audit already used the slot).
D5, D6, D8 remain open; see the body of each row for the
recommended remedy.

| # | Deficit | Reported in | Root cause | Recommended remedy |
|---|---|---|---|---|
| D1 | `lib/codec.ml` does not handle YAML literal-block scalars (`\|`). `bootstrap/*.yaml` uses `\|` for commitment/intent, so obligations/assumptions/triggers counts come back as 0 from the YAML path. `decision_id` and `revision` parse correctly because `Memory.strip_yaml_frontmatter` strips `---` locally before calling `Codec.load_yaml_string`. | `f0f80a9` (v3-alpha-0.0.7 commit message, Notes). | Hand-rolled YAML loader in `lib/codec.ml:412` is intentionally narrow (only top-level mappings with scalar values, per `bootstrap/kernel-conformance-runner.yaml` assumption `minimal-yaml-subset-stable`). | Extend `Codec.load_yaml_string` to handle `\|` block scalars. Must be done in `lib/codec.ml` (kernel offline, so the loader is the right place, not in `capsule`). OCAML_BEST_PRACTICES §11.19 already documents the related front-matter trap. |
| D2 | `lib/codec.ml` does not handle `---` YAML front-matter. `bootstrap/*.yaml` and the front-matter of `bootstrap/validate-and-context.md` start with `---`. The local `Memory.strip_yaml_frontmatter` workaround is sufficient for `mc context` only. | `OCAML_BEST_PRACTICES §11.19` (trap log entry written at v3-alpha-0.0.7). | Same loader limitation as D1. | Same remedy as D1; the two extensions should land together. |
| D3 | No priority-drift detector between `spec/semantics.md` "context-prioritisation" and `OCAML_BEST_PRACTICES.md` §10.5. The two tables are required to stay in lockstep (per `bootstrap/validate-and-context.md` countercase), but a change to one is not auto-detected as a change to the other. | `f0f80a9` Notes (recorded as risk `priority-order-drift-between-spec-and-implementation` in `bootstrap/validate-and-context.md`). | No machine check exists between the two tables. | **RESOLVED at v3-alpha-0.0.12**: see `bootstrap/priority-drift.yaml` obligation `priority-drift-detector` and the fixture `tests/fixtures/spec-vs-bp-priority.sh`. The fixture is invoked by `./scripts/check.sh`; it compares the priority-ordering line in `spec/semantics.md` to the mirror in `OCAML_BEST_PRACTICES.md` §10.5 and exits 1 (with a diff) on any byte-level mismatch or on exactly-one-missing. New trap-log entry `OCAML_BEST_PRACTICES.md §11.27` documents the failure mode for future maintainers. (Original recommendation was: add a fixture that diffs the two tables; until then, code review is the only enforcement. That recommendation was implemented.)

Extended at v3-alpha-0.0.16: process-principles fixture (tests/fixtures/process-principles.sh) broadens the drift-detector idea from priority tables (one instance of D3) to a class of principle-drift bugs. The new fixture enforces five machine-checkable principles (P1, P2, P5, P6, P7) and records two non-machine-checkable principles (P3 time-box, P4 merge order) as manual-acceptance obligations in bootstrap/process-principles.md. P1 (every bootstrap file has required frontmatter + body sections), P2 (every obligation declares a present verifier), P5 (no tests/cram/*.t files; cram retired in v0.0.10), P6 (scripts/check.sh exists and is executable), P7 (fixture assertions must be structural, not self-referential).) |
| D4 | `lib/digest.ml` SHA-256 implementation has not been validated against RFC 6234 vectors. `tests/digest_vectors.ml` exists but its 3 tests are marked `xfail until Digest is fixed`. | `OCAML_BEST_PRACTICES §5` and the `xfail until Digest is fixed` label visible in `dune test` output. | Hand-rolled SHA-256 (`lib/digest.ml:1-176`); conformance corpus would skip. | Until the vectors pass, do not use `Digest.sha256_hex` for canonicalization. `OCAML_BEST_PRACTICES §10.4` item 1 lists this as the top-priority pre-3.0-beta task. |
| D5 | `bin/mathc_main.ml` is a 1-line stale file containing the v0.0.5 hello-string. `bin/dune` lists only `Mathc`, so `mathc_main.ml` is not compiled, but it lingers in the tree. | `OCAML_BEST_PRACTICES §9.4` and §10.4 item 7 (recorded at v3-alpha-0.0.6). | History: `main.ml → mathc.ml → Mathc.ml`. | Delete `bin/mathc_main.ml`. Trivial cleanup; not blocking. |
| D6 | The 8 obligations in `bootstrap/decision.yaml` have manual-only verifiers. The kernel that would auto-verify them does not exist. | `bootstrap/decision.yaml` and `bootstrap/rationale.md`. | This is the bootstrap protocol itself, not a bug. | Track; expire when the released 3.0 kernel successfully checks this repository and its conformance corpus (`AGENTS.md` §Bootstrap gate). |
| D7 | `bootstrap/adapters.md` does not yet record a `git-changed-files-adapter` obligation as its own decision entry. The obligation appears in the v0.0.8 commit message and in `bootstrap/validate-and-context.md`'s `scope.capabilities`, but the adapters decision file groups it under the JUnit obligation. | `9f6d595` (the v0.0.8 commit added `bootstrap/adapters.md`; the message body is essentially empty; only `bcce74d` and `5486c13` carry the per-obligation text). | The two adapters landed in a single decision file but two implementation commits. | **RESOLVED at v3-alpha-0.0.14**: see `bootstrap/adapters.md@2`, which adds the `git-changed-files-adapter` obligation as a parallel obligation alongside the existing `junit-attestation-import` obligation (the audit's remedy (b)). The new obligation is anchored to the existing fixture `tests/fixtures/git-adapter.sh`, which is invoked by `./scripts/check.sh` and asserts that `mc assess BASE HEAD` exits 0 and emits a JSON array containing the expected file paths. The decision file also adds the corresponding `git-changed-files-adapter` outcome, capability, and scope.paths entries (`lib/git/git_diff.ml`, `lib/git/dune`, `tests/fixtures/git-adapter.sh`), and updates `relations.addresses` to include this audit. No new dependency, no fixture changes, no kernel changes. `./scripts/check.sh` remains at 26 passes (no new failures). (Original recommendation was: either split into two decision files or leave as-is and document that one file covers two obligations. The (b) branch of that recommendation was implemented.) |
| D8 | `mc validate` synthesises a single coarse diagnostic ("missing or invalid required field") without naming the specific field. The kernel's `Decision.parse_decision` returns `Some _ \| None`, not a typed `Diagnostic.t option`. | `bootstrap/validate-and-context.md` assumption `parse-decision-rejection-reason-coarse`. | Decision parser is binary accept/reject; finer diagnostics are a 3.0-beta item. | Promote `Decision.parse_decision` to return `Diagnostic.t option` in 3.0-beta; until then, the coarse diagnostic is documented. |
| D4′ | **NEW D4 (parent task label; renamed `D4′` here to disambiguate from the SHA-256 deficit above).** The mathc CLI subcommand list (version, validate, context, assess, attest, gate, session-start, record, stats, time-estimate) was documented only in `bin/Mathc.ml`'s header comment; the spec named only the priority order and exit codes. The audit's §Process improvements item 13 named this gap. | `doc/AUDIT-0.0.11.md` §Process improvements item 13. | The spec describes kernel semantics; the CLI surface was an implementation summary. | **RESOLVED at v3-alpha-0.0.13**: see `bootstrap/spec-cli-catalog.md` obligation `spec-cli-catalog-promoted` (this is the new decision file) and the fixture `tests/fixtures/spec-catalog-present.sh`. The new `spec/semantics.md` "CLI subcommands" section enumerates every subcommand bin/Mathc.ml implements at HEAD with synopsis, input, output, exit code, and the bootstrap obligation that justifies each. The fixture is invoked by `./scripts/check.sh` and exits 1 with the missing-name list on any absent canonical subcommand. `bin/Mathc.ml` is unchanged. (Original recommendation was: a spec section listing `mc validate`, `mc context`, `mc assess`, `mc attest`. That recommendation was implemented, and extended to the full ten-subcommand surface.) |

The parent task instruction also listed three deficits to ensure
are covered:

- **YAML `\|` block scalars in `lib/codec.ml`** → D1.
- **Priority drift detector missing** → D3.
- **Git obligation in `bootstrap/adapters.md`** → D7.

All three are present above. (The "git obligation in
`bootstrap/adapters.md`" phrasing in the parent task description
maps to D7: the Git adapter obligation exists in the decision but
is grouped under the JUnit decision file rather than its own
file. There is no missing obligation; the situation is a
documentation gap, not a policy deficit.)

**Closure status of the parent task's three items (updated
2026-09-27 at v3-alpha-0.0.14)**:

- D1 — **closed** at v3-alpha-0.0.12 by
  `bootstrap/yaml-block-scalars.md` (rev 2) and
  `tests/fixtures/yaml-block-scalars.sh`.
- D3 — **closed** at v3-alpha-0.0.12 by
  `bootstrap/priority-drift.yaml` (rev 2) and
  `tests/fixtures/spec-vs-bp-priority.sh` (this commit's
  work).
- D7 — **closed** at v3-alpha-0.0.14 by
  `bootstrap/adapters.md@2`, which adds the
  `git-changed-files-adapter` obligation as a parallel
  obligation alongside `junit-attestation-import`. The audit's
  remedy (b) was implemented: a single decision file covers
  both obligations, and the audit now records that fact.

**Closure status of the v0.0.13 CLI subcommand task (updated
2026-09-27 at v3-alpha-0.0.13)**:

- D4 (CLI subcommand catalog; the parent task's "D4",
  labelled `D4′` in the diagnostics table to disambiguate from
  the SHA-256 D4) — **closed** at v3-alpha-0.0.13 by
  `bootstrap/spec-cli-catalog.md` and
  `tests/fixtures/spec-catalog-present.sh`. The new
  `spec/semantics.md` "CLI subcommands" section enumerates the
  full ten-subcommand surface.

---

## Gaps vs OCAML_BEST_PRACTICES §10.4

`OCAML_BEST_PRACTICES.md` §10.4 lists 10 items the project
should write next, prioritized. Status at HEAD `1b48db2`:

| # | §10.4 item | Status | Why deferred |
|---|---|---|---|
| 1 | `tests/digest_vectors.ml` gates SHA-256 against RFC vectors | **Stubbed, xfail.** File exists (`tests/digest_vectors.ml`, 67 lines); 3 RFC 6234 cases run but are marked `xfail until Digest is fixed`. The kernel does not yet use SHA-256 for canonicalization, so the deficit is contained. | Cannot fix without resolving D4; the hand-rolled SHA-256 is plausible but unvalidated. Recommend gating any canonicalization on vector-passing. |
| 2 | `tests/decision_fixtures.ml` walks `fixtures/conformance/decision/` | **Done as `tests/conformance.ml`** with a broader scope (all three conformance kinds, not just decision). | The §10.4 item names decision only; the project unified it. |
| 3 | Rename `Diagnostic.class_` → `Diagnostic.kind` | **Done.** `lib/diagnostic.ml` uses `kind` (concrete variant); `string_of_kind` and `kind_of_string` are the accessors. | — |
| 4 | Refactor `parse_acceptance` into `parse_verifier` + `parse_review` + `parse_acceptance_item` + `parse_acceptance`; delete `to_acceptance` | **Not done.** `lib/decision.ml:79-119` still has the triple-tuple match and `to_acceptance` polymorphic-variant wrapper. | Behavior-preserving refactor; deferred until v0.0.12 or v0.0.13. |
| 5 | Add `lib/codec.ml` with `parse_result`, `parse_kind`, `parse_phase`, `parse_assumption_state`, `parse_action`, `parse_match`; remove from `decision.ml` | **Partially done.** `lib/codec.ml` exists (448 lines) with `parse_attestation`, `parse_waiver`, `load_yaml_string`. The variant parsers are still in `decision.ml`. | Same deferral as item 4. |
| 6 | Fix `flake.nix:40` to also build `@tests/runtest` | **Done.** `flake.nix:128` (in `checks.default.buildPhase`) now runs `dune build --root . @tests/runtest`. The `packages.default` build still produces only `bin/mathc.exe`. | — |
| 7 | Delete `bin/mathc_main.ml`; confirm `bin/dune` says `(name mathc)` with `(modules Mathc)` | **Half-done.** `bin/dune:3` says `(modules Mathc)` (correct). `bin/mathc_main.ml` is still on disk. | Stale file; trivial cleanup. |
| 8 | Phantom-typed IDs in `lib/identifier.ml` | **Not done.** All ids remain `type id = string` (`lib/domain.ml:2`). | Field names stabilize in 3.0-beta; defer until then. |
| 9 | Polymorphic variants → concrete variants in `lib/domain.ml` | **Not done.** `phase`, `kind`, `state`, `action`, `match_`, etc. are still polymorphic variants. | Touches every consumer; defer until 3.0-beta. |
| 10 | Move 11 modules under `lib/kernel/` when the first adapter lands | **Done.** `lib/git/` and `lib/junit/` are subdirectories with their own `dune` files; the kernel modules remain flat under `lib/`. The split is partial (kernel is flat, adapters are split), but the §10.1 rule is satisfied ("split when we add the 12th-and-onward"). | — |

### Additional deferred items (not in §10.4)

| Item | Why deferred |
|---|---|
| `qcheck` property tests | Need a stable, post-3.0-beta kernel to define invariants against. Defer to 3.0-beta. |
| `.mli` files + `odoc` | The spec documents the API; modules are short. Add `.mli` per module as each stabilizes, then `odoc`. Defer to 0.0.12 or 0.0.13. |
| `bisect_ppx` coverage | Coverage of the kernel is well-exercised by the 9 conformance cases; coverage of adapters will be useful when the MCP adapter lands. Defer until then. |
| `ppx_expect` snapshot tests | Useful for the `mc context` capsule output and the JUnit JSON rendering. Defer to 0.0.12. |
| `core_bench` benchmarks | No performance budget yet. Defer. |
| MCP server (`lib/mcp/server.ml`) | Adapter split is ready (`OCAML_BEST_PRACTICES §10.1`); the obligation is not yet recorded. Candidate for v0.0.12 (a separate decision under `bootstrap/`). |

---

## Trap log summary

`OCAML_BEST_PRACTICES.md` §11 contains **21 trap-log entries**:
§11.1, §11.2, §11.3, §11.4, §11.5, §11.6, §11.7, §11.8, §11.9,
§11.10, §11.11, §11.12, §11.13, §11.14, §11.15, §11.16, §11.17,
§11.18, §11.19, §11.20, §11.21.

(Source: `grep -cE '^### 11\.' OCAML_BEST_PRACTICES.md` = 21.)

Note: §11.12 appears between §11.11 and §11.13 in the file; the
section numbering is not strictly monotonic. The header listing
above preserves source order.

### Most recent 5 entries (one-line summaries)

1. **§11.21** — `dune fmt` exits 0 even when files would be
   reformatted. Fix: `DUNE_DISABLE_PROMOTION=1 dune fmt --root .
   --preview` (scripts/fmt-check.sh).
2. **§11.20** — Dune 3.23 cram tests cannot reach binaries via
   relative paths. Fix: anchor on `$INSIDE_DUNE/bin/mathc.exe`
   and declare `(deps ../bin/mathc.exe)` in the cram stanza.
3. **§11.19** — `lib/codec.ml`'s YAML loader does not handle
   `---` front-matter. Fix (capsule-side): `Memory.strip_yaml_frontmatter`;
   proper fix is to extend the loader.
4. **§11.18** — Structurally identical record types unify under
   inference (`Memory.spec_doc` vs `Memory.axiom_doc`). Fix:
   annotate at construction and consumption sites.
5. **§11.17** — `Arg.parse` calls `anonfun` once per positional,
   overwriting refs. Fix: collect positionals into a list, then
   pattern-match.

(§11.16, §11.15, §11.14, §11.13, §11.12 are also recent and
relevant; see `OCAML_BEST_PRACTICES.md` §11.15 for the
parse_array-loss trap that `jsonl-array-parser-fixed` closed.)

---

## Recommendations for v0.0.12+

The following is a research-only recommendation list. Each item
names the deficit it addresses, the proposed obligation or scope,
and any preconditions.

### Bug fixes (carryover from v0.0.11)

1. **YAML `\|` block scalars** (D1, D2). Extend
   `lib/codec.ml`'s `load_yaml_string` to handle `|` and `>`
   block scalars. This is a kernel change; per A3, requires a
   decision, positive+negative fixtures, migration path, and
   authorization by the current policy. The current policy is
   `bootstrap/decision.yaml@2`; a new revision `bootstrap/decision.yaml@3`
   would authorize the kernel change. Add a new decision file
   `bootstrap/yaml-block-scalars.md` recording the obligation.
2. **`bin/mathc_main.ml`** (D5). Delete the file. One-line edit.
   No bootstrap change needed (no behavior change).
3. **Priority drift detector** (D3). Add
   `tests/fixtures/spec-vs-bp-priority.sh` that diffs the two
   tables and fails on mismatch. The fixture would be a
   v0.0.12 addition under a new
   `bootstrap/spec-lockstep.md` decision.

### Refactors (carryover from §10.4)

4. **`parse_acceptance` split** (§10.4 item 4). Move into
   `lib/codec.ml` as `parse_verifier`, `parse_review`,
   `parse_acceptance_item`, `parse_acceptance`. Delete
   `to_acceptance`. Behavior-preserving — needs characterization
   fixtures before the refactor, which is what the existing
   9 conformance cases provide.
5. **Variant parsers into `lib/codec.ml`** (§10.4 item 5).
   Companion to item 4: move `parse_result`, `parse_kind`,
   `parse_phase`, `parse_assumption_state`, `parse_action`,
   `parse_match` from `lib/decision.ml` to `lib/codec.ml`.
6. **Decision parser returns `Diagnostic.t option`** (D8).
   Promote `Decision.parse_decision` from `Some _ | None` to
   `Diagnostic.t option` so negative fixtures can assert
   specific reasons. Requires bootstrap authorization.

### New obligations

7. **MCP server adapter**. Record in
   `bootstrap/adapters-mcp.md`; defer implementation to v0.0.13.
   The split convention is ready (`lib/mcp/` not yet present).
8. **`.mli` files + `odoc`** (§10.4 item 8 deferred). Add
   `lib/digest.mli`, `lib/jsonl.mli`, `lib/decision.mli`, etc.,
   one module at a time as each stabilizes. Add a
   `scripts/dev odoc` subcommand that runs `dune build @doc`.
9. **`ppx_expect` snapshot tests** for `mc context` capsule
   output and `mc attest` JSON rendering. Once `ppx_expect` is
   added to dev-deps, the snapshot corpus becomes a regression
   check on the priority order and the JUnit JSON shape.
10. **`bisect_ppx` coverage** on `lib/git/` and `lib/junit/`.
    Add to dev-deps; wire into a `scripts/dev coverage`
    subcommand. Useful before the MCP adapter lands.

### Process improvements

11. **Promote `scripts/check.sh` to the CI default.** Currently
    GitHub Actions runs `dune test` directly (`.github/workflows/ci.yml`).
    `scripts/check.sh` exercises both dune tests and the
    shell fixtures; making it the default in CI would catch
    regressions in either layer.
12. **Document the trap-log numbering quirk** (§11.12 vs
    §11.11/§11.13). The trap log is the first place anyone
    debugging an OCaml error should look. The non-monotonic
    numbering between §11.11 and §11.13 is a small wart; a
    one-line note at the top of §11 would prevent confusion.
13. **Spec change: list `mc validate`, `mc context`, `mc assess`,
    `mc attest` in `spec/semantics.md`.** Today only the
    priority order and exit codes are in the spec; the actual
    subcommands are documented only in `bin/Mathc.ml`'s header
    comment. A spec section would close the gap.

### Items explicitly NOT recommended

- Adding `yojson` to the kernel. The kernel stays offline
  (OCAML_BEST_PRACTICES §7.3). The hand-rolled parser in
  `lib/jsonl.ml` is sufficient and battle-tested through the 9
  conformance cases.
- Adopting cmdliner. `cmdliner` is in `devShells.test` only;
  using it would break `nix build` (the production closure
  that produces `bin/mathc.exe` does not include it). Stdlib
  `Arg` is sufficient for the four-subcommand CLI.
- Cutting the v2.1-final branch. The bootstrap protocol requires
  the tag to remain reachable (`bootstrap/decision.yaml`
  obligation `preserve-v2`).

---

## Provenance and evidence hierarchy

Per `AGENTS.md` §Evidence:

- **Declared** — facts recorded in this document. (Most facts
  here.)
- **Derived** — facts computed from the source tree at audit
  time. (Code metrics, line counts, file counts, tag chain.)
- **Attested** — facts witnessed by a passing test or fixture.
  (All 15 fixture passes; 12 dune tests passing; CLI smoke
  outputs.)
- **Observed** — facts obtained by direct execution. (The
  captured outputs of `./scripts/check.sh`, `dune build`,
  `dune test`, `mathc version`, `mathc validate`, `mathc
  context`.)
- **Reviewed** — not applicable to a research-only audit.

The audit makes no claim stronger than the source supports. In
particular, "the kernel is offline and pure" is a derived +
attested claim (visual inspection + the obligation
`kernel-offline-pure-unchanged` whose acceptance is "the binary
builds cleanly without pulling in unix-only functions for
`bin/`'s use"). "All 15 fixtures green" is observed.
"Conformance corpus covers 9 cases" is observed.

The audit does not claim:

- That the kernel is correct (A1 forbids it: "Math-coding must
  not present structural validity as proof of software
  correctness").
- That the obligations in `bootstrap/decision.yaml` are
  satisfied by anything more than a manual declaration
  (`bootstrap/rationale.md`).
- That the trap log is complete.
- That the recommendations in §Recommendations are urgent or
  authorized; each is a research proposal for human review.