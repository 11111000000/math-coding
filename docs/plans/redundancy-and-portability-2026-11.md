# Plan: Redundancy and portability, 2026-11

> **Status:** active, T0 in progress.
> **Branch:** `feat/redundancy-census-2026-11` (T0.1), then one branch
> per tranche.
> **Author:** orchestrator, 2026-10-31.
> **Companion decision:** `decisions/redundancy-census-2026-11.yaml`.
> **Instrument:** `tests/fixtures/redundancy-census.sh`.

## 0. Why this exists

The protocol is a working frame with two layers of growth on top of
it, and the growth has never been measured.

The frame works. `materials_digest` binds an attestation to the
content of the files a decision scopes (`lib/gate.ml:146-176`); a
scope change makes the signature stale. `unknown` is not `pass`
(`lib/gate.ml:209-214`). A review-class attestation discharges an
obligation only when its producer is a `human:` identity
(`lib/gate.ml:416-436`), so the 38 review signatures the machine wrote
in October close nothing. The kernel tells a check from a declaration
on its own (`bin/Mathc.ml:5064-5119`), and `mathc gaps` prints the
difference as a worklist. Three artifacts are all a project needs to
adopt the method: a decisions directory, an attestations directory,
and a `policies.yaml`.

The growth is what obscures it. The corpus holds 139 live decisions
where the project declared a target of about fifty rules
(`decisions/corpus-final-state-2026-10.yaml:64-70`). Forty-four
relation targets resolve to nothing. Twenty scope paths match no
tracked file, and a scope that names nothing makes the digest of that
decision a digest of nothing - the freshness wildcard. Five verifier
strings carry a YAML quote that broke their scheme, so those
obligations are promises the kernel cannot execute and the corpus
carries as if they were checks. The normative text
(`spec/algebra-3.2.md`, 1 002 lines) has not changed since
2026-10-24 while the code moved 221 commits, and it still says "72
active decisions" when there are 137. The risk function classifies
paths by a table whose entries name directories this repository does
not have (`lib/risk.ml:76-88`), and the whole of it is inert here:
the maximum risk it can produce is 0.0475 against a first threshold of
0.05, so `risk_to_mode` is always `Tiny` and the mode of every change
comes from the floor the project declared, not from the risk.

Every audit of this corpus began by reading 139 files. That is the
defect this plan fixes first: the corpus's shape must be a number.

## 1. The five principles

1. **A measurement becomes an instrument, not a report.** The tree
   already holds five (`executed-evidence-census.sh`,
   `legacy-attestation-debt.sh`, `negative-control-debt.sh`,
   `self-check-debt-ceiling.sh`, `corpus_no_silent_drops.ml`). All five
   measure the STORE. None measures the CORPUS's shape.
2. **A check must be able to catch its own lie.** The census of
   2026-10 turned `manual-*` promises into "the nearest check a
   program can execute" - executable, and not checking the claim.
   That class is worse than paper: the kernel takes it for evidence.
3. **Policy changes by decision, never by prose.** Two active
   decisions currently state opposite applicability rules, and both
   were green in one CI run (2026-10-30T14:57:35Z).
4. **The corpus converges on its declared target.** Records go to the
   archive by the census criterion - nothing in the tree depends on
   them. Rules stay, and stay executable.
5. **The transferable is separated from the project.** The kernel,
   `policies.yaml` and three artifacts are the protocol. The site,
   the plugin, the conformance corpus, the release tooling and the
   book are this repository.

## 2. Boundaries (A3 self-application)

- This plan is a plan. It lives in `docs/plans/`, and only the
  changes of POLICY become decisions (`decisions/*.yaml`).
- No tranche changes `spec/` or `axioms/` except T3, which is an A3
  protected transition and needs human review before merge.
- Every tranche leaves the corpus no larger than it found it.
- Every tranche is independently revertable; the census is the
  instrument that says whether a tranche achieved its aim.

## 3. The instrument (T0.1)

`tests/fixtures/redundancy-census.sh` prints and bounds six numbers:

