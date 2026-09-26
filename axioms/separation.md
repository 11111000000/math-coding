# Axiom A0 — Separation

> The error of any real system starts with conflating two things that
> were treated as the same. Math-coding's first principle is therefore
> not a feature. It is the insistence on keeping certain pairs apart.

## Statement

There exist objects of the following kinds:

```text
intent
decision
obligation
change
attestation
observation
revision
```

No two of them are the same object. Specifically:

```text
intent   != decision
decision != obligation
obligation != change
change   != attestation
attestation != observation
observation != revision
```

And no object of any one kind *implies* an object of another kind:

- an intent is not a decision (a user can want things that are not
  committed to);
- a decision is not an obligation (a commitment is not yet a falsifiable
  property);
- an obligation is not a change (a property is not yet an artefact);
- a change is not an attestation (a diff is not yet a verified fact);
- an attestation is not an observation (a test report is not a deployment
  fact);
- an observation is not a revision (a runtime signal is not yet a
  commitment change).

The chain goes only one way:

```text
intent -> decision -> obligation -> change -> attestation -> observation -> revision
```

A `revision` does not go back to `decision`. It supersedes or supersedes-not,
which is decided by an explicit `Decision` carrying a `supersedes` relation.

## What this axiom forbids

- A `Decision` whose `claim` field is the literal text of its `intent`
  source. (They are different objects; the `claim` is the *decision*, the
  `intent.text` is the *intent*.)
- An `Obligation` whose `statement` is the literal text of a `Decision`'s
  `commitment`. (The decision is the commitment; the obligation is the
  property.)
- An `Attestation` whose `result` is the literal text of a test name.
  (The test name is the *producer*; the result is the *attestation*.)
- A `Change` whose `summary` is the literal text of an `Obligation`. (The
  change is a diff; the obligation is the property the diff should
  preserve.)

## Where this axiom lives in the codebase

- `spec/domain.md` — entity model enforces the kinds.
- `spec/semantics.md` — evaluation rules follow the chain.
- `schemas/*.json` — required fields per kind.
- `lib/domain.ml` — concrete variants for each kind.
- `OCAML_BEST_PRACTICES.md` §2.1 — variants over records for sealed
  cases.
- `OCAML_BEST_PRACTICES.md` §3.2 — `parse_acceptance` refactor target
  (don't conflate Verifier and Review into one match).

## Counter-example that would violate this axiom

If the schema allowed a `Decision` whose `commitment` was optional and
defaulted to the empty string, then an agent could record a Decision
without stating what it decided, conflating *decision* with *intent*.
This is precisely the failure mode of math-coding 2.1 (see `core/parse.ml:217-250`
in tag `v2.1-final`).

## Counter-example that would silently violate this axiom

If `Attestation.subject` were allowed to point at a `Decision` *without*
naming an `Obligation`, then the attestation would conflate "verified
that the decision exists" with "verified that the obligation holds".
This is the failure mode described in `OCAML_BEST_PRACTICES.md` §10.1
(adapters must produce `Diagnostic.t` so subjects remain explicit).

## What an agent must do when the axiom seems to fail

1. Do not silently resolve the contradiction.
2. Record the contradiction as a deficit:
   `MC-AXIOM-SEPARATION: kind A and kind B were conflated in <path>`.
3. Propose either:
   - a new schema variant that distinguishes them, or
   - a new obligation that requires the missing field, or
   - a manual review by an accountable authority.
4. Do not proceed until the deficit has an accepted remedy.
