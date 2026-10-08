# Axiom A2 — Invariants and Recovery

> A system that cannot fail visibly cannot be trusted. A system that can
> fail visibly but cannot be recovered from is a trap. Math-coding's
> third principle is: every invariant is paired with a recovery path,
> and every state is paired with the operation that produced it.

## Statement

For every invariant I of the system, there exists a *recovery
operator* R such that:

```text
if I holds
   then the system may proceed
   else the system MUST surface a deficit with an authorized remedy
```

The recovery operator R is *authorized* when at least one of:

- the current principal can execute it;
- a named other principal with sufficient authority can execute it;
- a documented automated rollback exists.

The remedy is *finite* when it can be expressed as a finite sequence of
operations bounded by time and authority.

## What this axiom forbids

- A blocking decision that names no remedy. (See
  `spec/constitution.md` invariant 7.)
- A remedy that names an authority that does not exist in the project
  registry.
- A recovery that requires rewriting all of history. (Supersession
  produces a new commit; it does not erase an old one.)
- A state whose history is unknown. (Unknown provenance is itself a
  deficit; see `OCAML_BEST_PRACTICES.md` §3.3.)
- A diagnostic that the kernel cannot map to a gate state.

## Where this axiom lives in the codebase

- `spec/constitution.md` — invariants 4 (Type safety), 5 (Immutability),
  6 (Revision DAG), 7 (Corrective closure), 10 (Honest status), 11
  (Waiver bounds), 14 (Exit honesty).
- `spec/semantics.md` — Merge gate and Release gate rules.
- `lib/domain.ml` — `gate` variant includes `Open`, `Open_with_waiver`,
  `Blocked`. `Open_with_waiver` requires an authorized waiver; `Blocked`
  requires at least one remedy.
- `lib/diagnostic.ml` — `remedies : (string * string) list` (to be
  promoted to a `remedy = { kind; value }` record per
  `OCAML_BEST_PRACTICES.md` §2.6).
- `OCAML_BEST_PRACTICES.md` §4.3 — exit codes 0/1/2/3.

## Formalization

The fourteen invariants live in [`spec/algebra-3.2.md`](../spec/algebra-3.2.md)
§19. Six of the fourteen are stated below verbatim; together they
span determinism, identity, the revision DAG, status honesty, prior
authority, fixture coverage, and the exit-honesty rule that pairs
with this axiom's recovery operator.

```text
(I1)  ∀ c, p, t₁=t₂: gate(c, p, t₁, ∅) = gate(c, p, t₂, ∅)
(I2)  ∀ ref: resolve(ref) ≠ ∅
(I6)  ∀ rev: parents(rev) < rev ∧ acyclic(revisions)
(I10) Pass ≠ Unknown ≠ Waived ≠ Reviewed ≠ Observed
(I12) ∀ protected τ: authorized_by(previous(P))
(I13) ∀ MUST ∈ kernel: ∃ f⁺, f⁻ ∈ Fixtures
(I14) gate = Blocked ⇒ exit ≠ 0
```

The pair (I13, I14) is the formal core of this axiom: every
`MUST` in the kernel must have both a positive fixture \(f^+\) and
a negative fixture \(f^-\) (I13), and a blocked gate must produce
a non-zero exit code (I14). The remedy operator \(R\) required by
this axiom is exactly the non-zero-exit obligation written into I14:
"a blocking decision that names no remedy" violates both prose and
formal invariant.

## Counter-example that would violate this axiom

A merge gate that returns `Blocked` with `causes: ["missing review"]`
and `remedies: []`. The agent cannot proceed; the user cannot either.

The correct shape is:

```yaml
causes:
  - review obligation has no attestation
remedies:
  - kind: run
    verifier: mathc-request-review
  - kind: waive
    approver: human:domain-owner
```

## Counter-example that would silently violate this axiom

A diagnostic with `remedies` naming `human:security-board` when the
project registry has no such principal. The kernel should look up
authority and refuse to emit a remedy that no one can execute.

## What an agent must do when the axiom seems to fail

1. Verify the remedy names a principal that exists.
2. Verify the principal has authority for this class of remedy
   (e.g., security reviews need security authority).
3. If no remedy can be made authorized, classify the deficit as
   `Blocked` with `causes: ["no authorized remedy exists"]`. This is
   itself a deficit that requires escalation.
4. Never emit a synthetic remedy (`unassigned`, `TBD`, `auto`,
   `system`). A synthetic remedy is a placeholder, not a remedy.