| number | what it is | ceiling at 2026-10-31 |
|---|---|---|
| PAPER | obligations the kernel cannot execute (`mathc gaps`, against an empty store) | 44 |
| BROKEN | obligations whose verifier scheme the kernel does not recognise | 5 |
| DANGLING | relation targets that resolve to nothing | 44 |
| DEAD | scope paths matching no tracked file | 20 |
| CORPUS | decisions in the live corpus | 141 |
| ARCHIVE_ACTIVE | archived decisions still saying `state: active` | 104 |

Each ceiling may fall and may never rise; raising one is an explicit,
reviewable edit of the fixture, with the reason written beside it.
The fixture's negative control builds a synthetic corpus that
exceeds every ceiling and requires the instrument to report each
defect: a bound that has never been observed to bind is not known to
bind. Exit codes follow the house convention: 0 measured and held, 1
measured and broken, 3 nothing was measured - unknown, not pass.

## 4. The tranches

Order is by dependency, not by preference.

### T0 - instruments (2026-11-03 .. 11-07)

| step | what | risk |
|---|---|---|
| T0.1 | the redundancy census (this plan's companion) | low |
| T0.2 | repair the instruments that do not check themselves: the `MC_VERSION` check in `scripts/sync-version.sh --check` (commented out at lines 276-278), `tests/fixture_coverage.ml` (checks that a fixture file exists, not that it has an accepting and a rejecting case), `tests/cli/attest-batch-signature.t` (exercises `--from=decisions`, never `--manifest`) | low |
| T0.3 | two lints so the corpus cannot regrow: a verifier scheme outside the canonical list, and a relation target that resolves to nothing | medium - the first day they must run as reports, not errors |

### T1 - the kernel's own dirt (2026-11-09 .. 11-13)

| step | what | risk |
|---|---|---|
| T1.1 | `lib/risk.ml`: the dead branches (`pci/`, `payments/`, `migrations/`), the dead `mode_floor_of_string` (0 callers, and a vocabulary the kernel does not use), and the silent degradation of an unknown `mode_floor` to `Tiny`. The spec mirrors this table, so the spec's section moves with it, in the same commit | medium |
| T1.2 | one protected-path list: `lib/gate.ml:1016`, `scripts/pre-commit/decision-fixture-co-commit.sh:16-20` and `.github/workflows/release-pending.yml:123-129` currently disagree (`lib/` against `lib/*.ml` against `lib/*`) | low |
| T1.3 | the scaffold emits a file that is not valid YAML for a strict parser (an unquoted `<TODO: ...>`), and its `risk` block is indented under the `counterexample` scalar, so the parsed decision has no risk at all; and `lib/gate.ml:955-958` answers `Pass` when `changed_paths` is empty, so a missing git gives a green gate | medium |

### T2 - the corpus (2026-11-16 .. 11-27)

| step | what | risk |
|---|---|---|
| T2.1 | archive tranche: the records (one-off events, refactoring notes) move to `archive/decisions/` with `state: retired` and a reason. 112 archived files still say `state: active` today | medium |
| T2.2 | rewrite the stale decisions into statements about the current state, or archive them; fix the 44 dangling relation targets and the 20 dead scope paths | medium |
| T2.3 | the five quote-broken verifiers: fix the scheme or withdraw the promise. They are signed `pass` in the store, so the store lies about them | low |
| T2.4 | the class the audit of 2026-10-30 found and this plan names: obligations whose verifier is executable but does not check its own claim. 13 decisions carry no negative control; the debt is 98 against a ceiling of 123, and the ceiling may only fall | high - a choice: rewrite, declare with an owner and a date, or archive |

### T3 - the contract of the kernel (2026-11-30 .. 12-04, A3)

| step | what | risk |
|---|---|---|
| T3.1 | `spec/algebra-3.2.md` becomes `spec/kernel-contract.md`, content unchanged; the four fixtures that mirror the document (`risk-bucketing.t`, `body-vs-wrapper-canonical.t`, `applicability-envelope.t`, `render-mathjax-spec.t`) compare constants directly instead of grepping the text; 13 runtime strings and 26 schema descriptions follow | medium |
| T3.2 | one decision supersedes `decisions/algebra-3.2.yaml` and shrinks 1 002 lines to about 100: what the kernel enforces (rule, code, test) and what is declared but unchecked. The six references in `axioms/**` move in the same protected transition | high - human review |

### T4 - portability (2026-12-07 .. 12-18)

| step | what | risk |
|---|---|---|
| T4.1 | the transferable core becomes its own package: kernel, `policies.yaml`, three artifacts, the skill. The site, plugin, conformance corpus, release tooling and book stay here and are marked "not part of the protocol" | medium - a choice of packaging |
| T4.2 | one master policy instead of three (the one embedded in `mathc init`, the disconnected template in `scripts/install-tooling/templates/active-policy.yaml`, whose `MC_TEMPLATE_REMOTE_PATH` is a dead variable, and `decisions/decision.yaml`); `QUICKSTART.md` tells the reader what `mathc init` actually creates; the installer stamps a build id, because two binaries answer `3.7.4` and the older one writes a scaffold the kernel rejects | low |
| T4.3 | the project's own strings leave the core: `lib/gate.ml:1016`, `lib/capsule.ml:171-176`, `lib/decision.ml:1664-1667`, the sixteen pointers in `lib/diagnostic.ml`, and the read of a file that does not exist (`lib/memory.ml:592`) | medium |

### T5 - the measurement and the book (2026-12-21 .. 12-24)

| step | what | risk |
|---|---|---|
| T5.1 | re-measure the cost of the method on the fixed binary. The "3-4x slower" figure was measured on 3.3.1, before the path resolver was fixed, and nobody has measured it since | low |
| T5.2 | mark the book as normative background rather than a dependency: `axioms/`, `spec/`, `KERNEL_AGENTS.md`, `OCAML_KERNEL_CONVENTIONS.md`. An adopter's tree receives `policies.yaml`, decisions, attestations and the skill | low |

## 5. Parallelism

Branches that own disjoint files run in parallel; anything that shares
a file is sequenced.

| wave | branches | why they do not collide |
|---|---|---|
| 1 | T0.1 (the census), T0.2 (the instruments), T0.3 (the lints), T1.1 (the risk tables), T1.2 + T1.3b (the gate and the protected paths), T1.3a (the scaffold) | `tests/fixtures/`, `tests/`, `scripts/`, `lib/risk.ml`, `lib/gate.ml`, `lib/new_decision/`, `lib/policy.ml`, `spec/` section 2 |
| 2 | T2.1-T2.4 (the corpus), T4.2 (the adoption path), T4.3 (the core's project strings) | `decisions/`, `archive/`, `docs/`, `lib/capsule.ml`, `lib/decision.ml`, `lib/diagnostic.ml`, `lib/memory.ml` |
| 3 | T3.1 + T3.2 (the contract), T5.1 (the measurement) | `spec/`, `axioms/`, the four mirror fixtures, `docs/experiments/` |

The corpus tranche is one branch, not four: the decisions name each
other, and rewriting them in parallel branches would produce conflicts
in the relations that are the point of the work.

## 6. What this plan does not do

- It does not make the method faster. The speed is 1-2 minutes per
  decision; the price of a decision is what the floor asks for.
- It does not judge whether a commitment is wise. The census counts;
  the decisions judge.
- It does not delete the site, the plugin or the book. They are not
  the protocol, and they are not hurting: they are only not
  transferable, which T4.1 and T5.2 state out loud.
- It does not roll the 2026-10 census back to `manual-*`. That was
  the audit's option 1, and it is a step backwards: the paper layer
  was removed on purpose, and the corpus was rewritten towards "a
  promise is either machine-checked or it is not there".
- It does not write one negative control per promise. That was the
  audit's option 2, and a control is one more artefact per promise.
  The line adopted here is: the promise is checked by something that
  can catch its own lie, or the promise is gone.

## 7. The three choices this plan does not make

1. **T2.4** - what to do with the promises that are executable but do
   not check their claim: rewrite them, declare them with an owner
   and a date, or archive the decisions that carry them.
2. **T3.2** - shrink the normative text to a contract of the kernel,
   or retire it entirely and rewrite the six references in `axioms/`.
3. **T4.1** - a separate package for the transferable core, or a
   marked boundary inside this repository.
