---
proposition: "Each packet lives in its own folder math/<name>/ with packet.md + witness, plus optional substrate directories."
antithesis: "Flat files like math/cache-ttl.md collide with substrate extensions (math/cache-ttl.tla could mean TLA+ spec or a packet named tla)."
synthesis: "Folder per packet isolates proposition from substrate-specific files. Substrate files go in math/<name>/<substrate>/, never at the math/ root."
substrate: none
status: applied
---

## Intent

Allow each of eight substrates (none, shell, pbt, tla+, coq,
alloy, bpmn, pbt-prism) to bring its own files without colliding
with packet names.

## What this is NOT

- Not a directory tree of nested subfolders. One level only.
- Not a workspace-style monorepo. Each math/<name>/ is independent.

## Folder layout

```
math/<name>/
├── packet.md        # YAML frontmatter + Markdown body
├── witness          # YAML list of witness entries
├── run.sh           # only if substrate: shell
├── properties/      # only if substrate: pbt
├── tla/             # only if substrate: tla+
├── coq/             # only if substrate: coq
├── alloy/           # only if substrate: alloy
└── bpmn/            # only if substrate: bpmn
```

## Run (none)

This packet has substrate: none.

## Notes

OCaml runtime reads `packet.md` and `witness` from each folder.
Substrate-specific files are validated by the appropriate external
tool (TLC, coqc, Alloy, etc.) or skipped if not installed.
