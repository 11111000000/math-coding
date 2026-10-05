# Audit — math-coding 3.0.21 (kernel-self-consistency cycle)

> Author: agent on behalf of Petr Kosov &lt;p.b.kosov@yandex.ru&gt;
> Branch: `integrity-fixes-v0-cycle` (worktree)
> Date: 2026-10-05
> Status: pre-fix audit. The fixes themselves are tracked in
> `decisions/audit-0.0.21-fixes.yaml` (master decision adopted in
> this cycle).
> Head of audit: `d10732d docs: update self-check and migration
> snapshots to current counts` (origin/main + 9 unpushed).

This audit is a gap inventory at the boundary between docs,
kernel, schema, parser, fixtures, attestations, and the
`mc self-check` blocking gate. It enumerates 13 specific
defects (D21.1 … D21.13) and routes each to a single owner
phase in the cycle plan (Phases 0–5 in this audit's
sister document).

## Method

For each finding: the gap statement, where it surfaces,
what each side claims, what actually happens, and the
defect ID assigned by this audit. The audit does not fix
anything — it only reports. Fixes live in `decisions/audit-0.0.21-fixes.yaml`
and the subsequent commits on the `integrity-fixes-v0-cycle`
branch.

The empirical evidence for every claim below is reproducible
in two commands:

```bash
# Reproduces D21.1, D21.5, D21.6, D21.9, D21.10
mc packages --format=json | jq '.counts'
mc self-check | jq '.verdict, (.subjects | length)'

# Reproduces D21.2, D21.3, D21.4
mc validate decisions/decision.yaml
mc validate fixtures/conformance/decision/positive-minimal.json
mc re-evaluate bootstrap-v3 A1
```

## Summary

| ID | One-line | Severity | Phase |
|---|---|---|---|
| D21.1 | `mc self-check` returns `unknown` on clean HEAD, not `pass` | **blocking** | 2 |
| D21.2 | `mc validate` rejects every YAML decision in the repo (32/32) | **blocking** | 1 |
| D21.3 | Two incompatible decision models (strict schema-driven vs line-based) | structural | 1 |
| D21.4 | `mc re-evaluate` cannot load any decision (returns "unknown DECISION_ID" for all) | **blocking** | 1 |
| D21.5 | `tests/cli/self-check-pass.t` snapshot expects `verdict:"unknown"` despite preamble claiming `pass` | documentation lie | 2 |
| D21.6 | PACKAGES.md/ROADMAP.md/AUDIT-0.0.20.md quote `28 active decisions / 94 attestations`; actual `29 / 105` | drift | 3 |
| D21.7 | PACKAGES.md main table omits 5 active decisions | drift | 3 |
| D21.8 | PACKAGES.md cram table omits 4 cram fixtures | drift | 3 |
| D21.9 | README.md CLI table lists 13 subcommands; kernel implements 17 | drift | 3 |
| D21.10 | Obligation-count breakdown in PACKAGES.md (`72+7+0=79`) does not match `mc packages` (`103`) | drift | 3 |
| D21.11 | `lib/memory.ml:load_decisions` hardcodes 4 files (contradicts ROADMAP P1) | structural | 4 |
| D21.12 | `spec/constitution.md:149` contains `MUST MUST` typo | typo | 4 |
| D21.13 | `git config core.hooksPath` is empty; pre-commit hook is not registered | process | 4 |

## D21.1 — `mc self-check` is `unknown` on clean HEAD

**Gap.** AGENTS.md:6 states the bootstrap gate has expired
because "the released 3.0 kernel successfully checks this
repository and its conformance corpus". The kernel is the
blocking CI step (per `constitution.md` Invariant 14).

**Where it surfaces.**

- `AGENTS.md:6` — "the released 3.0 kernel successfully checks this repository"
- `ROADMAP.md:79` — "verdict `pass` (28/28 subjects green)"
- `doc/AUDIT-0.0.20.md:44` — "subjects_count=28, pass_count=28"
- `tests/cli/self-check-pass.t:2-3` — preamble claims verdict `"pass"` and exit `0`

