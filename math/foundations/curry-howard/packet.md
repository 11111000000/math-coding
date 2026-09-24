---
name: curry-howard
proposition: "Decision is a (proposition, code, witness) triple; the kernel S verifies structural consistency between proposition and code via witness."
superseded_by:
---

## Why

Curry-Howard isomorphism is the foundation of math-coding. A proposition
is a type. Code is a term inhabiting that type. The witness is the
derivation showing inhabitation. The kernel S is the type-checker.

Without this correspondence, math-coding becomes mere documentation.
With it, every decision has a *machine-checkable* connection to its
implementation.

## Considered alternatives

- Documentation-only (markdown files, no kernel verification) —
  rejected: no enforcement, drift accumulates silently.
- Custom DSL for propositions — rejected: adds complexity, breaks
  the principle that decisions are in natural language.
- Type-theoretic framework (Coq, Lean) — rejected: too heavy for
  everyday decisions; reserved for `substrate: coq` when needed.

## Notes

The other three foundations (temporal, constructive, categorical)
derive from this one plus standard CS frameworks.
