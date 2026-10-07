#!/usr/bin/env bash
# math-coding 3.0-alpha — verify merlin/ocaml-lsp are wired.
#
# Exits 0 if both binaries are present in `nix develop .#test`
# and report the expected versions; non-zero if either is missing
# or version-skewed.
#
# Used as the verifier for obligation `ocaml-lsp-and-merlin-in-dev-shell`
# in decisions/merlin-lsp-2026-10.yaml.

set -eu

required_merlin="v5.8-505"
required_ocamllsp="1.27.0"

cd "$(dirname "$0")/.."

# Inside the dev-shell:
nix develop .#test --command bash -c "
  set -eu
  merlin_ver=\$(ocamlmerlin -version 2>&1 | head -1)
  lsp_ver=\$(ocamllsp --version 2>&1 | head -1)
  ok=1
  case \"\$merlin_ver\" in
    *\"$required_merlin\"*) ;;
    *) printf 'merlin version mismatch: got %s, want substring %s\\n' \"\$merlin_ver\" \"$required_merlin\" >&2; ok=0 ;;
  esac
  case \"\$lsp_ver\" in
    *\"$required_ocamllsp\"*) ;;
    *) printf 'ocaml-lsp version mismatch: got %s, want substring %s\\n' \"\$lsp_ver\" \"$required_ocamllsp\" >&2; ok=0 ;;
  esac
  if [ \"\$ok\" = \"1\" ]; then
    printf 'merlin: %s\\nocaml-lsp: %s\\n' \"\$merlin_ver\" \"\$lsp_ver\"
    exit 0
  else
    exit 1
  fi
"