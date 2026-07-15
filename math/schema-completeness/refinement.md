# Refinement: schema-completeness

## State

- pre: 5 schema gaps. axiom Self-Application: PROVEN.
- post: 5 schema gaps closed. axiom Self-Application: PROVEN.

## Operation

1. `axiom: A0` (and A1, A2, A3, A4, A5, A6) added to each
   axiom packet's `packet.yaml`.
2. `axiom` column added to `theories/README.md`'s table.
3. `axiom` index table added to `docs/axioms.md` (after the
   existing axiom descriptions).
4. `## Definition` section added before `## Theorem` in each
   of the 8 theory files.
5. `math/README.md` (1 paragraph) created.

## Mapping

| change | file(s) |
|--------|----------|
| `axiom:` field | 7 axiom packet `packet.yaml` files |
| `axiom` column | `theories/README.md` |
| `axiom` index table | `docs/axioms.md` |
| `## Definition` | 8 theory files |
| `math/README.md` | new file |

## Invariant preservation

- 16 self-tests still pass.
- axiom Self-Application: PROVEN.
- axiom A2 (Curry-Howard): unchanged.
- axiom A3 (Material Basis): unchanged.

## Test obligation

`tests/run.sh` runs 16 cases. Each must pass.
`sh math-coding probe` must exit 0.

## Runtime check

None. The change is documentation-only.