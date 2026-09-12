---
proposition: "v0.993 packets migrate to v1.0 structure via `sh scripts/migrate-v0993.sh` which reads packet.yaml + decision.md, writes packet.md, removes old files."
antithesis: "Hand-migrating 35 packets would lose information and create inconsistency."
synthesis: "One shell script reads each packet, extracts proposition/antithesis/synthesis from decision.md, writes packet.md with YAML frontmatter, removes old 4-5 files. Run once at v1.0 adoption."
substrate: none
status: applied
---

## Intent

Make v1.0 adoption cheap. A user with v0.993 history runs one
script and gets v1.0 structure without losing any content.

## What this is NOT

- Not a one-way door. The old v0.993 files are removed after
  migration, but git history preserves them.
- Not automatic. Users opt in by running the script.

## Migration steps

1. `sh scripts/migrate-v0993.sh`
2. Each `math/<name>/packet.md` contains proposition, antithesis,
   synthesis from old decision.md.
3. Old files (packet.yaml, decision.md, refinement.md, task.md,
   assumptions.yaml) are removed.

## Run (none)

This packet has substrate: none.

## Notes

v1.0 is a clean break. The migration script is a one-time helper.
After migration, the v0.993 structure is gone, but git history
remains accessible via `git log -- math/<name>/`.
