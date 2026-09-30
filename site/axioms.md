# Axioms

> The five normative axioms of math-coding. Each axiom is a
> constraint on what the kernel may say, not a feature the
> kernel ships. The full statements live in `axioms/`; this
> page is the prose summary.

## A0 — Separation

Kinds are distinct; the chain goes one way.

There exist objects of the following kinds:

```text
intent, decision, obligation, change, attestation, observation, revision
```

No two are the same object. An intent is not a decision. A
decision is not an obligation. A change is not an attestation.
The chain goes only one way. A revision does not return to
decision; it supersedes or supersedes-not, decided by an
explicit `Decision.supersedes`.

## A1 — Feedback

Every commitment has a path to an observation.

For every commitment in the system, there exists a path by
which the world tells the system whether the commitment holds.
The path is `commitment -> prediction -> observation ->
revision`. Without an observation the commitment is a wish.

## A2 — Invariants and recovery

Every invariant is paired with a recovery path.

For every invariant `I` there exists a recovery operator `R`
such that if `I` does not hold, the system surfaces a deficit
with an authorized remedy. The remedy is authorized when an
existing principal can execute it. A blocking decision that
names no remedy is itself a deficit.

## A3 — Self-application

The rules govern their own changes.

For every transition `(K_n, P_n) -> (K_{n+1}, P_{n+1})` the
transition satisfies:

```text
Gate_{K_n, P_n}(transition) = Open
Conformance(K_{n+1}) = Pass
Migration(K_n, K_{n+1}) = Pass
VerdictDiff(K_n, K_{n+1}) subset DeclaredSemanticChanges
SelfVerify(K_{n+1}, P_{n+1}) = Pass
```

In particular: `P_{n+1}` MUST NOT contribute to the
authorization of its own adoption. A candidate policy cannot
authorize its own adoption.

## A4 — Care

Owner, consequence, accountability, expiry.

For every commitment, decision, obligation, attestation, or
waiver, the system names:

```text
who benefits if it holds
who suffers if it fails
who is accountable for it
when it will be revisited
```

These four are not negotiable. They are the minimum content of
*caring about an outcome*.

## How the kernel enforces them

| Axiom | Kernel mechanism |
|-------|------------------|
| A0 | Sealed variants for kind tags in `lib/domain.ml`; per-kind digest prefixes; closed `additionalProperties` in JSON Schemas |
| A1 | The `result` enum includes `Inconclusive` and `InfrastructureError` distinctly from `Pass`; waivers carry `expires_at`; operational outcomes allow `absence_means: inconclusive` |
| A2 | The gate variant includes `Blocked` with `remedies`; diagnostics carry `next_actions`; exit codes `0/1/2/3` per `OCAML_BEST_PRACTICES.md §4.3` |
| A3 | The active policy at `decisions/decision.yaml` references this index; constitution changes require migration + conformance; old policy authorizes new policy |
| A4 | `decision.risk.owner`, `obligation.decision`, `assumption.owner`, `waiver.issuer`, `attestation.producer_identity` are required, not optional |

The full enforcement cycle at v3.0.0.20 is described in
[methodology](methodology.html).