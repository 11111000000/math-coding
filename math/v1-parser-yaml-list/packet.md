---
proposition: "Parser recognises YAML inline-list notation [a, b, c] for `files:` and `axiom:` fields; degrades to comma-separated strings for missing brackets."
antithesis: "Current parser only splits by comma, so `files: [src/lib/foo.ml, src/lib/bar.ml]` is stored as one string `[src/lib/foo.ml, src/lib/bar.ml]` and check fails on a literal file with brackets in the name."
synthesis: "Detect leading `[` and trailing `]` after strip_quotes; if both present, split on comma and trim whitespace; else fall back to comma split. Same handling for axiom field (currently a single string but should accept list). Verified by adding two test cases for inline-list parsing."
substrate: pbt
status: applied
files: [src/lib/parse.ml, test/test_packet.ml]
---

## Intent

Stop the verifier from false-failing on well-formed YAML.

## What this is NOT

- Not a full YAML parser. We only need brackets-vs-no-brackets
  detection for inline lists in frontmatter.
- Not a compatibility break. Comma-separated strings still work.

## Test cases added

1. `files: [src/foo.ml, src/bar.ml]` parses to two strings.
2. `files: src/foo.ml, src/bar.ml` parses to two strings.
3. Empty bracketed list `files: []` parses to empty list.
4. Single value without brackets works as before.

## Run

```sh
dune test
```
