#!/bin/sh
# Executable spec for this packet: re-runs `dune build` and returns
# its exit code. Verifier on `math-coding check` will run this and
# compare against recorded_exit in epistemics.
cd "$(dirname "$0")/../.." || exit 2
dune build >/dev/null 2>&1
