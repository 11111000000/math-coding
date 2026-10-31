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
   them. Rules stay, and stay executable. The target number itself
   ("about 50 rules") comes from the corpus's own census of 2026-10,
   which is a record and not a standing requirement; the census
   instrument therefore measures the distance and does not fail on it.
   A count is a symptom, and the question behind it - is every promise
   in the corpus true, and is every promise that cannot be true named
   as such - is the one that is worth asking.
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
| CORPUS | decisions in the live corpus | 144 |
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
| T2.1 | archive tranche: the records (one-off events, refactoring notes) move to `archive/decisions/` with `state: retired` and a reason. 120 files sit in `archive/decisions/`, and 104 of them still say `state: active` today | medium |
| T2.2 | rewrite the stale decisions into statements about the current state, or archive them; fix the 44 dangling relation targets and the 20 dead scope paths | medium |
| T2.3 | the five quote-broken verifiers: fix the scheme or withdraw the promise. They are signed `pass` in the store, so the store lies about them | low |
| T2.4 | the class the audit of 2026-10-30 found and this plan names: obligations whose verifier is executable but does not check its own claim. Measured 2026-10-31: 99 decisions name no negative control, against a ceiling of 123 that may only fall. Decided 2026-10-31: divide by the nature of the promise - see below | high - decided |

#### T2.2, measured (the brief, ready to launch)

The 44 dangling targets are not 44 different mistakes. Measured with
`tests/fixtures/relation-targets-resolve.sh` over the live corpus
(200 targets, 9 relation kinds the schema declares and 2 the corpus
adds):

| kind | count | what it is |
|---|---|---|
| `id-dangling` | 33 | the target names a decision id that does not exist |
| `path-dangling` | 10 | the target names a file that does not exist |
| `fragment-dangling` | 1 | `attestation-store-fill@2::ci-block-set`: the decision is there, the obligation in it is not |

Two habits in the corpus produce the id form, and both are fixable
without inventing anything:

- **The filename is not the id.** 19 of the 142 files in `decisions/`
  carry an `id:` that differs from the file's stem
  (`exit-code-symmetry-2026-10.yaml` has `id: exit-code-symmetry`,
  `ceiling-monotonic-2026-10.yaml` has `id: ceiling-monotonic` with
  `revision: 2`). A relation written against the filename resolves to
  nothing: `exit-code-symmetry-2026-10@1` is dangling, while
  `exit-code-symmetry@1` resolves. The fix is to write the id.
- **The revision is part of the reference.** `ceiling-monotonic@1` is
  dangling because the decision is at revision 2. A relation that means
  "the first version" must say so, or name the current revision.

The path form is mostly one decision: `decisions/spec-cli-catalog.yaml`
points at eight files under `bootstrap/` that do not exist, and two more
decisions point at the same tree. Either the files come back, or the
relations name what exists.

The census and the lint agree on 44 - the census asks the kernel, the
lint parses the corpus, and the two counts coincide. Two instruments
that measure the same thing and differ are a bug in one of them; here
they do not differ.

T2.2 is two tranches, because the work is two kinds of work and the
measurement of the corpus cannot say which decisions are records:

- **T2.2a, mechanical.** The 44 dangling targets and the 20 dead scope
  paths. Both are counted by an instrument, both have one right answer
  per case, and the lint's ceiling falls as they are paid. This is the
  tranche that can be checked by running the instrument.
- **T2.2b, judgment.** The decisions whose claims no longer hold: read
  one, decide whether it is a rule that is still true, a rule that
  must be rewritten, or a record, and act. There is no pattern that
  finds these - a keyword heuristic over the 142 live decisions
  catches 77 candidates and misjudges half of them (it offers
  `enforce-body-sha-digest`, which is a standing rule, and misses
  `mcp-agent-auto-connect`, which is a record). The count of records
  cannot be measured by pattern; it can only be decided one at a time,
  and each decision is cheap to judge.

That is why the corpus's own "about 50 rules" cannot be used as a
target for T2.2b: it would need a classification that has to be
judged anyway, and a budget of decisions to be judged is not a
measurement. The census instrument therefore prints the distance and
does not fail on it.

#### T2.4, decided (2026-10-31): divide by the nature of the promise

The 99 decisions that name no negative control are not one class. They
are three, and the corpus has to be able to tell them apart, because
the difference between "checked" and "asserted" is the whole question
the census asks.

| class | what it is | what happens to it |
|---|---|---|
| checkable | the claim can be falsified by the kernel or by a fixture | rewrite: give it a negative control - a fixture that must fail on a deliberately broken corpus |
| not checkable | the claim is a process, a judgment, a state of the world | declare: name an owner and a date, and mark it as declared rather than checked |
| record | the decision records an event that happened | archive it (T2.1) |

The instrument changes with the rule. The debt counter today reports
one number - "decisions without a negative control" - with a ceiling
of 123 that may only fall. After this tranche it reports three:
CHECKED (a control that can fail), DECLARED (an owner and a date, and
nobody checking) and UNCHECKED (neither). The ceiling that may only
fall moves to UNCHECKED, because that number has to reach zero.
DECLARED gets its own, slower ceiling: a declared promise is a
promise to look at it on a date, and dates slip.

