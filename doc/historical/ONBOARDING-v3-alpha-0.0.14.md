---
schema: math-coding/3.0-alpha
id: onboarding
revision: 1

intent: |
  Codify the entry point for a new agent in math-coding 3.0-alpha.
  This file is the canonical onboarding record. The project has
  many first-class sources (axioms, spec, decisions, schemas, fixtures)
  but no single file that names them all and explains how they
  compose. Without a single onboarding record, a new agent that
  joins the project has to read 30+ files before knowing which to
  read; that is exactly the drift mode that closed the
  priority-drift detector in v0.0.12.

  This decision is meta: it records the onboarding structure
  itself. The convention it codifies is "a new agent reads
  this file first, then ROADMAP.md, then PACKAGES.md, then the
  decision file matching the task." Like every other decision in
  decisions/, this one is itself an ADR — it follows the
  convention it declares, by virtue of being recorded here as
  decisions/onboarding.yaml. This is the A3 self-application
  pattern (recursion), which is by design.

commitment: |
  The file is structured as eight sections:

  1. Status — one-line snapshot of where the project is.
  2. Purpose — what math-coding is and is not.
  3. Directory map — every path in the repo, what it does, who
     owns it.
  4. Read-first order — the canonical sequence for a new agent.
  5. Axioms — the five philosophical foundations in one place.
  6. Protocol surface — working chain, operational chain, scope,
     non-scope.
  7. Conventions — what to do when adding a new file, new decision,
     new fixture.
  8. State — current tag, open audit debts, working-in-progress
     items.

  The file is the onboarding entry point. AGENTS.md §"Read first"
  renames itself to §"First file" and points to this one.

scope:
  capabilities:
    - onboarding-record
  paths:
    - "AGENTS.md"
    - "README.md"
    - "PACKAGES.md"
    - "ROADMAP.md"
    - "OCAML_BEST_PRACTICES.md"
    - "decisions/onboarding.yaml"
  exclusions:
    - "lib/**"
    - "bin/**"
    - "spec/**"
    - "schemas/**"
    - "axioms/**"

outcomes:
  - id: onboarding-canonical-record
    statement: |
      This file is the single entry point for a new agent. It
      names every other first-class file in the repo, the read
      order between them, the axioms the project follows, and the
      conventions for adding new content.
  - id: onboarding-records-itself
    statement: |
      This file is itself a decisions/ file. The convention "a new
      decision lives in decisions/ as a YAML record" applies to
      the file that codifies that convention. A3 self-application:
      the rule is recorded as an instance of itself.
  - id: onboarding-discoverable-via-packages-md
    statement: |
      PACKAGES.md §"Bootstrap packages (by file)" lists this file
      with a row pointing to its conventions. The OCaml test
      asserts the row exists.

countercase: |
  "The README.md is already an entry point; another onboarding
  file is duplication." The counterargument fails for three
  reasons (the same A0-separation dialectic the v0.0.18 Winner-1
  analysis applied):
  (a) README.md is a 200-line narrative for humans. This file
      is a 200-line structured record for agents. The two
      audiences are different: README is what a person reads to
      decide whether to look at math-coding; this file is what an
      LLM agent reads to become productive.
  (b) README.md is constrained to short prose; this file can
      carry a directory map, an axiom table, a convention
      matrix, and a state-of-the-project snapshot. The README
      would have to be either too long (loses its narrative role)
      or too short (loses the onboarding role).
  (c) This file is itself a decisions/ file, which AGENTS.md
      §"Read first" already privileges over README. The
      "another onboarding file is duplication" complaint
      misreads the architecture: README is the human entry
      point; this file is the agent entry point; the convention
      is "the two coexist."

assumptions:
  - id: decisions-rename-stable
    state: assumed
    statement: |
      The decisions/ directory is the canonical location for
      both decisions and onboarding records. A future release
      that splits onboarding/ out of decisions/ would require a
      new decision recording the new convention (per A3).
    owner: human:maintainer
    consequence_if_false: |
      If onboarding/ becomes a separate directory and the
      convention changes without a new decision, the
      priority-drift detector in decisions/priority-drift.yaml@2
      will flag the change as a candidate drift.
    review_on:
      - signal: onboarding-relocated