**What actually happens.** Running `mc self-check` returns
`verdict:"unknown"`, exit `3`. Two store configurations:

- Live store (`attestations/`): 31 subjects, 30 pass,
  1 unknown (`portable-linux-musl`).
- Test fixture (`tests/fixtures/self-check-pass/attestations/`):
  31 subjects, 29 pass, 2 unknown (`site-deploy` and
  `portable-linux-musl`).

The fixture store is missing `site-deploy-extended-markdown-subset.json`
(present in the live store). `portable-linux-musl` is missing
attestations for all 7 of its obligations because the decision
reverted to `state: retired` after the Alpine CI build failed
(`decisions/portable-linux-musl.yaml:20`).

**Consequence.** The bootstrap-gate expiry clause is
unfulfilled. Every subsequent claim that "verdicts are
automated guarantees, not manual declarations"
(`AGENTS.md:6`, `doc/AUDIT-0.0.20.md:53-58`) is unfounded.

**Counterexample.** "The test fixture is just a sandbox; CI
runs against the live store." Response: the live store at
`attestations/` also does not cover `site-deploy/extended-markdown-subset`,
and CI runs have been observed to fail at the
`Init opam (Alpine musl container)` step per the commit log
of `release.yml`. Live store = same broken state.

## D21.2 — `mc validate` rejects every YAML decision

**Gap.** The kernel's strict validator (`Decision.parse_decision`
in `lib/decision.ml`) is the gate for `mc validate`. Every file
under `decisions/*.yaml` should pass it. None do.

**Where it surfaces.** `mc validate decisions/<file>.yaml`
for any of the 32 files. Each returns reject and the diagnostic
`MC-DECISION-INVALID / "missing or invalid required field"`.

**What actually happens.** `Decision.parse_decision` reads
the JSON-shape form (`intent` as `{source, text}` object;
`schema: math-coding/3.0-alpha/decision`; `kind: decision`;
`scope` as array of `{kind, path|capability}` objects). The
actual YAML decisions in `decisions/*.yaml` use a different
shape: `intent` as a scalar; `schema: math-coding/3.0-alpha`
(without `/decision` suffix); no `kind` field; `scope` as an
object with a `paths` list.

The parser silently returns `None` for these. The validator
emits the coarse diagnostic "missing or invalid required field"
(D8 from `doc/AUDIT-0.0.11.md:465` — already known).

**Consequence.** The kernel has two incompatible models of
what a decision is:

1. The strict schema-driven model used by `mc validate`
   (accepts only the JSON shape used by conformance fixtures).
2. The line-based model used by `mc self-check`, `mc packages`,
   `mc gate` (extracts id and obligations via line regex
   in `bin/Mathc.ml:1958-2080` and `lib/memory.ml:134`).

The first model never sees the project's own decisions.
The second model never uses the schema. They disagree.

**Counterexample.** "The YAML form is deprecated; users
should write JSON." Production code, fixtures, schema docs,
and migration scripts all assume the YAML form. Migrating
29 active decisions to JSON would break every downstream
consumer (`mc self-check`, `mc packages`, `mc gate`,
`mc context`, `mc explain`) and require a kernel rewrite.

## D21.3 — Two incompatible decision models

See D21.2 for the description. The fix is unification:
the schema accepts the YAML form; the parser parses the
YAML form; both yield the same domain value.

## D21.4 — `mc re-evaluate` cannot load any decision

**Gap.** `mc re-evaluate DECISION_ID AXIOM_ID` is a 3.2-ideal
subcommand implementing `lib/re_evaluation.ml`'s `re_evaluate`
oracle (algebra-3.2 §17).

**Where it surfaces.** Any invocation:

```
$ mc re-evaluate bootstrap-v3 A1
mc re-evaluate: unknown DECISION_ID bootstrap-v3
```

The error fires for **every** decision ID, including the
master policy `bootstrap-v3`.