A declared obligation must not look like a checked one to anything
that reads the corpus. The schema needs a field that says which of
the two it is, and the census has to count them apart. If declaring
were allowed to hide in the same field, the corpus would be telling
the same lie in a new place and the debt would look paid while
nothing had been checked.

This does contradict section 6, which says a promise is either
machine-checked or it is not there. The contradiction is real and
deliberate: the promises that cannot be checked are exactly the ones
whose absence was hiding a decision the method still needs, and
deleting them all would have been cheaper and worse. What keeps the
declared class from becoming the paper layer of 2026-10 is that it is
a number in the census, it carries a name and a date, and it is a
class the census reports separately - not a phrase in prose that a
reader has to notice.

#### T2.1, measured (a mention is not a dependency)

The first pass of the archive tranche looked at fourteen candidates for
the archive and moved one. The other thirteen were "named by the tree",
which sounded like a dead end and was not one: the naming turned out to
be mostly narration, not dependency.

| what the mention is | example | what it means for the move |
|---|---|---|
| the id, not a path | `relations.refines` from an archived decision, the `unknowns:` list in `lib/codec.ml` | nothing: both instruments resolve ids across the live tree and the archive, so the mention stays true |
| a path to a file | `PACKAGES.md`'s index row, a comment that says "see decisions/x" | the path stops existing: point it at the archive, or reword |
| a story of something that happened | `CHANGELOG.md`, `ROADMAP.md` | nothing: it stays true wherever the file lives |
| a machine reading the file | a script or a fixture that opens it | the real question: what does it check, and does it still need a live decision |
| normative text | `spec/algebra-3.2.md:143` | A3: the normative text does not move, so the decision that it names stays |

The criterion in principle 4 is "nothing in the tree depends on it",
not "nothing in the tree says its name". The first pass used the
stricter reading because the brief said so, and the strict reading
costs thirteen moves for nothing. The second pass fixes the pointers
and moves the files.

So the archive is not a filing cabinet: a record that the corpus's own
machinery names is entangled with that machinery, and untangling it is
the work. One move out of fourteen is the honest answer to a question
that was asked wrongly, not a failure.

### T3 - the contract of the kernel (2026-11-30 .. 12-04, A3)

| step | what | risk |
|---|---|---|
| T3.1 | `spec/algebra-3.2.md` becomes `spec/kernel-contract.md`, content unchanged; the four fixtures that mirror the document (`risk-bucketing.t`, `body-vs-wrapper-canonical.t`, `applicability-envelope.t`, `render-mathjax-spec.t`) compare constants directly instead of grepping the text; 13 runtime strings and 26 schema descriptions follow | medium |
| T3.2 | one decision supersedes `decisions/algebra-3.2.yaml` and shrinks 1 002 lines to about 100: what the kernel enforces (rule, code, test) and what is declared but unchecked. The six references in `axioms/**` move in the same protected transition | high - human review |

#### T3.1, measured (the rename is bigger than the row above says)

The row was written before anyone counted. Measured on 2026-10-31,
`spec/algebra-3.2.md` is named **322 times in 120 tracked files**:

| where | files | what it is |
|---|---|---|
| `decisions/` | 23 | records: four of them carry a live obligation that greps the file, the rest are history |
| `archive/decisions/` | 19 | history |
| `tests/cli/` | 22 | fixtures that grep the document for constants - these break |
| `lib/` | 9 | comments, and four runtime diagnostics whose message quotes the path |
| `schemas/` | 5 | descriptions |
| `docs/plans/`, `site/`, `scripts/`, `tests/fixtures/` | 21 | prose and links |
| `USAGE.md`, `docs/` | 3 | prose |

Plus 93 `algebra §N` section pointers in `lib/` and `bin/` and 13 in
`tests/`: they survive a rename as prose, but the anchor they name
stops existing, so a comment that says "algebra §13" ends up pointing
nowhere. That is the kind of sentence that looks like a reference and
is not one.

So the plan's "four fixtures, 13 runtime strings, 26 schema
descriptions" was wrong by an order of magnitude, and the correction
changes the shape of the tranche:

- **What is machine-followed must move**: 22 test files, four runtime
  diagnostics (the `MC-COUNTEREXAMPLE-MISSING` and
  `mode-considered-no-antithesis-demo` messages, whose text appears in
  five cram fixtures), five schema files, four decisions whose
  `verifier:` greps the document, and two whose `scope.paths:` names it
  (a renamed file makes a scope path dead, and the dead-path count is
  a number the census bounds).
- **What is a record keeps its history**: the 19 archived files and the
  19 decisions that only mention the path in prose say what was true
  when they were written. Rewriting them would be lying about the past,
  and it would cost 322 edits to buy nothing.
- **What is a comment gets the new name**: 93 section pointers move to
  the new file's sections, and the fixture that checks them stops
  grepping the prose and compares the constants instead.