obligations:
  - id: onboarding-record-self-applies
    outcome: onboarding-records-itself
    claim: |
      This file is recorded in decisions/ as a decisions/<topic>.yaml
      file, following the same schema and convention as every
      other decision. A3 self-application: the rule that
      decisions live in decisions/ is recorded as a decision in
      decisions/.
    acceptance:
      all:
        - verifier: tests/repo_structure.ml
          result: pass
  - id: onboarding-canonical-row-in-packages
    outcome: onboarding-discoverable-via-packages-md
    claim: |
      PACKAGES.md §"Bootstrap packages (by file)" contains a row
      for decisions/onboarding.yaml with a link to the onboarding
      contents.
    acceptance:
      all:
        - verifier: tests/repo_structure.ml
          result: pass

reversal:
  - signal: onboarding-relocated-or-removed
    action: |
      record-a-new-decision-with-supersedes:-[onboarding@1] and
      update PACKAGES.md to reflect the new location or removal.

risk:
  declared_triggers:
    - onboarding-drift
  owner: human:maintainer

relations:
  addresses:
    - bootstrap-v3
  supersedes: []
  superseded_by: []

---

# Math-coding 3.0-alpha onboarding record

> Status: this file is a decisions/ ADR and the canonical
> onboarding record for new agents. It is current as of
> `git tag v3-alpha-0.0.14` (commit `05e2ea5`). The repository
> has accumulated 17 Bootstrap decision files plus the audit
> log; this onboarding record brings the context forward so
> the next agent session can pick up cleanly.

> This is the file to read first. The agent should also read
> ROADMAP.md, then PACKAGES.md, then the decision file
> matching the task — see §"Read-first order" below.

## 1. Status

math-coding is at **v3-alpha-0.0.14**. The bootstrap process
introduced 5 axioms (separation, feedback, invariants,
self-application, care), 3 spec files (constitution, domain,
semantics), 18 Bootstrap decisions (a master policy + 14
sub-decisions + 2 aggregators), 4 JSON Schemas, 17 shell
fixtures (now 0 — they were migrated to OCaml/Alcotest in
v0.0.10), an OCaml/Alcotest conformance runner (9 cases
passing), 5 axioms, and the documentation system described
in OCAML_BEST_PRACTICES.md.

The next release (v0.0.18, in progress) consolidates the
infrastructure-honesty work (commit 191d1af) into a tagged
v0.0.14. The release *plan* (not yet executed) is:

  1. v0.0.18-1 cleanup: remove `legacy/`, add `result/` to .gitignore.
  2. v0.0.18-2 rename: `bootstrap/` → `decisions/`.
  3. v0.0.18-3 Winner-1: codify the onboarding convention as
     a new ADR under decisions/.
  4. v0.0.18-4 Winner-2: codify the formal-verifier-prefix
     convention as a new ADR.
  5. v0.0.18-5 audit + tag: update doc/AUDIT-0.0.18.md and
     cut tag v3-alpha-0.0.18.

The first three steps are done in the parent branch. Steps
4-5 are pending.

The **v0.0.0 / v2.1 source is reachable** via the
`v2.1-final` git tag. The directory layout in the active tree
does not contain it; use `git switch v2.1-final` to inspect
it. The `v3-alpha-0.0.x` source is at the corresponding `v3-alpha-*`
tags.

## 2. Purpose

math-coding is a **risk-adaptive assurance protocol for software
changes**. It links intent, decisions, obligations, changes,
attestations, observations, and revisions into an audit chain
that the kernel can verify mechanically.

The protocol is **not**:

- a CI runner. (Use the host's CI; the project does not provide
  its own orchestration. The shell fixture `scripts/check.sh` is
  the developer-side aggregation; `nix flake check` is the
  formal aggregation in CI.)
