# Verdict (A5)

A verdict is the outcome of evaluating the proof obligation:

  Spec ⊨ P

The five canonical verdicts of math-coding:

  VERIFIED                   — proof accepted
  NEEDS_REVISION             — counterexample or missing piece
  UNVERIFIABLE:TOOL_MISSING  — required tool unavailable
  UNVERIFIABLE:DEFERRED      — data not yet available
  UNVERIFIABLE:OUT_OF_SCOPE  — human review required

`core/check/verify.sh` exits 0 (VERIFIED) or non-zero
(NEEDS_REVISION). `core/self/probe.sh` reports the verdict
of the convention applied to itself.

See math/05-accounting/, math/06-self-application/.