# Obsidian support

math-coding v0.992 is designed for Obsidian. Open this
repository as an Obsidian vault.

## Plugins

Recommended (all built-in or freely available):

  - **Dataview** (built-in via Dataview community plugin) —
    enables queries over markdown files. Used in
    `core/spec/axioms.md` and `core/theories/README.md`.
  - **Graph view** (built-in) — visualises the axiom
    dependency graph.

Not needed:

  - **Templater** — we do not use templates.
  - **Calendar** — not applicable.
  - **Tasks** — we use a finite state machine, not a task
    list.

## Wikilinks

Obsidian renders `[[...]]` as links between markdown files.
The convention uses wikilinks liberally:

  `[[core/spec/axioms.md#a0-difference-ontological|A0]]` —
  link to a specific axiom by anchor.

  `[[math/00-difference|packet A0]]` — link to a packet.

Each axiom packet's `decision.md` has a backlink to the
axiom definition in `core/spec/axioms.md`, and vice versa.

## Dataview queries

`core/spec/axioms.md` lists axiom packets:

```dataview
TABLE
  lifecycle AS "lifecycle",
  substrate AS "substrate",
  decision AS "decision"
FROM "math"
WHERE file.name >= "00" AND file.name < "10"
SORT file.name ASC
```

`core/theories/README.md` lists theories:

```dataview
TABLE
  file.link AS "theory",
  axiom AS "axiom"
FROM "theories"
WHERE file.name != "README"
SORT file.name ASC
```

## Looking at the axiom graph

Open `math/` and view it in Graph view. Obsidian renders
wikilinks between axiom packets and `core/spec/axioms.md` as
edges. The seven axiom packets cluster around `core/spec/axioms.md`
with edges to axiom-specific anchors.

## Reading order (recommended for Obsidian)

1. `README.md` (one-page manifest)
2. `core/spec/axioms.md` (seven axioms, Dataview query at top)
3. `core/theories/README.md` (eight theories, Dataview query)
4. One axiom packet — start with `math/00-difference/`

For implementation: `core/spec/packet-schema.md` → one axiom packet →
`core/spec/packet-schema.md`.