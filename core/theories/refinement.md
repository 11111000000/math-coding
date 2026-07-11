# Theory: Refinement

**Rigor:** any

A refinement is a function R: S_impl → S_spec such that for
every implementation transition, there exists a sequence of
spec transitions matching it.

**Used in:** refinement.md (every packet describes how its
implementation maps to its specification). The State/Operation/
Invariant/Test/Runtime sections of refinement.md follow this
pattern.

**Example:** packet-lifecycle_impl has 6 states
(sketch, working, verified, deprecated, archived, superseded).
Packet_spec has 5 states (sketch, working, verified, deprecated,
archived). R maps superseded → deprecated, then to archived.
The lifecycle FSM implements this refinement.