**What actually happens.** `bin/Mathc.ml:1744` calls
`Re_evaluation.load_decisions ~reader ~root:repo_root`,
which calls `Decision.parse_decision` (the strict parser
from D21.2). Since `Decision.parse_decision` returns `None`
for every YAML decision, `load_decisions` returns `[]`.
`List.find_opt` then fails on every input.

**Consequence.** Algebra 3.2 §17 oracle is non-functional.
The subcommand exists and is documented in
`spec/semantics.md`, `README.md`, and `tests/cli/re-evaluate.t`,
yet cannot perform its core function.

The negative-path cram fixture `tests/cli/re-evaluate.t`
documents this as "a pre-existing parser bug" and ships
only rejection paths.

## D21.5 — `self-check-pass.t` snapshot contradicts preamble

**Gap.** The cram fixture `tests/cli/self-check-pass.t`
is named `*-pass` and its preamble claims it tests the
pass path. The snapshot in the file expects `verdict:"unknown"`.

**Where it surfaces.** `tests/cli/self-check-pass.t:2-4`
preamble vs. `:17` snapshot.

**What actually happens.** The snapshot reads:
`{"verdict":"unknown","pass_count":29,"fail_count":0,
"unknown_count":2,"subjects_len":31,...}`. Running `mc
self-check` against the same fixture reproduces this.

**History.** Commit `2e0cb95` (2026-09-29) authored the
test with `verdict:"pass"` and 22 subjects. Commit
`a1bf4f5` (2026-10-05) silently changed the snapshot to
`unknown` without renaming the file or rewriting the
preamble. Subsequent commits `445400a`, `d10732d` only
adjusted the count fields.

**Consequence.** The test name, its preamble, its snapshot
disagree. The test passes (because cram matches the actual
output against the snapshot), but it tests the wrong thing
for a reader who trusts the name.

## D21.6 — Documentation counters drift from reality

**Gap.** Three authoritative docs quote numbers that do not
match the kernel.

| Source | Claimed | Actual | Δ |
|---|---|---|---|
| `PACKAGES.md:11` | `attestations/ contains 94 files` | `105` | +11 |
| `PACKAGES.md:14` | `mc packages reports 28 active decisions` | `29` | +1 |
| `PACKAGES.md:19` | `mc self-check … subjects_count=28` | `31` | +3 |
| `ROADMAP.md:7` | `attestations/ is populated (94 files)` | `105` | +11 |
| `ROADMAP.md:79` | `mc self-check verdict: pass (28/28)` | `29 pass + 2 unknown (31 total)` | mixed |
| `ROADMAP.md:178` | `tests/cli/*.t (15 files at HEAD)` | `32` | +17 |
| `doc/AUDIT-0.0.20.md:44-45` | `subjects_count=28, pass_count=28` | `31, 29` | +3 |
| `doc/AUDIT-0.0.20.md:47` | `attestations/ contains 94 files` | `105` | +11 |
| `doc/AUDIT-0.0.20.md:66` | `28/94 attestations resolve` | `29/103` | both off |

**Cause.** The numbers were correct at `v3.0.0.20` (commit
`8fa7fcf`). Subsequent decisions (R5 `ci-blocking-list-config`,
R6 `3-2-cli-catalog`, R7 `gate-attestation-store-fill`) and
retirement of `portable-linux-musl` changed the counts.
The README / ROADMAP / PACKAGES / AUDIT synchronisation was
not performed atomically with each decision.

**Consequence.** Every reader who tries to verify the
project's status from the docs gets a different number than
the kernel reports. The bootstrap-expiry claim collapses
in the presence of drift.

## D21.7 — PACKAGES.md main table omits 5 active decisions

**Gap.** PACKAGES.md table at lines 50-79 enumerates 25
decision files. Five are missing:

- `decisions/3-2-cli-catalog.yaml`
- `decisions/algebra-3.2.yaml`
- `decisions/ci-blocking-list-config.yaml`
- `decisions/gate-attestation-store-fill-decision.yaml` (the
  table lists its id `gate-attestation-store-fill` but uses
  no path field — `PACKAGES.md:60`)
- `decisions/process-principles-close-branches.yaml`