- a code-review tool. (Reviews happen out-of-band.)
- a documentation generator. (The spec files are normative; tools
  read them.)
- a runtime monitor. (Attestations are produced out-of-band; the
  kernel does not run them in production.)
- a ticket or issue tracker. (Issues are tracked separately.)
- a chat or messaging system. (Synchronous, agent-to-agent chat
  happens in Paseo workspaces; the project does not host it.)
- a code formatter or linter beyond what `dune fmt` provides.
  (See OCAML_BEST_PRACTICES.md for the project-specific rules.)
- a tests runner. (Tests run via `dune test`; the shell fixture
  `scripts/check.sh` aggregates; the cram CLI tests run via
  `dune runtest`.)
- a build system. (Build is via `dune build`; the flake.nix
  nix shell provides the OCaml toolchain.)
- a package manager. (nix is the package manager; `flake.nix`
  declares the inputs; the project's actual dependencies are
  zero — the kernel stays pure.)

In short: math-coding is a *record* and an *audit*, not an
*executor*. The executor is the developer's host (nix, dune,
OCaml compiler, git). math-coding records what was decided, what
must hold, what was verified, and what is missing.

## 3. Directory map

### Top-level

- `AGENTS.md` — the agent protocol. A 200-line document
  describing how an LLM agent should behave in this repo. Has a
  "Read first" section that points to ROADMAP.md as the
  canonical next read.
- `README.md` — the human-facing entry point. A 200-line
  document. The current README is current as of v0.0.10. It
  points to ROADMAP.md, PACKAGES.md, axioms/index.md.
- `ROADMAP.md` — the priority queue and process principles.
  Contains the Tier 1-4 work list and the P1-P7 process
  principles. Current as of v0.0.10; the v0.0.18 plan
  description in §"Status" above is the active update.
- `PACKAGES.md` — the catalogue. One row per decision file
  under decisions/, with status, revision count, obligations
  count, and the audit debt it closes.
- `OCAML_BEST_PRACTICES.md` — project-specific OCaml conventions
  plus a trap log (§11) of errors encountered. The trap log
  entries are 1:1 with observed failures; they accumulate.

### decisions/ (Bootstrap decisions)

- `decisions/decision.yaml` — the active policy (`bootstrap-v3@2`).
  The master obligation list.
- `decisions/obligations.yaml` — aggregator. The 8 obligations of
  the active policy listed as a cross-reference, so a single
  grep finds them without parsing the master policy's
  `obligations:` block.
- `decisions/rationale.md` — narrative companion to the master
  policy. Pure prose, not a decision.
- 15 sub-decisions covering kernel, process, infrastructure,
  time, schemas, adapters, and governance. The full list is in
  PACKAGES.md §"Bootstrap packages (by file)".

### spec/ (Normative contracts)

- `spec/constitution.md` — the 14 invariants the kernel must
  preserve. The kernel's correctness is measured against
  these.
- `spec/domain.md` — the closed entity model (5 kinds:
  Decision, Obligation, Attestation, Waiver, Change, plus the
  separate `execution_log` record). Defines required fields per
  kind.
- `spec/semantics.md` — operational rules. The merge gate, the
  release gate, revisions, the protected-policy-transition
  protocol, and the CLI subcommand contract (10 subcommands
  as of v0.0.10).

### axioms/ (Philosophical foundations)

Five axioms; the index is axioms/index.md. The kernel does not
read these files; the agent does, before any non-trivial change.

### schemas/ (JSON Schemas)

- `schemas/common.json` — shared definitions.
- `schemas/decision.json`, `schemas/obligation.json`,
  `schemas/attestation.json`, `schemas/waiver.json` — the
  four-entity schema set, plus a fifth (the older
  `schemas/execution_log.json` for the time-honesty storage
  record).

### lib/ (Pure kernel, offline)

- `lib/domain.ml` — closed algebraic types. The 5-kind enum and
  the `execution_log` record.
