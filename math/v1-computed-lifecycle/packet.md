---
proposition: "Lifecycle (draft, applied, drift, stale, retired, abandoned) is computed from git history, not stored as a field."
antithesis: "Stored lifecycle drifts from reality — a packet says 'applied' but witness SHA is invalid, or files in witness don't match manifest."
synthesis: "Compute lifecycle on every check: no witness → draft; proposition changed → drift; files changed but proposition same → stale; proposition + files match → applied. Optional `status:` field in frontmatter overrides the computation for explicit retire/abandon."
substrate: shell
status: applied
files: [src/lib/lifecycle.ml]
---

## Intent

Make lifecycle a property of the packet's git history, not a
manual annotation that can lie.

## What this is NOT

- Not a replacement for explicit retire. CLI `packet edit --status=retired`
  writes the override into frontmatter.
- Not a state machine with legal transitions. Lifecycle is
  observed, not assigned.

## Run

```sh
ocaml -I src/lib unix.cma yaml.cma yojson.cma \
  src/lib/packet.cmo src/lib/parse.cmo \
  src/lib/git.cmo src/lib/lifecycle.cmo \
  -e 'Packet.Lifecycle.compute_lifecycle () pkt |> print_int'
```

This is the OCaml test for lifecycle computation.

## Notes

Six states: `draft`, `applied`, `drift`, `stale`, `retired`,
`abandoned`. The first four are computed. The last two require
explicit override via frontmatter `status:` field.