**Consequence.** A reader cannot trust PACKAGES.md as the
"single source of truth for what exists in math-coding 3.0"
(`PACKAGES.md:2-3`). The table is a partial view.

## D21.8 — PACKAGES.md cram table omits 4 cram fixtures

**Gap.** PACKAGES.md cram table at lines 101-130 lists 28
cram tests. Four exist on disk but are missing from the table:

- `tests/cli/gate-empty.t`
- `tests/cli/mode.t`
- `tests/cli/rebuttals.t`
- `tests/cli/re-evaluate.t`

**Consequence.** PACKAGES.md is silent on obligations owned
by `3-2-cli-catalog@1` (the decision file specifically
anchored on `mode-subcommand-spec-row`,
`rebuttals-subcommand-spec-row`, and
`re-evaluate-subcommand-spec-row`).

## D21.9 — README.md CLI table lists 13 subcommands; kernel has 17

**Gap.** `README.md` lines 13-25 list 13 subcommands in the
CLI table. The kernel dispatcher at `bin/Mathc.ml:2474-2495`
matches 17 subcommands. Missing from README:

- `version`
- `session-start`
- `record`
- `stats`

`version` is in `spec/semantics.md` (so the spec is fine).
`session-start`, `record`, `stats` are also in
`spec/semantics.md` but not in README.md.

