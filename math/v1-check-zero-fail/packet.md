---
proposition: "math-coding v1.0 check exits 0 on all 43 packets in math/, probe reports 215 pass / 0 fail; build is deterministic via nix flake."
antithesis: "YAML inline-list notation [a, b] was stored as one string, not a list, causing check to false-fail on paths like [src/lib/check.ml]; Sys.readdir returned hidden files (.)."
synthesis: "Three coupled fixes: parser detects [ ... ] brackets in inline lists and splits accordingly; check_files_exist resolves relative paths against project root (two levels above pkt.path); probe skips hidden entries starting with '.'. Result: 215 pass, 43 warn (all draft-witness missing), 0 fail across 43 packets. All 7 unit + 4 QCheck property tests pass."
substrate: shell
status: applied
files: [src/lib/parse.ml, src/lib/check.ml, src/lib/probe.ml, test/test_packet.ml]
---

## Intent

Make v1.0 quality checkable and reproducible.

## What this is NOT

- Not a coverage claim. The 9 -> 0 fail reduction is one shape of
  quality; we have not added new tests, only fixed existing ones.

## Run

```sh
_build/default/src/main.exe check
_build/default/src/main.exe probe
dune test
```

All three should report 0 fail / 0 error.

## Notes

43 warnings are all `WARN: no witness; lifecycle is draft` —
intentional for draft packets. Move to `applied` by adding a
witness SHA once implementation lands.

## Test coverage

- 4 Alcotest unit tests (substrate_of_string, marker_of_string,
  parse_packet_frontmatter, lifecycle_no_witness)
- 3 new parser tests (inline_list, comma_list, empty_brackets)
- 4 QCheck properties (substrate_inverse, marker_inverse,
  substrate_distinct, parse_proposition)
