# Theory: Modal Logic for FSM Lifecycles

**Rigor:** temporal+

Modal operators:
- □P — necessarily P (P in every reachable state)
- ◇P — possibly P (P in some reachable state)
- P ~> Q — P leads to Q (whenever P, Q eventually)

A packet lifecycle FSM (sketch → working → verified →
deprecated → archived → superseded) has safety and liveness:

| Property | Formula | Type |
|----------|---------|------|
| No skipping | ¬(sketch → verified) | safety |
| Verified persists | □(verified → ◇deprecated) | liveness |

**Used in:** refinement.md of packets with non-trivial
lifecycle. For simple CRUD packets, skip.

**Example:** packet-historical-replacement must guarantee
"every superseded packet is eventually archived". Write this
as superseded ~> archived in refinement.md:§Liveness.