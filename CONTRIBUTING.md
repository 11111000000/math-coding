# KNOWN DIVERGENCE convention

When OCaml code in `core/` deviates from the LaTeX model in
`math/modeling/`, the divergence is recorded as a `KNOWN DIVERGENCE`
comment in the OCaml code.

## Format

```ocaml
(* KNOWN DIVERGENCE: see issue #N
   Theorem: X.Y expects ABC.
   OCaml does XYZ instead.
   Action: tighten LaTeX to match OCaml, or restrict OCaml scope.
   Decision date: YYYY-MM-DD *)
```

The comment must contain:
- `KNOWN DIVERGENCE:` keyword
- Issue reference (`see issue #N`) — even if N is a placeholder
- Theorem name from the LaTeX model
- What the OCaml actually does
- Action plan

## When to write

Write when:
- OCaml implementation cannot immediately match LaTeX (e.g., V6 SPO
  cycle detection requires graph traversal that v2.0-Y defers)
- A field is optional in LaTeX but mandatory in OCaml (or vice versa)
- A behavior is approximated (e.g., state FSM uses 5 states but
  LaTeX has 3 transitions)

## When NOT to write

Do NOT write when:
- OCaml implements LaTeX exactly
- The divergence is a typo (fix it instead)
- The divergence is short-lived (within one commit)

## Resolution

Each `KNOWN DIVERGENCE` must have an issue. The issue tracks the
work to either tighten the LaTeX or restrict the OCaml. The
divergence is resolved when the issue is closed.

## Self-application

This convention applies to itself. The KNOWN DIVERGENCE
convention itself is described in this file; if the convention
changes, the file changes via supersede.

## See also

- `math/modeling/semantics.tex` — formal model
- `core/check.ml` — kernel S with KNOWN DIVERGENCE comments
- `core/types.ml` — Decision type
- `AGENTS.md` — agent protocol