- `lib/canonical.ml` — RFC 8785 JCS canonicalization.
- `lib/jsonl.ml` — hand-rolled JSON parser/printer.
- `lib/schema.ml` — schema-aware field extractors.
- `lib/diagnostic.ml` — `Diagnostic.t` record + constructors +
  severity + class.
- `lib/identifier.ml` — id / timestamp / digest parsers.
- `lib/digest.ml` — SHA-256 (hand-rolled). **This implementation
  has not been validated against RFC 6234 vectors** (open audit
  debt D4). It must not be used for canonicalization in any
  release path until the test suite is fixed.
- `lib/codec.ml` — pure YAML/JSON loading + value parsing.
- `lib/decision.ml` — Decision decoder.
- `lib/memory.ml` — project memory index.
- `lib/capsule.ml` — context capsule builder (priority order
  per spec/semantics.md §"Context-prioritisation").
- `lib/gate.ml` — gate verdict evaluator (currently a SCAFFOLD;
  the attestation store obligation is open).
- `lib/reference.ml` — reference parsing.
- `lib/scope.ml` — scope target parsing.
- `lib/git/git_diff.ml` — `git diff --name-only` adapter
  (I/O allowed; this is an adapter, not the kernel).
- `lib/junit/junit.ml` — JUnit XML parser (no I/O; pure on strings).

### bin/ (The mathc CLI)

- `bin/Mathc.ml` — argv dispatcher. Subcommands: `version`,
  `validate FILE [--format=text|json]`, `context BASE HEAD
  --budget N`, `assess BASE HEAD`, `attest FILE`,
  `gate BASE HEAD`, `session-start`, `record --decision-id ID
  --scale S --class C --value N`, `stats --scale S --class C
  --since ISO`, `time-estimate --class C`. The CLI contract is
  in spec/semantics.md §"CLI subcommands"; the implementation
  in bin/Mathc.ml follows that contract.

### tests/ (Acceptance tests)

- `tests/conformance.ml` (Alcotest) — the runner. Walks
  fixtures/conformance/{decision,attestation,waiver}/ and asserts
  parse-acceptance for each. 9 cases passing.
- `tests/digest_vectors.ml` (Alcotest) — SHA-256 RFC 6234 vectors.
  Currently xfail until the digest.ml fix lands.
- `tests/process_principles.ml` (Alcotest) — P1-P7 obligation
  enforcement (the 5 machine-checkable ones). The non-checkable
  subset (P3 time-box, P4 merge order) is recorded as
  manual-acceptance in decisions/process-principles.yaml.
- `tests/repo_structure.ml` (Alcotest) — the convention
  enforcement layer. Asserts that the conventions in
  decisions/agent-onboarding.yaml, decisions/formal-verifier-
  conventions.yaml, and the existing rules are present in
  PACKAGES.md, ROADMAP.md, AGENTS.md.
- `tests/cli/*.t` (dune cram) — 8 CLI integration tests covering
  each subcommand. Run via `dune runtest`.

### fixtures/ (legacy)

