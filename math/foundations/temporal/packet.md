---
name: temporal
proposition: "Lifecycle L(decision, repo) is a function from decision and git history; L is computed, not stored. Terminal state (retired, abandoned) is the only stored lifecycle value."
superseded_by:
---

## Why

Decisions evolve over time. A proposition true at commit A may not be
true at commit B. Storing lifecycle as an enum would allow lying
about state. Computing lifecycle from git history makes drift
detection automatic and falsifiable.

L(decision, repo) ∈ {Draft, Applied, Drift, Stale}.

Terminal transitions (retired, abandoned) require explicit CLI action
because they encode *human judgment*, not mechanical fact.

## Considered alternatives

- Stored lifecycle enum with manual updates — rejected: enables drift
  between claim and reality.
- LTL-based runtime verification — deferred: complex; current
  Draft/Applied/Drift/Stale covers the cases that matter.
- Continuous polling — rejected: git gives us the event log natively.

## Notes

Combined with foundation/curry-howard, every decision has:
- type (proposition), term (code), derivation (witness) from curry-howard
- temporal trajectory (lifecycle over git history) from temporal
