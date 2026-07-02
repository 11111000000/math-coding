# Install Script v2

## Problem

A user wants to apply math-coding to their project without
manually copying every file. A single command should suffice.

## Desired outcome

`install/install.sh`:

- Copies templates (packet.yaml, task.md, assumptions.yaml)
- Copies schemas/ (machine-readable specs)
- Copies theory/ (reference documents)
- Copies core.md (the convention)
- Copies verify-consistency.sh (the verifier)
- Creates a README in the target `./math-coding/` directory

## Constraints

- Idempotent (running twice produces same result)
- Requires only `sh`, `awk`, `grep`, `sed`, `find`, `git`
- No Python, no Node, no external tools

# Adaptations

(none)