**Consequence.** A new agent reading README.md does not learn
about four of the seventeen subcommands. Violates
`spec/semantics.md:152-153` ("implementation MUST NOT add a
new subcommand without first adding a row here").

## D21.10 — PACKAGES.md obligation breakdown disagrees with kernel

**Gap.** PACKAGES.md:14-18 says:
```
mc packages reports 28 active decisions / 79 obligations
(72 original + 7 from algebra-3.2 + 0 from portable-linux-musl)
```

`mc packages --format=json` reports:
```
{ total: 103, pass: 96, missing: 7 }
```

The breakdown `72 + 7 + 0 = 79` does not sum to `103`. The
arithmetic is wrong by `24`.

**Cause.** PACKAGES.md was last updated when `mc packages`
reported `79` obligations (rev 2 of `obligation-count-reconcile`,
commit `93e765a`). Since then, five additional decisions
landed (`3-2-cli-catalog`, `ci-blocking-list-config`,
`obligation-count-reconcile` itself bumping from rev 1 to 2,
`process-principles-close-branches`, and a revert-then-add of
`gate-attestation-store-fill`); none of them were counted in
the breakdown.

**Consequence.** The PACKAGES.md Obs column sum (151) does not
match the prose claim (79). Both are wrong relative to the
kernel (103). Three different counts for the same fact.

## D21.11 — `lib/memory.ml:load_decisions` hardcodes 4 paths

**Gap.** `lib/memory.ml:188-195` enumerates four specific
decision files:

```ocaml
let paths = [
  Filename.concat root "decisions/decision.yaml";
  Filename.concat root "decisions/infrastructure-honesty.yaml";
  Filename.concat root "decisions/kernel-conformance-runner.yaml";
  Filename.concat root "decisions/validate-and-context.yaml";
]
```

ROADMAP.md P1 (process-principles) requires the dispatcher
to walk the full directory (`tests/cli/self-check-pass.t:7-8`
echoes this). The kernel's other entry points
(`bin/Mathc.ml:2061` `mc self-check`,
`bin/Mathc.ml:2426` `mc packages`) use
`Sys.readdir` over `decisions/`. Only the `memory.ml`
capsule builder uses the hardcoded list.

**History.** Commit `e3a4620` (R4 `full-decision-memory@1`)
replaced the hardcoded list with `Sys.readdir`. Commit
`8bc3ce2` reverted it "because its load_decisions walk had
unintended consequences for the gate-* cram fixtures".
The revert message does not explain the unintended
consequence.

**Consequence.** `mc context BASE HEAD --budget N` produces
a capsule that names 4 of 29 active decisions. An agent
reading the capsule has no visibility into `mc self-check`,
`gate-decision`, `algebra-3.2`, `site-deploy`, etc.

## D21.12 — `spec/constitution.md:149` contains `MUST MUST`

**Gap.** The 13th kernel invariant reads:
```
13. Fixture coverage: every kernel-enforced MUST MUST have at least one
    accepting and one rejecting conformance fixture.
```

`MUST MUST` is a literal typo. Either the second MUST is
extraneous, or the first is a duplicate of a word intended
to be "MUST" elsewhere. The sentence is unreadable.

**Where it surfaces.** `spec/constitution.md:149`. Also
possibly in `bin/Mathc.ml:1483` and `lib/decision.ml:218`
(the audit did not confirm these).

**Consequence.** The constitution is the kernel's
formal contract with itself. A typo at line 149 weakens
the whole document.

## D21.13 — Pre-commit hook not registered

**Gap.** `.githooks/pre-commit` exists (5486 bytes, mode
`-rwxr-xr-x`). PACKAGES.md:151-152 claims it is registered
through `git config core.hooksPath`. Verified at HEAD: empty.

```
$ git config core.hooksPath
(empty)
```

**Cause.** `scripts/dev init-hooks` (one-time) has not
been run in this checkout.

**Consequence.** P1 (decisions before kernel changes) and
P2 (decisions paired with fixtures) are enforced in OCaml
tests but not at commit time. A contributor can commit a
kernel change without a paired decision, and the only
catch is in CI.

## Authoritative numbers (verified at HEAD `d10732d`)

```bash
$ mc packages --format=json | jq '.counts'
{ fail: 0, missing: 7, no_store: 0, pass: 96,
  stale: 0, total: 103, unknown: 0, waived: 0 }

$ mc packages --format=json | jq '.decisions | length'
29

$ mc self-check | jq '.subjects | length'
31

$ mc self-check | jq '.verdict'
"unknown"

$ mc self-check | jq '[.subjects[] | select(.verdict == "pass")] | length'
29

$ ls attestations/ | wc -l
105

$ ls tests/cli/*.t | wc -l
32

$ ls decisions/*.yaml | wc -l
32

$ mc validate decisions/decision.yaml
reject: decisions/decision.yaml
  code: MC-DECISION-INVALID
  severity: warn
  message: missing or invalid required field
```

## Fix routing

| Phase | Defects | Commit-prefix convention |
|---|---|---|
| 0 | — | — |
| 1 | D21.2, D21.3, D21.4 | `feat(kernel):` |
| 2 | D21.1, D21.5 | `fix(kernel):`, `test:` |
| 3 | D21.6, D21.7, D21.8, D21.9, D21.10 | `docs:` |
| 4 | D21.11, D21.12, D21.13 | `fix(process):`, `fix(spec):` |
| 5 | unpushed commits (9) | merge commit |

Phase 0 produces this audit and the master decision
`decisions/audit-0.0.21-fixes.yaml`. Phases 1-4 each land
their commits atomically. Phase 5 merges the worktree back
to main.

## Evidence

| Source | Where | Type |
|---|---|---|
| `mc packages --format.json` | run at HEAD | observed |
| `mc self-check` | run at HEAD | observed |
| `mc validate decisions/*.yaml` | 32 invocations | observed |
| `mc re-evaluate <known-id> A1` | 4 invocations | observed |
| `git config core.hooksPath` | run at HEAD | observed |
| `git log --oneline` | run at HEAD | observed |
| `ls attestations/`, `ls tests/cli/*.t`, `ls decisions/*.yaml` | run at HEAD | observed |

## Outstanding after this cycle (deferred)

- **D8** (`mc validate` coarse diagnostics) — pre-existing,
  tracked at `doc/AUDIT-0.0.11.md:465`, scheduled for 3.0-beta.
- The **portable-linux-musl** retirement signal (`alpine-ci-build-fails`)
  is unchanged; the 7 obligations stay missing unless a
  waiver is issued.

The CERT-PASS claim ("automated guarantees not manual
declarations") is the END state of this cycle, not the
start. No claim in this audit relies on it.