# math/

Sixteen packets live here. Seven are axiom packets
(A0–A6); nine are post-genesis packets.

## Axiom packets

- `00-difference/` — axiom Difference (ontological)
- `01-care/` — axiom Care (motivational)
- `02-curry-howard/` — axiom Curry-Howard (structural)
- `03-material/` — axiom Material Basis (substrate)
- `04-process/` — axiom Process (temporal)
- `05-accounting/` — axiom Accounting (epistemic)
- `06-self-application/` — axiom Self-Application (meta)

## Post-genesis packets

- `packet-lifecycle/` — how packets evolve
  (amendment / supersession / deprecation)
- `create-packet-spec-driven/` — spec-driven
  packet creation
- `extract-packet-reverse/` — reverse: 5 files to spec
- `ci-workflow-convention/` — CI workflow packet
- `brownfield-install-cycle-test/` — install cycle test
- `epistemic-markers-in-theory/` — epistemic markers test
- `schema-completeness/` — schema completeness
- `opencode-skill-restructure/` — opencode skill split
- `theory-formal-statements/` — theorem-proof for theories

## Source-only

v0.978: `math/` is **source-only**. The axiom packets and
post-genesis packets live in the source repository where
the convention is developed. They are not part of the
install payload. `core/install/install.sh` does not copy
them into target projects.

In a target project, the user's own packets live in
`<target>/math/`. This directory is created by `install.sh`
as an empty workspace and is configured via `.mathrc`
(field: `math_dir`).

The distinction keeps the convention honest: axiom
packets prove that the convention works (definitional
axiom Self-Application); user packets prove that the
convention applies (applicative axiom Self-Application).

## See also

- `docs/axioms.md` — seven axioms with full statement
- `theories/` — eight theories
- `core/` — install payload
- `tests/run.sh` — 20 self-tests