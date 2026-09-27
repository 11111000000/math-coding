---
schema: math-coding/3.0-alpha
id: process-principles
revision: 2

intent: |
  Lock down the seven process principles P1-P7 recorded in
  ROADMAP.md §"Process principles (binding on all agents)" as
  formal obligations under the active policy (bootstrap-v3).
  Today those principles are documentation-only: a new agent can
  read ROADMAP.md and skip them, because no machine check fires
  when one is violated. The yml-block-scalars and priority-drift
  sessions (D1, D2, D3) showed that principle-drift is a real
  failure mode: decisions were retro-fitted after the kernel
  changed, and a fixture appeared in `tests/fixtures/` without a
  paired decision in `bootstrap/`. Recording the principles as
  obligations makes them visible in PACKAGES.md; the checkable
  subset (P1, P2, P5, P6, P7) is asserted by the new fixture
  `tests/fixtures/process-principles.sh`; the non-checkable
  subset (P3, P4) is recorded as manual-acceptance obligations
  with the explicit acknowledgement that they cannot be
  machine-checked (per AGENTS.md §"Bootstrap gate" — "Process
  principles cannot be machine-checked; they are honest
  declarations of how the human and agents work").

commitment: |
  Each of P1-P7 is recorded as a separate obligation in this
  decision file. For P1, P2, P5, P6, P7 the obligation's
  acceptance predicate references
  `tests/fixtures/process-principles.sh` (one shared fixture;
  each check is its own labelled sub-section of the fixture
  output). For P3, P4 the obligation carries
  `evidence: manual-acceptance` and names the human maintainer
  as the reviewer, because the principle is a declaration of
  agent conduct, not a property of the tree.

  The fixture `tests/fixtures/process-principles.sh` is
  registered with `./scripts/check.sh` via the existing glob
  (`tests/fixtures/*.sh`). It exits 0 when all checkable
  principles hold and exits 1 with the offending principle name
  on the first violation. The fixture must be a real check,
  not a self-referential pass (P7).

scope:
  capabilities:
    - process-principles-enforced
  paths:
    - "bootstrap/process-principles.md"
    - "tests/fixtures/process-principles.sh"
    - "PACKAGES.md"
    - "doc/AUDIT-0.0.11.md"
  exclusions:
    - "ROADMAP.md"
    - "lib/**"
    - "bin/**"
    - "spec/**"
    - "schemas/**"

outcomes:
  - id: principles-recorded-as-obligations
    statement: |
      Each of P1-P7 is a discrete obligation in
      bootstrap/process-principles.md with its own claim,
      countercase (where applicable), and acceptance predicate.
      The obligations are visible in PACKAGES.md under
      "Bootstrap packages (by file)" once that table is updated.
  - id: checkable-principles-asserted-by-fixture
    statement: |
      tests/fixtures/process-principles.sh asserts P1, P2, P5,
      P6, P7 by reading the repository state and exits 1 with
      the principle name on any violation. P3 and P4 are
      recorded as manual-acceptance obligations and are NOT
      asserted by the fixture, with the rationale recorded
      alongside the obligation.

countercase: |
  "These principles are already documented in ROADMAP.md; the
  decision duplicates them without changing behavior." The
  counterargument fails for three reasons:
  (a) ROADMAP.md is a priority queue and process-norms
      document; it is read once on agent entry and not re-read on
      every commit. An obligation in `bootstrap/` is read by
      every fixture invocation and surfaced in PACKAGES.md, so a
      principle listed there is visible to every new agent.
  (b) The checkable subset (P1, P2, P5, P6, P7) is asserted by
      a fixture that runs on every `./scripts/check.sh`; the
      principle is enforced, not just stated.
  (c) ROADMAP.md names the principles but does not bind them
      to a specific failure mode or remediation. An obligation
      carries a `claim`, a `countercase`, and an `acceptance`
      predicate; the principle becomes actionable rather than
      advisory.

  "P3 (time-box) and P4 (merge order) cannot be enforced, so
  the decision adds obligations the kernel can never check."
  The counterargument fails: per AGENTS.md §"Bootstrap gate",
  process principles that are not machine-checkable are
  acceptable as honest declarations of conduct. The decision
  records them with `evidence: manual-acceptance` and names the
  reviewer. This is not a regression; it is the same honesty
  norm that `bootstrap/decision.yaml` already applies to its
  own obligations (e.g., `preserve-v2`, `conformance-coverage`).

  "If a fixture must catch every violation, the fixture
  becomes brittle and is skipped." The counterargument fails:
  the fixture is structural (frontmatter fields exist;
  obligation IDs are referenced; cram files are absent;
  scripts/check.sh is executable). None of these checks
  produce false positives on the current tree; all of them
  fail on a hypothetical violation. The fixture is the
  smallest check that catches the P1-P7 failure modes.

assumptions:
  - id: frontmatter-schema-is-stable
    state: assumed
    statement: |
      The required frontmatter fields (schema, id, revision)
      and the required body sections (intent, commitment,
      scope, obligations, risk) are stable across all current
      and future decision files. A future revision of this
      decision may extend the required-fields list (e.g., to
      add `outcomes`), but no current file would fail such an
      extension without an explicit reason.
    owner: human:maintainer
    consequence_if_false: |
      If a future revision adds a required field that current
      files lack, the fixture will report every existing file
      as failing. That is the intended behavior (a forcing
      function), not a regression; the parent task that
      proposes the new field must update every file in the
      same commit.
    review_on:
      - signal: frontmatter-schema-extends
  - id: meta-policy-skipped-by-fixture
    state: assumed
    statement: |
      bootstrap/decision.yaml (the active policy),
      bootstrap/obligations.yaml (the cross-reference
      aggregator), and bootstrap/rationale.md (free-form
      rationale prose) are NOT subject to the P1 schema check.
      They carry their own formats (the active policy has no
      `obligations:` block; the aggregator uses a different
      schema; rationale.md is documentation, not a decision).
      The fixture skips these by name.
    owner: human:maintainer
    consequence_if_false: |
      If a new meta-file appears in bootstrap/ without a
      schema check exemption, the fixture must be updated to
      either skip the new file or include it in the check.
      This is a maintenance contract, not a bug.
    review_on:
      - signal: new-bootstrap-meta-file-added
  - id: manual-acceptance-is-honest
    state: assumed
    statement: |
      For P3 and P4, manual-acceptance is not a euphemism for
      "skip"; it means the human maintainer (named in
      `risk.owner`) reviews adherence to the principle on
      every change. A waiver mechanism for P3/P4 violations
      does not exist (and per A3 self-application, would
      itself require a decision under the current rules).
    owner: human:maintainer
    consequence_if_false: |
      If the human maintainer becomes unavailable, the
      principle has no replacement reviewer; the principle
      either lapses (no enforcement, no acceptance) or the
      kernel-side enforcement must be implemented. A future
      revision can extend the fixture to assert structural
      proxies for P3/P4 (e.g., commit timestamps for P3,
      merge-order in commit messages for P4) without
      changing the principle itself.
    review_on:
      - signal: maintainer-rotation

obligations:
  - id: p1-decisions-before-kernel-changes
    outcome: principles-recorded-as-obligations
    claim: |
      A change to `lib/*.ml`, `spec/*.md`, `schemas/*.json`,
      or `bin/Mathc.ml` ships with a `bootstrap/*.yaml` (or
      `.md`) decision under the active policy. The acceptance
      proxy is structural: every non-meta decision file in
      `bootstrap/` has the required frontmatter fields
      (`schema`, `id`, `revision`) and the required body
      sections (`intent`, `commitment`, `scope`, `obligations`,
      `risk`). A future file added to `bootstrap/` that
      omits any required field violates P1 and trips the
      fixture.
    acceptance:
      all:
        - verifier: tests/fixtures/process-principles.sh
          result: pass
  - id: p2-decisions-paired-with-fixtures
    outcome: principles-recorded-as-obligations
    claim: |
      Every obligation in a non-meta decision file references
      a test fixture via `acceptance.all[].verifier`, either
      as a path under `tests/fixtures/*.sh` (file exists), a
      kernel-test reference (`tests/conformance.ml ...`), or
      an explicit manual-style verifier (e.g., `text-scan-`,
      `cram-fixture-`, `script-runs-and-is-deterministic`,
      `dune test`, `manual-`, `review`, `practice-review`,
      `mathc-`). The check is structural: every obligation
      declares a verifier; the verifier is either present
      (file exists or kernel-test reference is well-formed)
      or is in the manual-style prefix list. An obligation
      with no verifier declaration, or with a verifier
      pointing to a non-existent fixture file, trips the
      fixture.
    acceptance:
      all:
        - verifier: tests/fixtures/process-principles.sh
          result: pass
  - id: p3-time-box-on-detailed-work
    outcome: principles-recorded-as-obligations
    claim: |
      If a single change exceeds 10 minutes without a passing
      build, the agent switches to WIP commit + decision-record
      + next task. This principle is an honest declaration of
      agent conduct (AGENTS.md §"Bootstrap gate"); the kernel
      cannot measure wall-clock against a single session.
      Acceptance is manual: the human maintainer reviews
      commit messages and the `git log --since=<session-start>`
      sequence on demand.
    evidence: manual-acceptance
    owner: human:maintainer
  - id: p4-merge-order-time-budget-kernel
    outcome: principles-recorded-as-obligations
    claim: |
      When multiple parallel agents commit, integration
      follows the order: bootstrap/*.yaml (decisions) ->
      tests/fixtures (additive) -> lib/ pure helpers ->
      bin/Mathc.ml (dispatcher) -> build artifacts. This
      principle is an honest declaration of agent conduct;
      the kernel cannot observe the merge order without
      rewriting git history. Acceptance is manual: the human
      maintainer reviews `git log --graph` and the merge
      pull-request ordering on demand.
    evidence: manual-acceptance
    owner: human:maintainer
  - id: p5-cram-retired-shell-fixtures-only
    outcome: checkable-principles-asserted-by-fixture
    claim: |
      `tests/cram/*.t` were retired in `dc78bcd`. New CLI
      tests go in `tests/fixtures/*.sh`. The acceptance proxy
      is structural: `tests/cram/*.t` does not exist; the
      `tests/dune` file documents the cram retirement. A
      future commit that adds `tests/cram/*.t` violates P5
      and trips the fixture.
    acceptance:
      all:
        - verifier: tests/fixtures/process-principles.sh
          result: pass
  - id: p6-pre-commit-verification
    outcome: checkable-principles-asserted-by-fixture
    claim: |
      Before `git commit`, the agent runs
      `./scripts/dev verify`, which in turn runs
      `scripts/check.sh`. The acceptance proxy is
      structural: `scripts/check.sh` exists, is executable,
      and is the aggregator the fixture itself uses. A
      future commit that removes the file or strips the
      executable bit violates P6 and trips the fixture.
    acceptance:
      all:
        - verifier: tests/fixtures/process-principles.sh
          result: pass
  - id: p7-honesty-in-fixture-assertions
    outcome: checkable-principles-asserted-by-fixture
    claim: |
      A passing fixture must assert SOMETHING meaningful.
      Self-referential tautologies (e.g., "the fixture exits
      0" asserting on its own exit code, or matching a
      captured failure output verbatim) violate the principle.
      The acceptance proxy for P7 is meta: this fixture
      (process-principles.sh) is itself a check, and the
      other 26 fixtures it does not subsume are checked
      independently by `./scripts/check.sh`. The fixture
      does NOT assert "this fixture exits 0" as its only
      statement; it reads repository state and compares it
      against structural invariants. A future revision that
      weakens the fixture to a no-op self-check would itself
      require a new decision (a forbidden self-amendment
      per A3 self-application).
    acceptance:
      all:
        - verifier: tests/fixtures/process-principles.sh
          result: pass

reversal:
  - signal: kernel-can-enforce-p3-p4
    action: |
      supersede-with-kernel-side-p3-p4-checks (e.g., commit
      timestamps for P3, merge-order scan for P4) without
      changing the principle itself.
  - signal: frontmatter-schema-extends
    action: |
      update-tests/fixtures/process-principles.sh to require
      the new field, and update every decision file in the
      same release.

risk:
  declared_triggers:
    - process-principle-drift
    - manual-acceptance-without-reviewer
  owner: human:maintainer

relations:
  addresses:
    - bootstrap-v3
    - ROADMAP.md#process-principles-binding-on-all-agents
  supersedes: []
  superseded_by: []