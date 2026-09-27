# Math-coding 3.0-alpha domain

## Common Form

Every artifact carries:

```text
schema
kind
id
revision (revision DAG identity)
created_at (canonical UTC timestamp)
actor (declared principal)
canonical_digest (computed externally)
```

`revision` is content-derived. A stable integer may be displayed but is
not authoritative. References use `(kind:id@revision_digest)` or
`(kind:id@parent_digest)` for navigation; floating references are
forbidden in attestations, waivers and protected transitions.

## Decision

A Decision records an accountable commitment.

Required fields:

- `intent` (text, source);
- `commitment` (text);
- `scope` (paths, capabilities, interfaces, artifacts);
- `outcomes` (array of `{id, statement}`);
- `assumptions` (array of `{id, state, statement, owner,
  consequence_if_false, review_on}`);
- `obligations` (array of Obligation, may be inline);
- `reversal` (array of `{signal, condition, action}`);
- `risk` (declared_triggers, owner);
- `relations` (supersedes, addresses, ...).

The final risk tier and the canonical digest are derived.

A Decision is required only when a change introduces a new commitment,
tradeoff, assumption, public contract, architecture choice or policy
change.

## Obligation

An Obligation has a human-readable claim and a machine-checkable
acceptance predicate.

```yaml
id: stable-idempotency-key
decision: payment-retry
outcome: at-most-one-charge

claim: |
  Every attempt for one payment intent uses the same idempotency key.

subjects:
  - capability:payment-settlement
  - path:src/payments/gateway/**

acceptance:
  all:
    - verifier: payments-timeout-after-charge
      result: pass
    - review:
        authority: payments-owner
        minimum_independence: different-principal

phase: pre-merge
```

Allowed kinds: `invariant`, `acceptance`, `recovery`, `operational`.

Allowed phases: `pre-merge`, `pre-release`, `post-release`.

## Change

A Change identifies a concrete repository transition.

```yaml
id: pr-481
base_commit: abc123
candidate_tree: sha256:41aa...
files:
  - path: src/payments/gateway/retry.ml
    digest: sha256:92ff...
materials:
  - kind: source
    path: src/payments/gateway/**
    digest: sha256:...
  - kind: lockfile
    path: opam.locked
    digest: sha256:...
  - kind: toolchain
    id: ocaml-5.4
    digest: sha256:...
decisions:
  - payment-retry@rev:41aa92
```

`Change` is produced by Git/forge adapters and policy rules; agents do
not author it directly.

## Attestation

```yaml
schema: math-coding/attestation-3.0-alpha
kind: attestation
id: sha256:7e91...
subject:
  decision:
    id: payment-retry
    revision: rev:41aa92
  obligation:
    id: stable-idempotency-key
  candidate_tree: sha256:41aa...
  materials_digest: sha256:21de...
producer:
  identity: ci:payments-tests
  run: https://ci.example/runs/9182
environment_class: linux-x86_64/ocaml-5.4
result: pass
issued_at: 2026-09-26T12:00:00Z
evidence_digest: sha256:f61b...
signature:
  format: dsse
  key_id: payments-tests-2026
  value: ...
```

Allowed results: `pass`, `fail`, `inconclusive`,
`infrastructure-error`.

A signature proves credential possession, not truth.

## Assurance Gap

```yaml
id: MC-GATE-203
kind: missing-evidence
subject: change:pr-481
obligation: payment-retry/stable-idempotency-key
state: missing
cause:
  - src/payments/gateway/retry.ml changed
  - payment-side-effect trigger applies
  - policy requires duplicate-delivery evidence
remedies:
  - kind: run
    verifier: payments-timeout-after-charge
  - kind: review
    authority: payments-owner
  - kind: waive
    authority: payments-owner
```

State is derived. `missing`, `stale`, `failed`, `inconclusive`,
`infrastructure-error`, `waived` are distinct.

## Waiver

```yaml
schema: math-coding/waiver-3.0-alpha
kind: waiver
id: auth-emergency-waiver-921
policy_id: repository-policy
rule: payment-side-effect/duplicate-delivery
subject: change:pr-481
scope:
  paths: ["src/payments/gateway/retry.ml"]
issuer: human:payments-lead
issued_at: 2026-09-26T12:00:00Z
expires_at: 2026-09-27T12:00:00Z
reason: Gateway sandbox is unavailable during an active incident.
unverified_obligation: stable-idempotency-key
compensating_controls:
  - Automatic retry remains disabled by default.
```

## Relations

Allowed relations:

```text
revises
supersedes
refines
depends-on
conflicts-with
addresses
implements
verifies
```

`revises`, `supersedes`, `refines`, `depends-on` are acyclic.
`conflicts-with` is symmetric.

## Identity and Trust

Identities may come from:

- local Git identity (declared, weak);
- forge identity (declared, attested for review);
- OIDC subject tokens (attested);
- signing keys referenced by policy (declared, attested).

Trust is policy-derived. Attestations do not declare their own trust.

Trust levels (ordered):

```text
untrusted < authenticated < delegated < authoritative
```

## ExecutionLog

`ExecutionLog` is the observation that closes the time-honesty
feedback loop (axiom A1). It records one of three observable
scales named in AGENTS.md §Honest time reporting:

```text
wall-clock-minutes   real seconds/minutes from session start to now
token-budget         prompt + completion tokens consumed
step-count           tool calls / reasoning rounds performed
```

An `ExecutionLog` is observation, not certification (A0:
`attestation != observation`). It is therefore a distinct kind
from `Attestation`. The `lib/domain.ml kind` enum is intentionally
unchanged — adding `ExecutionLog` there would conflate two
semantics; instead ExecutionLog is a separate record
(`Domain.execution_log`).

```yaml
id: sha256:deadbeef...
kind: execution_log
scale: wall-clock-minutes   # token-budget | step-count
value: 12.5                 # wall-clock-minutes; integer for step-count
observed_at: 2026-09-26T12:00:00Z
observed_by: human:devname  # or runtime harness identity
source_decision: time-honesty@rev:2b853ca
```

`ExecutionLog.scale` and `ExecutionLog.value` MUST name a scale
the agent can defend (A1: every commitment has a path to an
observation). A `Decision.time.estimate` whose corresponding
`ExecutionLog.value` lands outside the reference-class percentile
band opens an `AssuranceGap` of kind `time-estimate-exceeded`
(proposed; not implemented in this revision).

No `ExecutionLog` is constructed by the bootstrap parser. The
runtime harness, when implemented, is the only writer. Agents
read but never instantiate.

## Relations (extended)

Relations remain as listed above. `ExecutionLog` does not add
new relation types in this revision.

## Identity and Trust (extended)

`ExecutionLog.observed_by` may carry any `id` from the same
identity classes as other artifacts. A runtime harness writes
under its own forge identity. The trust level of an ExecutionLog
is **declared** by the writer until the kernel can verify the
harness signature; an unsupported ExecutionLog is therefore
`Untrusted` until promoted.
