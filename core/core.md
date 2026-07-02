# Math Coding Core (v2.0)

This document defines the math-coding convention. It is grounded in
eleven theory documents that live in `core/01-Theory/`. Each section
below cites the relevant theory.

The repository itself uses this convention: `examples/self-application/`
verifies that every packet follows the rules defined here. This is
the **fractal property** (ADR-0001).

## How this document is grounded

| Section | Theory |
|---------|--------|
| §Invariants | [theory-01-predicate-invariant](01-Theory/01-Predicate-and-Invariant.md) |
| §State machine | [theory-02-state-machine](01-Theory/02-State-Machine.md) |
| §Temporal properties | [theory-03-temporal-logic](01-Theory/03-Temporal-Logic.md) |
| §Refinement | [theory-04-refinement](01-Theory/04-Refinement.md) |
| §Assumption set | [theory-05-assumption-set](01-Theory/05-Assumption-Set.md) |
| §Verdict | [theory-06-verdict](01-Theory/06-Verdict.md) |
| §Epistemics | [theory-07-epistemic](01-Theory/07-Epistemic.md) |
| §Deprecation | [theory-08-deprecation](01-Theory/08-Deprecation.md) |
| §Proof structure | [theory-09-curry-howard](01-Theory/09-Curry-Howard.md) |
| §Modal obligations | [theory-10-modal-lifecycle](01-Theory/10-Modal-Lifecycle.md) |
| §Confidence calibration | [theory-11-confidence-information](01-Theory/11-Confidence-Information.md) |

## What is a packet

A **packet** is a directory that captures intent before code is
written. The intent is recorded in plain text files following a
fixed structure. A packet may include a formal model, a verifier,
and other artifacts. A packet always includes enough information
for a human or agent to understand what the intent is and to
verify that the resulting code matches it.

A packet is **not** a project. A project contains many packets,
many files, many kinds of documentation. A packet is a single
decision or change, captured in isolation.

A packet that lacks any of the three required files is **not a
packet**. It is a draft. Complete it or delete it.

## Packet structure

A packet is a directory. Required files:

- `packet.yaml` — manifest, conforms to `schemas/packet-manifest.schema.json`
- `task.md` — task description (Problem, Desired outcome, Constraints)
- `assumptions.yaml` — assumptions, conforms to `schemas/assumptions.schema.json`

Recommended files (must be present for `verified` lifecycle):

- `refinement.md` — how the model becomes code (see
  [theory-04](01-Theory/04-Refinement.md))
- `traceability.json` — links between model elements and code
  locations
- `verifier-output.yaml` — verdict of last verification

Optional files:

- `Model.tla`, `Model.cfg` — TLA+ formal model
- `verify.sh` — verifier script
- `verification.yaml` — alternative name for verifier-output
- `decision.md` — for ADRs
- `supersession.yaml` — deprecation metadata
- `theory.md` — for theory documents

## Invariants

Following [theory-01](01-Theory/01-Predicate-and-Invariant.md),
each invariant is a predicate $I : S \to \mathbb{B}$ over the
state space of all possible `packet.yaml` values.

The base verifier checks the following invariants structurally.
Each invariant has a corresponding section in
[theory-01](01-Theory/01-Predicate-and-Invariant.md).

### Structural invariants (verified mechanically)

- `packet-yaml-present` — `packet.yaml` exists
- `packet-yaml-required-fields` — required fields present
- `lifecycle-valid` — `lifecycle` ∈ allowed enum
- `task-md-has-three-sections` — `## Problem`, `## Desired outcome`,
  `## Constraints` in order
- `task-md-has-h1` — starts with `# Title`
- `task-md-has-content` — each section has at least 10 words
- `assumptions-yaml-present` — `assumptions.yaml` exists
- `assumptions-id-pattern` — assumption ids match `A<n>`
- `assumptions-status-valid` — `status` ∈
  {`user-confirmed`, `agent-inferred`, `open`}
- `assumptions-epistemology-valid` — `epistemology` ∈
  {`fact`, `hypothesis`, `judgment`, `unknown`}
