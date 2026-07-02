# Changelog

All notable changes to math-coding are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [2.0.0] - 2026-07-02

### Initial release with mathematical foundation

This is the first release of math-coding as a self-applying,
mathematically-grounded convention. The methodology is
ready for adoption.

#### Added

##### Theory (8 documents in core/01-Theory/)

- `01-Predicate-and-Invariant.md`: invariants as predicates
  $I : S \to \mathbb{B}$, safety as
  $\forall s \in \text{Reachable}(s_0) : I(s)$
- `02-State-Machine.md`: FSM as tuple
  $\langle S, s_0, A, \to, I \rangle$, reachability via
  smallest fixed-point
- `03-Temporal-Logic.md`: LTL operators `[]`, `<>`, `~>`,
  `WF`, `SF` with formal semantics
- `04-Refinement.md`: refinement map
  $R : S_{\text{impl}} \to S_{\text{spec}}$, stuttering
  equivalence
- `05-Assumption-Set.md`: assumptions as axioms
  $\Sigma \vdash \text{Spec}$
- `06-Verdict.md`: verdicts as theorem statements
  $\text{Spec} \models P$
- `07-Epistemic.md`: belief updates
  $B : \text{Prop} \times \text{Agent} \to [0,1]$, epistemic
  action protocol
- `08-Deprecation.md`: supersession
  $P_{\text{old}} \perp P_{\text{new}}$, cascading protocol

##### Convention (core/core.md)

- Each section cites its formal theory
- Packet lifecycle FSM with explicit forbidden transitions
- Triggered transitions: dependency cascade, convention
  version change
- Verdicts with provenance (verified_at, scope, tool, evidence)
- 5 v1 lies fixed: idempotency levels, FSM history, false CLI
  claim, packet emptiness, schema validation

##### Schemas (6 files in schemas/)

- `packet-manifest.schema.json`: packet.yaml with extended
  fields (owner, priority, tags, lifecycle_history, etc.)
- `assumptions.schema.json`: epistemic markers with
  confidence field
- `verification-report.schema.json`: verdicts with
  provenance fields
- `traceability.schema.json`: links with kind enum
- `refinement.schema.json`: refinement.md section structure
- `decision.schema.json`: decision.md (ADR) structure

##### Agents (agents/agents.md)

- Epistemic action protocol as a table
- Two-layer scheme: mandatory (judgment, unknown) vs
  auto-inferred (fact, hypothesis)
- Belief update protocol
- Default values for substrate and priority

##### Verifier (examples/self-application/verify-consistency.sh)

- Plain shell, no Python
- 14 structural invariants mechanically checked
- FSM transition validation
- Epistemic-marker enum validation
- Refinement.md section validation
- Traceability.json validation
- Provenance recording in verifier-output.yaml

##### Schema validator (examples/schema-self-application/verify-schemas.sh)

- Meta-verification of JSON Schema files
- Validates $schema, type, properties, version, balanced
  braces

##### Example (examples/modal-dialog/)

- TLA+ model of modal dialog state machine
- 5 states: closed, opening, open, confirming, closing
- 4 safety invariants: I1-I4
- 2 liveness properties (declared, not all enforced)
- TypeScript implementation matching the model
- Runtime tests verifying the invariants

##### ADRs (10 in adr/)

- `0001-fractal-property`: convention applies to itself
- `0002-decision-gate`: 4-assumption threshold
- `0003-plain-text-and-git`: minimum external dependencies
- `0004-no-cli`: shell commands only
- `0005-soft-conventions`: verifier reports, not blocks
- `0006-self-applying-repository`: all files belong to packets
- `0007-theory-as-foundation`: theory is part of core
- `0008-epistemic-protocol`: markers drive agent behavior
- `0009-extended-packet-fields`: owner, priority, tags, history
- `0010-extended-fsm-triggers`: dependency cascade, version

##### CI and integrations

- `.github/workflows/verify.yml`: runs on every push and PR
- `docs/integrations/github-pr.md`: PR template and required
  checks
- `docs/integrations/linear.md`: bidirectional sync with
  Linear issues
- `docs/integrations/github-actions.md`: extending CI with
  TLC, tsc, pytest
- `docs/integrations/cursor.md`: `.cursorrules` for Cursor
  agent

##### Agent integrations

- `.cursorrules`: instruction file for Cursor IDE agent
- `.opencode/AGENTS.md`: instruction file for opencode
- `.opencode/skills/math-coding/SKILL.md`: full skill for
  opencode with mathematical references
- `.opencode/commands/mathpacket`: slash command to create
  packets
- `.opencode/commands/verify`: slash command to run the
  verifier

#### Statistics

- 30 packets in this release
- 8 theory documents
- 6 JSON Schema files
- 10 ADRs
- 13 development artifacts

#### Verified

- `sh examples/self-application/verify-consistency.sh` →
  OK: all packets follow conventions
- `sh examples/schema-self-application/verify-schemas.sh`
  → OK: 6 schemas valid
- 0 Python references in shell scripts or YAML files
- 0 CRLF line endings

## [1.0.0] - Historical

The v1 series of math-coding lived in `~/Desktop/math-coding-new/`
and is preserved as the historical snapshot. It used the same
packet structure but lacked the mathematical foundation.

The v1 schema is documented in
[`docs/v1-schema-notes.md`](docs/v1-schema-notes.md) for
migration purposes.

The Force-TLA+ edition is at
[`11111000000/math-coding-force-tla`](https://github.com/11111000000/math-coding-force-tla).

[Unreleased]: https://github.com/11111000000/math-coding/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/11111000000/math-coding/releases/tag/v2.0.0
[1.0.0]: https://github.com/11111000000/math-coding/releases/tag/v1.0.0
