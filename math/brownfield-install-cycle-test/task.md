# brownfield-install-cycle-test

## Problem

The brownfield install (`core/install/install.sh`) is
untested. If install breaks (missing file, wrong mode,
broken path), all downstream users fail at axiom A6 — but
in their copy, not in the source. axiom Self-Application
runs in the source, so it does not catch install errors.

## Desired outcome

A hermetic test that exercises install → verify →
uninstall in a tmp directory. The test runs in CI. axiom
A6 is verified **in the copy**, not in the source.

## Constraints

- POSIX shell only (axiom Material Basis).
- The test must not modify the host repository.
- The test must clean up its tmp directory.
- The test must be hermetic: each run is independent.