- `refinement-md-present` — `refinement.md` exists
- `refinement-md-has-sections` — `refinement.md` has the five
  required sections (state mapping, operation mapping, invariant
  preservation, test obligation, runtime-check)
- `traceability-json-present` — `traceability.json` exists
- `traceability-json-valid` — JSON parses, has `links` array
- `encoding-valid` — UTF-8 LF, no BOM
- `file-naming` — packet files use canonical names

### FSM-dependent invariants (verified per lifecycle)

- `working-requires-artifact` — `lifecycle: working` implies
  `Model.tla` or `verify.sh` exists
- `verified-requires-verdict` — `lifecycle: verified` implies
  `verifier-output.yaml.verdict == VERIFIED`
- `verified-requires-verification-output-fields` — verdict
  record includes `verified_at`, `scope`, `tool`
- `deprecated-requires-deprecated-at` — `lifecycle: deprecated`
  implies `deprecated_at` field present
- `archived-requires-archived-at` — `lifecycle: archived`
  implies `archived_at` field present

## State machine

Following [theory-02](01-Theory/02-State-Machine.md), the
packet lifecycle is a finite state machine:

$$\mathcal{M}_{\text{packet}} = \langle S, s_0, A, \to, I \rangle$$

where:

- $S = \{\text{sketch}, \text{working}, \text{verified}, \text{deprecated}, \text{archived}\}$
- $s_0 = \text{sketch}$
- $A = \{\text{formalize}, \text{verify}, \text{deprecate}, \text{archive}, \text{reopen}\}$
- $\to$ is the transition relation below
- $I$ is the structural invariant above

### Transitions

| from | action | to |
|------|--------|----|
| sketch | formalize | working |
| working | verify | verified |
| working | revert | sketch |
| verified | deprecate | deprecated |
| working | deprecate | deprecated |
| deprecated | archive | archived |
| verified | reopen | working |
| deprecated | reopen | working |

### Forbidden transitions

The following are **never** legal:

| from | to | reason |
|------|----|----|
| sketch | verified | a packet cannot skip the working stage |
| sketch | deprecated | must be formalized first (judgment-based rule) |
| sketch | archived | same as above |
| archived | * | archives are immutable |
| verified | sketch | verified state retains epistemic status even on revision |
| verified | archived | must transition through deprecated first |

### Triggered transitions (extended)

Some transitions are triggered by **external events**, not by
explicit action:

- **Dependency cascade**: if packet $P$ is superseded, all
  packets depending on $P$ revert from `verified` to `working`.
  (See [theory-08](01-Theory/08-Deprecation.md).)
- **Convention version**: if `convention_version` in `core/core.md`
  changes, all `verified` packets revert to `working`. They must
  re-verify against the new invariants.

The verifier does **not** enforce cascades mechanically — they
are documented as a human responsibility in the dependent
packet's `task.md`.

## Temporal properties

Following [theory-03](01-Theory/03-Temporal-Logic.md), the
lifecycle satisfies these LTL properties:

- **Safety**: `[]I_{\text{struct}}` — every reachable state
  satisfies the structural invariant.
- **Liveness (declared, not enforced)**: 
  $\text{lifecycle} \neq \text{"sketch"} \sim> \text{lifecycle} \in \{\text{"verified"}, \text{"deprecated"}, \text{"archived"}\}$.
  Every packet that has been formalized eventually reaches a
  terminal state.
- **Fairness (declared, not enforced)**:
  $WF_{\text{verify}}(\text{lifecycle} = \text{"working"} \Rightarrow
  \text{lifecycle} \in \{\text{"verified"}, \text{"sketch"}\})$.

The verifier checks **safety**. Liveness and fairness are
declared in the FSM definition but not enforced — they require
runtime monitoring over time, which the base verifier does not
do.

## Verdicts

Following [theory-06](01-Theory/06-Verdict.md), each verdict
is the result of attempting to verify $\text{Spec} \models P$.

Five verdicts:

