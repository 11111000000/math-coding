# schema-completeness

## Thesis

The convention's schema is **incomplete** in five places:
(1) axiom packets lack an explicit `axiom:` field; (2)
`theories/README.md` lacks an `axiom` column; (3) `docs/axioms.md`
lacks a navigation table from axiom → packet → theory;
(4) theories lack a `Definition` step before Theorem; (5)
`math/` lacks a README.

## Antithesis

The current schema is **functional** (axiom A6 holds, 16
self-tests pass). The five incompletenesses are
**cosmetic** — readers can navigate by file names, packet
names, and section headers.

But: a LLM agent that loads the convention into context
wastes **context tokens** finding which axiom corresponds
to which packet. A 5-minute manual lookup is **redundant**
when the schema can provide a 5-second query.

## Synthesis

Add 5 small, additive improvements:

1. **`axiom:` field** in each axiom packet's `packet.yaml`.
   E.g. `axiom: A0` in `math/00-difference/packet.yaml`.
2. **`axiom` column** in `theories/README.md`'s table.
3. **`axiom` index table** in `docs/axioms.md` (axiom →
   packet → theory → related axioms).
4. **`Definition` step** before Theorem in each theory
   (formal definition of the data structure first, then the
   theorem about it, then the proof).
5. **`math/README.md`** (1 paragraph) — 13 packets live
   here, 7 are axioms, 6 are post-genesis.

All 5 changes are **additive** (1-3 lines each). They do not
break axiom Self-Application. The 16 self-tests still pass.

## Surface impact

touches: 7 axiom packet `packet.yaml` files
(`math/00-difference/.../packet.yaml` through
`math/06-self-application/.../packet.yaml`),
`theories/README.md`, `docs/axioms.md`, 8 theory files
(`theories/{curry-howard,predicate,fsm,refinement,
verdict,epistemic,deprecation,agent}.md`),
new `math/README.md`.

## Proof

axiom Self-Application: PROVEN. 16 self-tests pass before
and after these changes. The convention is
**structurally self-documenting** after the change.