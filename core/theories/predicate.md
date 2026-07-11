# Theory: Predicate and Invariant

**Rigor:** any (foundational)

A predicate over a state space S is a function:
  I: S → B

A state s satisfies I iff I(s) = true.

**Used in:** packet.yaml:lifecycle (the lifecycle is a
predicate over the packet state — sketch, working,
verified, deprecated, archived, superseded).

**Example:** I(packet) = (packet.yaml exists /\ task.md
exists /\ assumptions.yaml exists). A packet passes
the structural check iff this predicate holds.
