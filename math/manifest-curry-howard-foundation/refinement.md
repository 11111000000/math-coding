# Refinement: manifest-curry-howard-foundation

## State

- pre: root `README.md` is the v0.618 seed description,
  15 lines, generic phrasing about "mathematically grounded
  software artifacts".
- post: root `README.md` is a foundation manifest, ≤80 lines,
  naming Curry-Howard, four axioms, eight theories,
  three modes.

## Operation

Replace `README.md` with new content. Save the v0.618
version as `README.v0.618.md` if anyone needs it; for v0.854
the manifest replaces it directly.

## Mapping

| pre-existing | post-state |
|--------------|------------|
| "mathematically grounded software artifacts" | "Curry-Howard convention: packet = proof term, verifier = type-check" |
| Three required files per packet | Five files per packet |
| 11 theories | Eight theories |
| Four modes | Three modes |

## Invariant preservation

- 5-file packet structure unchanged.
- Tools unchanged.
- Theories preserved in `core/theories/`.
- axiom A4 unchanged.

## Test obligation

- `wc -l README.md` returns ≤80.
- README explicitly contains "Curry-Howard".
- README lists 8 theories and 3 modes.

## Runtime check

None — manifest is documentation.