---
name: constructive
proposition: "Proven requires Reproducible{command, recorded_exit, when_} evidence. Re-running the command and comparing exit codes is the only acceptable proof. Other epistemic markers (fact, hypothesis, judgment, unknown) are declarations without runtime verification."
superseded_by:
---

## Why

Classical logic permits "proven" without construction. Constructive
logic requires a witness. In software, the witness is a re-runnable
command. If you cannot reproduce the result, the claim is not
proven — it is hypothesis.

This is why math-coding uses only one epistemic marker that
triggers runtime action: `proven`. Other markers are useful as
labels but do not affect kernel verdicts.

## Considered alternatives

- Classical logic with multiple truth values — rejected: too
  permissive; reduces to opinion.
- Five epistemic markers (fact, hypothesis, judgment, unknown,
  proven) — rejected: four of five are decorative; agents fill
  them with noise.
- Confidence as numeric value — deferred: nice to have but not
  load-bearing for the kernel.

## Notes

Re-running is normalisation in the Curry-Howard sense: the program
`command` reduces to a value (exit code). If the value matches
`recorded_exit`, the type inhabitation holds.