Empty as of v0.0.10. The previous shell fixtures under
fixtures/*.sh were migrated to OCaml/Alcotest (commit 7907b17:
"drop 8 redundant repo-state shell fixtures"). The directory
remains for backward compatibility but contains only a stale
"fixtures" placeholder, which is `.gitignore`d.

### legacy/

Empty as of v0.0.18-1 commit f2f527f. The file `legacy/v2.1.md`
was a single pointer to the `v2.1-final` git tag; the
historical source is reachable via `git switch v2.1-final`.

### doc/ (Audit history)

- `doc/AUDIT-0.0.11.md` — the canonical deficit chain. The
  audit's deficit IDs (D1-D8) are referenced in PACKAGES.md
  and in any decision's `addresses:` field.
- `doc/AUDIT-0.0.18.md` (planned, not yet written) — the v0.0.18
  audit that closes the v0.0.10 infrastructure-honesty work and
  the new onboarding decisions.

### scripts/ (Developer tooling)

- `scripts/dev` — build wrapper. `scripts/dev build`, `scripts/dev
  test`, `scripts/dev rebuild`, `scripts/dev lint`, `scripts/dev
  check`, `scripts/dev lock-update`, `scripts/dev shell`,
  `scripts/dev run FILE`. Replaces the `rm -rf _build` superstition.
- `scripts/check.sh` — aggregator. Runs the remaining shell
  fixtures (none as of v0.0.10) and the cram CLI tests.
- `scripts/fmt-check.sh` — runs `dune fmt --check`.
- `scripts/pre-commit/` — pre-commit hooks (decision-fixture
  co-commit check; the hook concept is in ROADMAP Tier 2).

### .gitignore (top-level)

- `_build/`, `*.install`, `*.opam`, `.math/cache/`, `dist/`,
  `result/` — build artifacts.
- `.worktrees/` — worktree directories (git-managed elsewhere).
- `.local`, `bootstrap/execution-logs.jsonl` — per-worktree runtime
  data (time-honesty obligation storage-paths-declared).

### flake.nix (Nix shell)

- `devShells.default` — kernel-only toolchain (OCaml + dune).
- `devShells.test` — full toolchain (OCaml + dune + alcotest).
- `packages.default` — mathc binary.
- `checks.default` — runs `dune test`.
- `checks.x86_64-linux.fmt` — runs `dune fmt --check`.

## 4. Read-first order

A new agent that opens the repo for the first time should
read these files in this order:

1. `ROADMAP.md` (single source of truth for priorities, audit
   status, and process principles).
2. `PACKAGES.md` (single source of truth for "what exists in
   this repository": every decision, fixture, kernel module,
   adapter, schema, spec, and axiom).
3. `README.md` (short pitch and pointers — the human entry point).
4. `spec/constitution.md` (the 14 invariants the kernel must
   preserve).
5. `spec/domain.md` (the closed entity model).
6. `spec/semantics.md` (operational rules + CLI subcommand
   contract).
7. `OCAML_BEST_PRACTICES.md` (project-specific OCaml conventions
   plus the trap log in §11).
8. `decisions/<relevant>.yaml` (the specific decision file
   matching the task at hand).
9. The corresponding fixture (in `tests/fixtures/*.sh` or
   `tests/cli/*.t` or `tests/repo_structure.ml`).

This file (the onboarding record) is **not** the entry point;
it is the structural map of the repo. The first three items
(ROADMAP, PACKAGES, README) are the live entry points; the rest
is the deep structure.

## 5. Axioms (5)

The five axioms are the philosophical foundations of the
project. Every non-trivial change must derive from at least
one. They are versioned with the kernel; a change to an
axiom is itself a protected-policy transition (axiom A3).

### A0 — Separation (axioms/separation.md)

Kinds are distinct. The chain is one-way:

```
intent -> decision -> obligation -> change -> attestation
       -> observation -> revision
```

A Decision's `claim` is the decision, not the intent. An
Obligation's `statement` is the property, not the decision. A
Change's `summary` is the change, not the obligation. An
Attestation's `result` is the verification, not the change. An
Observation is the deployment fact, not the verification.
A Revision does not go back to Decision.

Where this lives:
- `spec/domain.md` enforces the kinds.
- `spec/semantics.md` follows the chain.
- `schemas/*.json` requires the fields per kind.
- `lib/domain.ml` provides the closed variants.

### A1 — Feedback (axioms/feedback.md)

Every commitment has a path to an observation. The path
can be manual (human review) or automatic (kernel-enforced
fixture), but the path must exist. A commitment without a
path is a wish, not a feedback loop.

Where this lives:
- `lib/codec.ml` — `result` enum includes `Inconclusive`
  and `InfrastructureError` (the two "we don't know" states).
- `lib/decision.ml` — `Obligation.expires_at` is required (no
  waiver outlives its term).
- `spec/semantics.md` — operational outcomes may carry
  `absence_means: inconclusive`.

### A2 — Invariants and Recovery (axioms/invariants.md)

Every invariant has an authorized recovery. The recovery
operator R is authorized if at least one of:
- the current principal can execute it;
- a named authority can;
- a documented automated rollback exists.

The recovery is finite if it can be expressed as a bounded
sequence. `Gate.Blocked` always carries a `remedies` array
with at least one entry.

Where this lives:
- `lib/diagnostic.ml` — `Diagnostic.t` record with `remedies`,
  `next_actions`, `retryable`, `autofix_safe`.
- `lib/gate.ml` — `Gate.Blocked` variant requires `remedies`.
- `lib/codec.ml` — `Obligation` acceptance has `remedies` field.

### A3 — Self-application (axioms/self-application.md)

The rules govern their own changes. Every change to the
constitution, schemas, canonicalization, kernel, gate rules,
authority rules, or waiver rules is a protected-policy
transition. The transition is recorded as a Decision under
the previously active policy. A candidate policy does not
authorize its own adoption.

Where this lives:
- `bootstrap/decision.yaml` is itself a Decision under the
  bootstrap protocol it declares. Recursion by design.
- `process-principles.yaml` records the P1-P7 process norms as
  obligations; the principles are themselves enforced by a
  fixture under the policy.
- `OCAML_BEST_PRACTICES.md` §11 trap log accumulates violations
  and fixes; the trap log is itself enforced by the process.

### A4 — Care (axioms/care.md)

The protocol records who benefits, who suffers, who is
accountable, and when the decision is revisited. A Decision
without an owner is a wish; an Assumption without a
consequence is a guess; a Waiver without a scope is a leak.

Required fields (per A4):
- `Decision.risk.owner`
- `Obligation.decision`
- `Assumption.owner`
- `Assumption.consequence_if_false`
- `Waiver.issuer`
- `Waiver.scope`
- `Waiver.expires_at`

The owner of a risk is a real principal, not a placeholder.

Where this lives:
- `lib/domain.ml` — required fields are typed as `string`, not
  `string option`. A record missing a required field does not
  parse.
- `tests/repo_structure.ml` and the conformance runner assert
  every Decision file has `risk.owner` populated.

## 6. Protocol surface

### 6.1 Working chain (one-way)

```
intent -> decision -> obligation -> change -> attestation
       -> observation -> revision
```

A change (`change:`) is produced by the Git/forge adapter and
by policy rules; agents do not author it directly. An
attestation is produced by a CI run; the agent that authors
the decision does not produce the attestation. An observation
is a runtime fact produced by a deployed process or a human
reviewer. A revision is a new decision that supersedes or
does not supersede the previous one.

### 6.2 Operational chain (what an agent or developer does)

```
change
  -> affected_knowledge    (git diff BASE..HEAD; decisions touched)
  -> assurance_gaps         (kernel + policy)
  -> minimal_remedies        (per the convention)
  -> gate                    (release gate; SCAFFOLD until attestation
                              store is built)
```

### 6.3 Scope (what math-coding is and is not)

The protocol's job is the assurance loop: every commitment has
a path to an observation, every observation has a known
source class, every source class is bounded by
subject/inputs/time.

### 6.4 Non-scope (what the protocol does not do)

- It is not a CI runner. The host's CI is the executor.
- It is not a code-review tool. Reviews happen out-of-band.
- It is not a documentation generator. The spec is normative.
- It is not a runtime monitor. Attestations are produced out-of-band.
- It is not a ticket or issue tracker.
- It is not a code formatter or linter beyond `dune fmt`.
- It is not a tests runner. Tests run via `dune test`.
- It is not a build system. Build is via `dune build`.
- It is not a package manager. The package manager is nix.

## 7. Conventions (how to add new content)

### 7.1 Add a new ADR / decision

1. Create `decisions/<topic>.yaml` (or `decisions/<topic>/packet.yaml`
   if it needs narrative, formal-verifier, or multi-file
   structure).
2. The file MUST have these frontmatter fields: `schema: math-coding/
   3.0-alpha`, `id: <topic>`, `revision: 1`.
3. The file MUST have these body sections: `intent`,
   `commitment`, `scope`, `outcomes`, `assumptions`,
   `obligations`, `reversal`, `risk`, `relations`. All are
   required (P1 enforcement).
4. Each obligation's `acceptance` MUST include a verifier. A
   verifier is one of:
   - a path under `tests/fixtures/*.sh` (file must exist),
   - a path under `tests/cli/*.t` (dune cram file must exist),
   - a kernel-test reference (e.g., `tests/conformance.ml ...`),
   - a manual-style verifier (prefix `text-scan-`, `cram-fixture-`,
     `script-runs-and-is-deterministic`, `dune test`, `manual-`,
     `review`, `practice-review`, `mathc-`).
5. Bump the active policy's revision if the change affects it.
6. Add a row to PACKAGES.md §"Bootstrap packages (by file)" with
   `revision: 1`, `obligations: <count>`, `status: RESOLVED`
   (or whichever is appropriate).
7. The P1 fixture (`tests/process_principles.ml`) enforces
   (1)-(4) automatically.

### 7.2 Add a new spec

1. Edit `spec/{constitution,domain,semantics}.md`. Each is a
   normative contract; any change is a protected-policy
   transition.
2. Update `schemas/*.json` if the new spec changes the shape of
   a kind.
3. Update `lib/domain.ml` if a new closed kind or new required
   field is added.
4. Add fixtures for the new spec invariant (P1/P2 enforcement).
5. Update the relevant decision's `addresses:` field.
6. Update `OCAML_BEST_PRACTICES.md` §11 trap log if the new spec
   reveals a new pitfall.

### 7.3 Add a new axiom

1. Create `axioms/<name>.md`. Each axiom is versioned with the
   kernel. A change to an axiom is itself a protected-policy
   transition (axiom A3).
2. Update `axioms/index.md` to add the new axiom row.
3. The new axiom MUST have a §"Where this axiom lives in the
   codebase" section (5-10 references to specific files).
4. The new axiom MUST have a §"What this axiom forbids" section.
5. The new axiom MUST have a §"Counter-example that would
   violate this axiom" section.
6. The new axiom MUST have a §"What an agent must do when the
   axiom seems to fail" section.
7. The P1 fixture (or a new test) enforces the axiom's
   mechanical properties.

### 7.4 Add a new shell fixture

1. Create `tests/fixtures/<name>.sh`. It must be executable.
2. The fixture must exit 0 on pass, non-zero on fail.
3. The fixture must print per-fixture status to stdout.
4. The fixture is invoked by `scripts/check.sh` automatically.
5. **However**: as of v0.0.10, the convention is that repo-state
   fixtures are migrated to OCaml/Alcotest. New repo-state
   fixtures should be added as `tests/<name>.ml` (Alcotest)
   rather than `tests/fixtures/<name>.sh` (shell). Only
   CLI-integration-style fixtures remain in shell.

### 7.5 Add a new OCaml test

1. Create `tests/<name>.ml` (Alcotest).
2. Register the test executable in `tests/dune`:
   ```
   (test (name <name>) (libraries mathcoding_core alcotest))
   ```
3. The test must use `Alcotest.test_case` with a `\`Quick` or
   `\`Slow` speed tag.

## 8. State (current as of v0.0.14)

### Tags

```
v0.0.1          bootstrap 3.0-alpha (rename `math/` → `bootstrap/`)
v0.0.1-final    final bootstrap
v0.0.2          dev-shell split
v0.0.3          add dune-project, flake, opam, .gitignore
v0.0.4          rename class_ to kind, refactor parse_acceptance
v0.0.5          process-principles
v0.0.6          mathc validate
v0.0.7          mathc context
v0.0.8          adapters (git, junit)
v0.0.9          cram integration
v0.0.10         consolidation (parse-acceptance, sha-256, capsule,
                 gate scaffold, yaml-block-scalars decision,
                 time-honesty, editorial)
v0.0.11         audit (doc/AUDIT-0.0.11.md)
v0.0.12         priority drift detector
v0.0.13         spec-cli-catalog
v0.0.14         audit D7 (adapters covers both git and junit)
v0.0.15         documentation consolidation
v0.0.16         process principles as enforceable obligations
v0.0.17         UX cleanup: rename .md → .yaml in decisions/
v0.0.18         (in progress) onboarding convention, formal-verifier
                 convention, legacy cleanup, decisions/ rename
```

### Open audit debts (from doc/AUDIT-0.0.11.md)

- **D1** — YAML `|` block scalars (deferred to v0.0.18 yaml-block-
  scalars decision). Decision recorded; implementation pending
  (kernel change in lib/codec.ml).
- **D2** — YAML `---` front-matter (same decision; same status).
- **D4** — SHA-256 RFC 6234 vectors. The hand-rolled SHA-256 in
  lib/digest.ml has not been validated. The test is in
  `tests/digest_vectors.ml` as `xfail until Digest is fixed`.
  This is the single biggest residual risk in the kernel.
- **D6** — The 13 obligations in `bootstrap/decision.yaml` have
  manual-only verifiers. The kernel that would auto-verify them
  does not exist yet. This obligation expires when the released
  3.0 kernel successfully checks this repository and its
  conformance corpus (per AGENTS.md §"Bootstrap gate").
- **D8** — `mathc validate` synthesises a coarse diagnostic
  ("missing or invalid required field") without naming the
  specific field. The fix is to promote `Decision.parse_decision`
  to return `Diagnostic.t option` (3.0-beta work).
- **D4 prime** — `result/` directory not in .gitignore. Closed at
  v0.0.18-1 commit f2f527f.

### Adjacent worktree (in progress)

The `time-honesty` worktree (worktree on `time-honesty` branch)
records time estimates via the `ExecutionLog` record
(Domain.execution_log), with classes defined in
`bin/data/time-distribution.yaml` and Cram CLI tests for
`mathc record` / `mathc stats` / `mathc time-estimate` /
`session-start`. This is the human-time honesty layer; it
complements the SHA-256 wall-clock work but does not close the
D4 deficit (the kernel still uses an unverified hand-rolled
SHA-256 for content digests).

The `yaml-block-scalars/v0.0.13` worktree (which is now
merged into `main` since the rename commit) is the same
`bootstrap/yaml-block-scalars.yaml` decision in the new
`decisions/` location. Implementation is pending.

### What is NOT going to be done in v0.0.18

- TLA+, Coq, Alloy tool integration. The convention is
  recorded (Winner-2: `decisions/formal-verifier-conventions.yaml`,
  planned for v0.0.18-4) but no tool is wired into `nix develop`.
  The convention is documentation only.
- Phantom-typed IDs in lib/. The OCaml-Best-Practices §10.4
  plan defers this to 3.0-beta.
- Multi-policy hierarchy. Same deferral.
- Coq proof or TLA spec for the existing 14 invariants. The
  convention says "if you write a formal proof, name it
  `formal/<tool>/<artifact>.<ext>` and reference it from a
  decision's `acceptance` block". No proof has been written.

### How to verify state

Run `./scripts/check.sh` to aggregate shell fixtures and Cram
tests, or `nix develop .#test --command bash -c 'dune test --root .'`
to run the OCaml/Alcotest suite. The conformance runner is at
`tests/conformance.ml`; the structural convention checks are at
`tests/repo_structure.ml`. The P1-P7 process-principles fixture
is at `tests/process_principles.ml` (Alcotest).

The current tag chain is in `git tag --list | grep v3-alpha`.
The current decision chain is in `git log --oneline decisions/`.
The audit chain is in `doc/AUDIT-0.0.11.md`.
