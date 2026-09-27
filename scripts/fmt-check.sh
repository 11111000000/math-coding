#!/usr/bin/env bash
# math-coding 3.0-alpha: dune fmt --check wrapper.
#
# obligation ocamlformat-fmt-clean: exposes `dune fmt --preview`
# (dune 3.23 has no `--check` flag) as a pass/fail script for the
# fmt-clean fixture. Uses the nix test shell so ocamlformat is on
# PATH. Returns 0 iff the OCaml tree is fully normalized.
#
# Implementation: dune 3.23's `dune fmt` always promotes changes by
# default and exits 0 even when files would be reformatted. To get
# a clean pass/fail we set DUNE_DISABLE_PROMOTION=1, which makes
# `dune fmt --preview` (non-mutating: print diffs only) exit 1
# when any source file would be reformatted. See OCAML_BEST_PRACTICES
# trap log §11.21.

set -euo pipefail
cd "$(dirname "$0")/.."

nix develop .#test --command bash -c '
  set -e
  cd "'"$(pwd)"'"
  DUNE_DISABLE_PROMOTION=1 dune fmt --root . --preview
'
