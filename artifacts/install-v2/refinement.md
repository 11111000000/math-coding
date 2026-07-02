# Refinement: install-v2

## State mapping

- Spec → install behavior defined here
- Implementation → install/install.sh
- Refinement map → each `cp` command in the script

## Operation mapping

- `cp -r schemas` → copies all JSON Schema files
- `cp templates/*` → copies packet template files
- `cp verify-consistency.sh` → copies verifier
- `cp core/core.md` → copies the convention document
- `cat > README.md` → generates target README

## Invariant preservation

- All required files are copied
- The convention document is the latest version
- Schema files are unchanged

## Test obligation mapping

- Run install in a temp directory, verify all expected files
  exist
- Run twice, verify idempotency (same files, same content)

## Runtime-check mapping

- User runs `sh install.sh` from target project root
- Output: `./math-coding/` with all files

## Connection

This is the **deployment** layer of the convention. It brings
the convention from theory to user's project.