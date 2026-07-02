# Theory 10 — Modal Logic for Lifecycle

## Problem

The convention uses temporal logic (LTL) for lifecycle but
cannot express cascading deprecation cleanly: "if P is
superseded, then Q (which depends on P) must eventually
re-verify" is a statement about the dependency relation, not
about the temporal trace. Pure LTL forces the dependency graph
into the temporal trace, which loses structure.

## Desired outcome

A document that:

- Introduces Kripke structure $\mathcal{K} = \langle W, R, V \rangle$
  over packet states
- Reinterprets LTL operators as modal operators over the
  temporal successor relation
- Adds distinct modal operators $\square$ and $\Diamond$ over the
  dependency relation
- Expresses cascading deprecation as a modal obligation
- Expresses forbidden transitions as modal impossibility

## Constraints

- Notation is compact (LaTeX-as-ASCII)
- A concrete example ties modal obligations to cascading
- References to Hughes-Cresswell, Blackburn-de Rijke-Venema,
  Harel-Kozen-Tiuryn

# Adaptations

(none)