| Verdict | Statement | When |
|---------|-----------|------|
| `VERIFIED` | $\text{Spec} \models P$ proved | The verifier proved the property |
| `NEEDS_REVISION` | $\text{Spec} \not\models P$ (counterexample) | The verifier found a violation |
| `UNVERIFIABLE:TOOL_MISSING` | Tool not available | TLC, tsc, etc. not installed |
| `UNVERIFIABLE:OUT_OF_SCOPE` | Property not amenable to mechanical verification | Human review required |
| `UNVERIFIABLE:DEFERRED` | Data not yet available | Re-attempt when data arrives |

There is no `UNVERIFIABLE:REJECTED`. "Verification is unnecessary"
must be reformulated as a smaller verifiable task.

Each verdict record must include:

- `verdict`: the verdict string
- `verified_at`: ISO date
- `scope`: list of properties verified
- `tool`: tool name and version
- `evidence`: object describing what was checked
- (for UNVERIFIABLE) `human_review`: named reviewer and process

## Epistemics

Following [theory-07](01-Theory/07-Epistemic.md), each
assumption carries an epistemic marker that determines the
agent's behavior.

### Two-layer scheme

**Mandatory (human or explicit decision):**

- `judgment` — design decision; agent must respect, not challenge
- `unknown` — open question; agent must ask user

**Auto-inferred (agent may set):**

- `fact` — agent sets when confident (e.g., source verified)
- `hypothesis` — agent sets when uncertain (default)

### Action protocol

When an agent reads an assumption:

1. If `judgment`: respect, do not challenge.
2. If `unknown`: ask user, do not proceed.
3. If `fact`: verify if possible; downgrade to `hypothesis` if cannot.
4. If `hypothesis`: search for evidence; upgrade to `fact` if found;
   downgrade to `unknown` if contradicted.

Without this protocol, epistemic markers are cosmetic.

## Deprecation

Following [theory-08](01-Theory/08-Deprecation.md), deprecation
is a relation $P_{\text{old}} \perp P_{\text{new}}$ between
packet versions.

Three types of deprecation:

| Type | Effect on dependents |
|------|------------------------|
| `renamed` | Update name, no other change |
| `replaced` | Re-verify, may fail |
| `removed` | Remove from `depends_on` or fail |

Deprecation metadata lives in `supersession.yaml`:

```yaml
supersession:
  supersedes: <old-task-id>
  reason: <why deprecated>
  type: renamed | replaced | removed
  deprecated_at: <ISO date>
```

## Schema validation

Machine-readable JSON Schema files live in `schemas/`:

| Schema | Artifact | Required fields |
|--------|----------|------------------|
| `packet-manifest.schema.json` | `packet.yaml` | yes |
| `assumptions.schema.json` | `assumptions.yaml` | yes |
| `verification-report.schema.json` | `verifier-output.yaml` | yes |
| `refinement.schema.json` | `refinement.md` structure | recommended |
| `traceability.schema.json` | `traceability.json` | recommended |
| `decision.schema.json` | `decision.md` | recommended |

Schemas are themselves verified by
`examples/schema-self-application/`.

## What this document does not cover

- Code style. The project's concern.
- Test framework choice. The convention says "write a verifier";
  it does not say "use pytest".
- Programming language. The convention works for any language.
- Project structure. The convention says "a packet is a directory";
  not where it lives.
- Pull request workflow. The team's concern.
- Continuous integration. The project's concern.
- Specific tools. The convention is conventions only.

## Changes from v1

| v1 | v2 |
|----|----|
| Idempotency not specified | Three levels of idempotency declared |
| FSM without history | `lifecycle_history` field optional |
| "CLI refuses" (no CLI) | Verifier reports regression; no false claim |
| Empty packets pass | `task-md-has-content` invariant |
| Schemas not verified | `schema-self-application/` packet |
| Epistemics as fields | Epistemics as action protocol |
| No temporal scope | `verified_at`, `deprecated_at`, `archived_at` |
| No provenance | `scope`, `tool`, `evidence` required |
| No ownership | `owner` field (recommended) |
| No supersession protocol | `supersession.yaml` defined |