The rename is a mechanical move with a real blast radius, so it gets
its own tranche with its own decision, and the ceiling on dead scope
paths is checked after it: a rename that turns 2 live scope paths into
dead ones must pay them back in the same tranche.

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

## 7. The choices this plan does not make

1. **T3.2** - shrink the normative text to a contract of the kernel,
   or retire it entirely and rewrite the six references in `axioms/`.
2. **T4.1** - a separate package for the transferable core, or a
   marked boundary inside this repository.

T2.4 was decided on 2026-10-31: the promises are divided by their
nature, and the instrument grows three numbers where it had one. The
decision is written out under T2.4 above.

## 8. State of the wave (2026-10-31)

Merged into `main`, each with its own decision and its own evidence:

| tranche | what it changed | evidence |
|---|---|---|
| T0.1 | the census, this plan, `decisions/redundancy-census-2026-11.yaml` | the instrument's own negative control |
| T0.1a | the census stopped mirroring the kernel: PAPER is the kernel's answer over an empty store, BROKEN is the kernel's own `MC-VERIFIER-SCHEME-UNKNOWN`, ARCHIVE_ACTIVE counts only files carrying a `math-coding/3.x` schema | 46 -> 44 paper obligations; 104 archives counted as decisions instead of 112 |
| T0.1b | the marker a ceiling raise must carry, in the format `scripts/ceiling-monotonic.sh` reads | the checker caught my own wrong marker and made me fix it |
| T0.1c | the census prints the ITEMS behind its counts (`--list`), because a number nobody can act on is a number, not a measurement | my own reconstruction counted 576 dead paths; the instrument knew 20 |
| T0.2 | the `MC_VERSION` check back in both copies of the skill, `tests/fixture_coverage.ml` measuring levels instead of existence, `tests/cli/attest-batch-signature.t` exercising `--manifest` | 77 cram fixtures measured: 0 without an accepting case, 51 without a rejecting one |
| T1.2 + T1.3b | one protected-path list in `scripts/protected-paths.txt` with two matchers that check each other, and a gate that answers `unknown` instead of `pass` on an empty diff | the gate's own output on an empty diff |
| T0.3 | two lints so the corpus cannot grow back: a verifier scheme outside the canonical list, a relation target that resolves to nothing | both fixtures, each with a synthetic corpus that must be caught |
| T1.1 + T1.3a | the risk function's dead branches, an unknown `mode_floor` named instead of silently downgraded, and a scaffold that a strict parser can read | `tests/fixtures/risk-dead-branches-gone.sh`, `tests/cli/policy-unknown-mode-floor.t`, `tests/cli/new-decision-scaffold.t` |
| T2.3 | eight promises that named a verifier the kernel could not execute, or one that did not check its own claim; the diagnostic prints the list the kernel owns | BROKEN 5 -> 0, PAPER 44 -> 38 |
| T2.1 | twelve records moved to `archive/decisions/` with `state: retired`; two stayed for reasons that are not taste | the corpus criterion, and the pointer repairs each move needed |
| T2.2a | the corpus's relation and scope debt paid: 44 dangling targets and 20 dead scope paths, both zero now | both instruments report zero, and the census lists no item |

The numbers after the wave (2026-10-31):

| number | before | now |
|---|---|---|
| CORPUS - decisions in the live corpus | 144 | 136 |
| PAPER - obligations the kernel cannot execute | 44 | 36 |
| BROKEN - verifier schemes the kernel does not know | 5 | 0 |
| DANGLING - relation targets that resolve to nothing | 44 | 0 |
| DEAD - scope paths matching no tracked file | 20 | 0 |
| ARCHIVE_ACTIVE - archived decisions still saying `state: active` | 104 | 104 |

Three things the wave cost, written down because they were not
obvious:

- **The corpus is a mechanism, not a filing cabinet.** A record that
  the corpus's own machinery names is entangled with that machinery:
  its verifier, its relations, a hook that points at it. The first
  pass of the archive tranche moved one file of fourteen because the
  brief said "nothing names it"; the plan says "nothing depends on
  it", and with the difference made explicit eleven of the remaining
  thirteen moved.
- **A mention is not a dependency, and a path is not an id.** Nineteen
  of the corpus's files carry an `id:` that differs from the file's
  stem, and the revision is part of a reference - so a relation
  written against the file name resolves to nothing. Half of the
  corpus's dangling targets were that habit and nothing else.
- **Five sessions died and the work did not.** Four of them on the
  shared SQLite file every opencode session writes to (the fix: one
  agent per provider), one on the token plan of the first minimax
  account (the fix: the second account). Everything now ends in a
  commit, and the wave's own rule is that a tranche is checked by the
  instruments rather than by the reader of a diff.

What is left, in the plan's order: T2.2b (the decisions whose claims
no longer hold - judgment, one at a time, not a pattern), T2.4 (the
debt counter grows three numbers where it had one), T3 (the contract
of the kernel: 322 references to the spec in 120 files), T4 (the
portable core), T5 (the measurement and the book).
