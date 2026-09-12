---
proposition: "OCaml 5.3 + dune compiles math-coding runtime after replacing String.Set with Set.Make(String), using modules via -I +unix, and fixing syntax errors."
antithesis: "OCaml 5.x differs from 4.x in standard library path (Set became Stdlib.Set), parser syntax, and unix module discovery. Code written for older OCaml may not build."
synthesis: "Three fixes: replace String.Set with module S = Set.Make(String); add (libraries unix yojson) to dune files for OCaml 5.x auto-include; correct invalid 'as _' syntax in parse.ml."
substrate: shell
status: applied
files: [src/lib/git.ml, src/lib/parse.ml, src/dune]
---

## Intent

Build the OCaml runtime on NixOS where OCaml 5.3 + dune are
available. Get past initial syntax errors.

## What this is NOT

- Not a refactor. The runtime is already minimal; fixes are
  OCaml-version compatibility, not logic changes.
- Not a performance optimisation.

## Run

```sh
dune build
dune test
```

Expect both to succeed.

## Notes

OCaml 5.x changed:
- `String.Set` → must use `module Set = Set.Make(String)` then `Set.of_list`,
  or fully qualify `Stdlib.String.Set` (which is bound to `Set`).
- `Unix` module auto-include deprecated; add `unix` to dune's
  `(libraries ...)` explicitly.
- `as _` patterns in `match` clauses are no longer accepted in
  OCaml 5.x; use a regular variable name.
