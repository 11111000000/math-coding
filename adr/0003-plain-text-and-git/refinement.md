# Refinement: ADR 0003

## State mapping

- Decision → minimal tool stack
- Implementation → all scripts use only sh + coreutils

## Operation mapping

- `Run verifier` → only sh, awk, grep needed

## Invariant preservation

- No external tool required for base verifier

## Test obligation mapping

- Verifier runs on a clean system

## Runtime-check mapping

- `sh verify-consistency.sh` requires no installation

## Connection

This ADR enables portability.