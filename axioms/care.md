# Axiom A4 — Care

> The protocol exists because the people who use it care about what
> they ship. The fifth principle is the simplest: do not make them
> pretend to care.

## Statement

For every commitment, decision, obligation, attestation, or waiver,
the system MUST identify:

```text
who benefits if it holds
who suffers if it fails
who is accountable for it
when it will be revisited
```

These four are not negotiable. They are the minimum content of *caring
about an outcome*.

## What this axiom forbids

- A decision with no owner.
- An obligation with no consequence_if_false.
- A waiver with no `compensating_controls`.
- A review with no `minimum_independence`.
- An attestation with no `producer_identity` or no `environment`.

## Where this axiom lives in the codebase

- `spec/domain.md` — `decision.risk.owner`, `assumption.owner`,
  `obligation.decision`, `waiver.issuer`, `attestation.producer_identity`.
- `spec/constitution.md` — invariant 11 (Waiver bounds).
- `lib/domain.ml` — these fields are required, not optional.
- `OCAML_BEST_PRACTICES.md` §2.4 (Tagged arguments) and §2.6 (Records
  over tuples) ensure these fields cannot be silently dropped.

## Counter-example that would violate this axiom

An `assumptions` entry that says "the system is fast" with no
`owner` and no `consequence_if_false`. The agent has nothing to test,
nothing to monitor, nothing to escalate.

The fix:

```yaml
- id: response-latency-acceptable
  state: assumed
  statement: 95% of search responses complete within 200ms.
  owner: team:search
  consequence_if_false: |
    Customer-visible latency regression; investigate via
    dashboards/latency.
  review_on:
    - date: 2026-12-01
```

## Counter-example that would silently violate this axiom

An `obligation` whose `acceptance` lists a `verifier` that no one
maintains. The agent has no one to ask, no one to escalate to, no
one to hold responsible when the check fails silently.

## What an agent must do when the axiom seems to fail

1. Identify the missing field (owner, consequence, expiry, principal).
2. Ask the user or the accountable authority to provide it.
3. If the question cannot be answered, decline to record the decision:
   "I cannot tell you who will be hurt by this decision failing, so I
   cannot in good faith record it."
4. Never substitute a placeholder owner like `human:tbd` or
   `team:unassigned`.
