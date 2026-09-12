---
proposition: "math-coding v1.0 ships as a single OCaml static binary that verifies packet structure, computes lifecycle from git history, and checks epistemic markers."
antithesis: "Shell scripts and per-project payloads make the convention heavy and fragile. Multi-language implementations cannot share types."
synthesis: "One OCaml binary at $XDG_DATA_HOME/math-coding/<ver>/. Project repos carry only math/<name>/. Static type-check at compile time, QCheck properties at test time, structural checks at runtime."
substrate: none
status: applied
---

## Intent

Make the convention light enough that adding a packet feels like
writing one file, not maintaining a stack of metadata.

## What this is NOT

- Not a Rust implementation. We considered Rust for cross-compile
  ergonomics; OCaml wins on density.
- Not a backward-compatible fork of v0.993. v1.0 starts from zero.
- Not a multi-agent coordination tool. Git is the coordination layer.

## Run (none)

This packet has substrate: none. It documents a decision, not a
runtime check.

## Notes

See `docs/substrate-decision-rules.md` for when to use which
substrate. The OCaml runtime implements real verification for
`none`, `shell`, `pbt`. The other six substrates are typed in the
runtime but report `tool not installed, SKIP` until external
checkers are wired in future versions.
