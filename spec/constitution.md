# Math-coding 3.0-alpha constitution

## Scope

Math-coding is an assurance protocol. It links intent, decisions,
obligations, changes, attestations and revisions. It MUST NOT claim to
prove software correctness.

The normative chain is:

```text
intent -> decision -> obligation -> change -> attestation -> revision
```

`MUST`, `MUST NOT`, `SHOULD`, `MAY` are normative.

## Authority Boundary

The kernel determines only predicates computable from canonical
repository artifacts, declared policy and an explicit evaluation time.

The kernel MAY determine:

- schema, identifier and reference validity;
- relation typing and graph acyclicity;
- revision DAG structure;
- digest equality, freshness and expiry;
- presence of required fields, relations, fixtures and attestations;
- satisfaction of mechanically declared gate predicates;
- authorization by the currently active policy.

The kernel MUST NOT determine:

- whether an intent is desirable;
- whether a decision is wise;
- whether obligations are complete;
- whether a countercase is the strongest practical countercase;
- whether a risk, reversal or waiver is acceptable;
- whether a program semantically satisfies an obligation beyond the
  scope of its attestations;
- whether an actor is substantively accountable merely because an
  identifier or signature exists.

An advisor statement is a declaration, never authority, review,
observation or evidence.

## Epistemic Separation

Source classes are distinct:

```text
declared != derived != attested != reviewed != observed
```

A result MUST NOT be promoted to a stronger class without an artifact
establishing that class.

```text
unknown != pass
waived != pass
reviewed != observed
```

Every assurance claim MUST be bounded by subject, obligation, inputs,
environment, implementation digest, method and time.

## Proportionality

The protocol imposes the least sufficient friction:

```text
silent < record < ask < block
```

The advisor MAY raise friction. It MUST NOT lower kernel-required
friction.

A block MUST identify:

- the governing rule;
- the affected subject;
- the blocking reason;
- at least one practical remedy executable by an available authority.

## History and Correction

Normative artifacts MUST be append-only after acceptance. Correction
MUST create a revision or a superseding artifact; it MUST NOT erase
accepted history.

`revises` updates representation while preserving identity.
`supersedes` replaces a commitment with a different commitment. They
MUST NOT be conflated.

## Waivers

A waiver is explicit, scoped, authorized, expiring acceptance of one
AssuranceGap. A waiver:

- MUST identify one gap, authority, rationale, scope, issue time,
  expiry and recovery or follow-up action;
- MUST NOT convert `fail`, `unknown` or `missing` into `pass`;
- MUST NOT outlive its expiry or the artifact revisions it names;
- MUST NOT waive a constitutionally non-waivable rule;
- MAY permit a gate only when the active policy marks that gap class
  waivable at that gate.

## Self-Application

Changes to the constitution, schemas, canonicalization, kernel, gate
rules, authority rules or waiver rules are protected policy
transitions. A protected policy transition MUST include:

1. a decision accepted under the previously active policy;
2. the strongest practical countercase;
3. positive and negative conformance fixtures;
4. a migration path;
5. a rollback or forward-recovery path;
6. an explicit list of changed verdicts;
7. authorization required by the previously active policy.

A candidate policy MUST NOT authorize its own adoption.

## Kernel Invariants

For repository state `R` and active policy `P`, `K(R, P, now)` is the
deterministic kernel result.

1. Determinism: equal canonical inputs and equal evaluation time
   produce equal verdicts.
2. Referential integrity: every relation endpoint MUST resolve.
3. Type safety: every relation MUST use an allowed source and target
   type.
4. Identity: `(kind, id, revision)` MUST be globally unique.
5. Immutability: an accepted artifact revision MUST retain its
   canonical digest.
6. Revision DAG: revisions MUST have parent digests and form a DAG.
7. Supersession order: `supersedes` MUST be irreflexive and acyclic.
8. Evidence binding: an attestation MUST name exact artifact
   revisions and material digests.
9. Freshness: a changed material digest MUST invalidate dependent
   attestations unless the method proves digest independence.
10. Honest status: missing, stale, failed, inconclusive, infrastructure
    error, waived and passed states MUST remain distinguishable.
11. Waiver bounds: a waiver MUST apply only to its named gap, scope,
    revisions, gate and validity interval.
12. Prior authority: a protected transition MUST be authorized by the
    previously active policy.
13. Fixture coverage: every kernel-enforced MUST MUST have at least one
    accepting and one rejecting conformance fixture.
14. Exit honesty: a blocking verdict MUST produce nonzero exit code.
