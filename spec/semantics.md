# Math-coding 3.0-alpha semantics

## Authoring vs Canonical

Authors submit a compact request:

```yaml
intent: Search remains available when Redis is unavailable.
decision: Fall back to origin.
subjects:
  - capability:search-availability
preserve:
  - Cached responses are no older than 60 seconds.
unknowns:
  - Can origin sustain full fallback traffic?
reconsider_when:
  - Origin error rate exceeds 5%.
```

`mathc draft` compiles it into the canonical intermediate
representation. The agent does not write:

- digests;
- revision identifiers;
- timestamps;
- freshness;
- trust levels;
- derived risk tier;
- gate results.

Invariant: `AgentNeverAuthorsDerivedData`.

## Evaluation

For obligation `o`, change `c`, gate `g`, active policy `p` and
evaluation time `t`:

```text
current(a) iff
  a.revisions resolve
  a.materials_digest equals digest(relevant materials of c)
  a.validity interval contains t
  a.method satisfies Req(p, o, g)
```

```text
Pass(o, c, g) iff
  some a is current and a.result = pass
  and no policy-defined decisive failure
Fail(o, c, g) iff
  some current decisive a reports fail
Unknown(o, c, g) iff
  otherwise
```

The kernel MUST create or report an AssuranceGap for every applicable
`Fail`, `Unknown`, `Stale`, `AtRisk` or `InfrastructureError`.

A valid Waiver changes gate disposition only:

```text
disposition(gap) = waived
```

It MUST NOT change the underlying assurance result.

## Friction

```text
silent < record < ask < block
```

The kernel requires:

- `block` when a gate has a blocking, unwaived AssuranceGap;
- `ask` when a declared unknown can change behavior, obligation, risk,
  recovery, authority or gate disposition;
- `record` for meaningful work covered by active decisions and
  sufficient evidence;
- `silent` only when deterministic checks establish no semantic or
  protected change.

Human or advisor review MAY raise the mode. Only authorized policy
MAY lower a policy default, and only through a valid Waiver.

## Merge Gate

A change MAY merge only if:

1. its schema, references, relations and digests are valid;
2. change coverage is complete under deterministic policy;
3. every required obligation is `pass` or has a valid merge waiver;
4. no non-waivable merge gap exists;
5. required reviews and authorities are present;
6. protected transitions satisfy the prior-policy rule;
7. all kernel-enforced normative changes have positive and negative
   fixtures.

A merge with a Waiver MUST report `open-with-waiver`, never `pass`.

## Release Gate

A revision MAY release only if:

1. every included change satisfies the merge gate;
2. the release artifact digest is attested;
3. all release-required obligations pass;
4. no release-blocking gap is missing, stale, failed, inconclusive or
   infrastructure-error without a waiver;
5. every remaining waiver is explicitly allowed at release, unexpired,
   scoped, has an owner and a follow-up deadline;
6. migration and recovery evidence exists for irreversible or
   protected changes;
7. the released kernel passes the complete conformance corpus;
8. the kernel successfully checks the repository under the policy
   being released.

The release verdict MUST be one of `pass`, `open-with-waiver`, or
`block`.

## Revisions

A new revision MUST:

- reference its immediate predecessor by digest;
- preserve prior accepted revisions;
- state changed fields and resulting verdict changes;
- invalidate attestations whose bounded material changed.

A changed commitment MUST use `supersedes`, not merely `revises`.

## Protected Policy Transition

For transition `(P0 -> P1)`:

```text
Adopt(P0, P1) valid iff
  P0 authorizes the transition
  the authorizing decision was accepted under P0
  P1 contributes no authority to its own adoption
  countercase, fixtures, migration, recovery and verdict diff exist
  K_P0(P1) = allow
```

After adoption, an activation boundary is recorded. Changes before
that boundary evaluate under `P0`; later changes under `P1`.

## Kernel Output

For every rule the kernel emits:

- rule identifier;
- subject and exact revision;
- verdict;
- machine-readable reason;
- artifact references;
- remedies when the verdict blocks a gate;
- retryability;
- autofix safety;
- next actions.

Verdicts are reproducible from canonical inputs and the explicit
evaluation time.
