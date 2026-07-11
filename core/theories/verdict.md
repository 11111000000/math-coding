# Theory: Verdict

**Rigor:** any

A verdict is the result of verification: Spec ⊨ P?
Five outcomes:

- VERIFIED — Spec ⊨ P proved
- NEEDS_REVISION — Spec ⊭ P (counterexample)
- UNVERIFIABLE:TOOL_MISSING — tool unavailable
- UNVERIFIABLE:OUT_OF_SCOPE — human review required
- UNVERIFIABLE:DEFERRED — data not yet available

There is no UNVERIFIABLE:REJECTED. Reframe as smaller task.

**Used in:** verifier-output.yaml:verdict. The packet's
verifier: {command, verdict_file} specifies how to produce it.

**Example:** packet TLA-rate-limiter has Model.tla. Without
TLC, verdict is UNVERIFIABLE:TOOL_MISSING with exit 0. With
TLC, verdict is VERIFIED if invariants hold, NEEDS_REVISION
otherwise.