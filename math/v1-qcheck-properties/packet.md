---
proposition: "QCheck properties verify that the OCaml runtime obeys its own invariants: substrate inverse, marker inverse, parse preserves proposition, eight substrates are distinct."
antithesis: "Unit tests cover examples; they cannot prove laws. The runtime might be consistent on tested inputs but inconsistent elsewhere."
synthesis: "Four QCheck properties run 100 random inputs each: substrate_of_string is inverse of substrate_to_string; marker_of_string is inverse of marker_to_string; all 8 substrates are distinct; parse_packet preserves proposition. This catches bugs in the type system itself."
substrate: pbt
status: applied
files: [test/test_properties.ml]
---

## Intent

Make the runtime test itself, not just examples of behaviour.

## What this is NOT

- Not a substitute for unit tests. QCheck covers properties; unit
  tests cover specific edge cases.
- Not a guarantee. 100 random inputs cannot cover the state space.

## Run

```sh
dune test
# Runs both test_packet (Alcotest) and test_properties (QCheck).
```

## Properties

1. `prop_substrate_inverse` — `substrate_to_string (substrate_of_string s) = s`.
2. `prop_marker_inverse` — `marker_to_string (marker_of_string s) = s`.
3. `prop_substrate_distinct` — all 8 substrates have distinct string forms.
4. `prop_parse_proposition` — parse preserves proposition text.

## Notes

QCheck is a property-based testing library for OCaml, similar to
Haskell's QuickCheck. Generates 100 random inputs per property.
Runs in `dune test`.
