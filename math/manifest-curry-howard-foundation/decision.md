# manifest-curry-howard-foundation

## Thesis

math-coding inherits its logical structure from the
Curry-Howard correspondence: every packet is a proof term,
every verifier run is a type-check. This relationship is
load-bearing in `core/think-before-do.md` but never stated
explicitly in the manifest.

## Antithesis

Without an explicit manifest, agents may treat math-coding
as a process convention only — "spec before code" — without
realising that the convention is itself a logical system.
The result is ceremony without rigour.

## Synthesis

State the foundation explicitly in the root README.md:

> math-coding is a Curry-Howard convention: every packet is
> a proof term, every verifier exit-code is a type-check.
> The convention applies to itself (axiom A4).

## What this packet commits to

- Replace the root `README.md` with a foundation manifest
  that names Curry-Howard as the load-bearing correspondence.
- Provide one paragraph for each of the four axioms:
  think-before-do, FSM lifecycle, epistemic markers, axiom A4.
- Reference the eight theories (4 foundational + 4 applied).
- Reference the three modes (light/standard/strict).

## What this packet does NOT commit to

- No change to 5-file packet structure.
- No change to existing tools.
- No new theories.