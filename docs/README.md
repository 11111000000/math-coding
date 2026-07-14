# Documentation (math-coding v0.854)

The convention's documentation lives in three places.

## docs/

  axioms.md      seven axioms with formal statements and
                 worked reasoning
  spec.md        canonical specification (axioms + theories +
                 tools + lifecycle)
  extensions.md  the extensions/ contract — when and how to
                 extend

## theories/

Eight mathematical theories, each grounding one or more
axioms. See `theories/README.md` for the index.

## core/spec/

  packet-schema.md     five-file contract per packet
  think-before-do.md  temporal discipline (axiom Process)
  decision-modes.md   three modes (light/standard/strict)

## Obsidian

The repository is designed for Obsidian. Open the root as a
vault; recommended plugins are Dataview (built into
Obsidian) and Graph view (built-in).

Dataview queries live in `docs/axioms.md` and
`theories/README.md`. Wikilinks `[[packet-name]]` between
axiom packets and `[[docs/axioms.md#a0-difference-ontological|A0]]`
between axiom packets and the axiom definitions work
out of the box.

## Reading order

For first contact: `README.md` → `docs/axioms.md` →
`theories/README.md` → one axiom packet (`math/00-difference/`).

For implementation: `docs/spec.md` → `core/spec/packet-schema.md`
→ `math/packet-lifecycle/`.