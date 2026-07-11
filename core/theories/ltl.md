# Theory: Linear-time Temporal Logic

**Rigor:** temporal+

LTL operators:
- □P — "always P" (P holds in every state)
- ◇P — "eventually P" (P holds in some future state)
- P ~> Q — "P leads to Q" (whenever P holds, Q eventually holds)

**Used in:** refinement.md when stating properties of packet
lifecycle. For liveness, write P ~> Q in refinement.

**Example:** □(lifecycle=verified → ◇lifecycle=deprecated).
"Every verified packet is eventually deprecated." This
guarantees packets don't stay verified forever; they must
eventually be superseded when convention evolves.
