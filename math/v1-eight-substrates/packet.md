---
proposition: "Eight substrates (none, shell, pbt, tla+, coq, alloy, bpmn, pbt-prism) describe how strongly a proposition is verified; the LLM chooses based on decision-rules."
antithesis: "Reducing to three substrates (none, shell, pbt) hides the option of formal verification from LLM users, who can learn TLA+ when told it's the right tool."
synthesis: "List all eight substrates with rules for choosing. Real verification is implemented for `none`, `shell`, `pbt` in v1.0. The other five are typed in the runtime; the CLI reports `tool not installed, SKIP` until external checkers are wired."
substrate: none
status: applied
files: [src/lib/check.ml]
---

## Intent

Keep all eight substrates visible. LLM users do not have cognitive
resistance to formal methods; they only need to be told which one
fits the proposition.

## What this is NOT

- Not a recommendation to use formal verification everywhere.
- Not a guarantee that all eight are fully implemented in v1.0.

## Decision rules

See `docs/substrate-decision-rules.md`. Summary:

- `none`: cosmetic, no executable check.
- `shell`: one shell command verifies.
- `pbt`: property-based, many cases.
- `tla+`: state machine, concurrency.
- `coq`: formal proof, critical invariants.
- `alloy`: relational constraints.
- `bpmn`: workflow.
- `pbt-prism`: probabilistic.

## Run (none)

This packet has substrate: none.

## Notes

LLM picks the substrate that matches the proposition. CLI accepts
any value. OCaml runtime checks substrate-specific file presence
for shell/pbt/tla+/coq/alloy/bpmn. For pbt-prism, skipped.
