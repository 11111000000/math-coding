# theory-predicate — Predicate and Invariant in math-coding

## Thesis

math-coding claims to be "grounded in mathematics". This claim
is vacuous unless each mathematical theory is concretely applied
to the convention. Without application, "Predicate" is just a
word; with application, it is a tool that explains why a packet
is verified or not.

## Antithesis

A 20-line theory doc in `core/theories/predicate.md` is enough
as mathematical reference. But it does not explain HOW math-coding
uses the predicate. The convention says "lifecycle: 6 states" but
does not say "lifecycle is a predicate over packet state".

## Synthesis

This packet connects the abstract theory (Predicate and
Invariant) to the concrete convention (lifecycle FSM, packet
completeness check, structural verifier). It says:
1. The packet lifecycle IS a predicate (an OS file should
   authorize this claim, which this packet does)
2. The packet structure check IS a predicate (each file's
   existence is a propositional variable)
3. The "packet is verified" verdict IS a predicate satisfaction
   check

## What this packet commits to

- The mathematical connection between Predicate theory and
  math-coding's lifecycle, structural check, and verifier
- Clarifies WHY math-coding is "grounded in math" — not just
  abstract theories in core/theories/, but applied reasoning
- This packet authorizes core/theories/predicate.md as
  the canonical application of Predicate theory to math-coding

## What this packet does NOT commit to

- A formal theorem prover (deferred — we use the theory
  informally for now)
- Additional theories beyond the existing 11
- Changing core/theories/predicate.md content (it's already
  correct as a reference doc)
