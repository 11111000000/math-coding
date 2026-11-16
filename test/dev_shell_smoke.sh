#!/bin/sh
# The development shell is ready for work.
#
# The check proves three things. The tools of the shell come from the store
# and not from the system, so the shell says the same on every machine. The
# node of the shell can be taken from the binary cache instead of being
# compiled from the sources, which took twenty minutes on a fresh machine.
# And the shell stays in the store after the shell is closed, so the next
# start of the shell does not download the whole toolchain again.
set -eu

fail() {
  printf 'dev shell: %s\n' "$1" >&2
  exit 1
}

# The checks need the tools of the development shell. The verifier enters the
# shell itself when it does not run inside one already, so the check says the
# same on every machine and in every place it is called from.
if [ "${MATHC_DEV_SHELL:-}" != "inside" ]; then
  script="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/$(basename -- "$0")"
  MATHC_DEV_SHELL=inside MATHC_DEV_SHELL_SCRIPT="$script" \
    nix develop -c sh -c 'MATHC_DEV_SHELL=inside sh "$MATHC_DEV_SHELL_SCRIPT"'
  exit $?
fi

root="${MATHC_DEV_ROOT:-${XDG_CACHE_HOME:-$HOME/.cache}/nix/roots/math-coding-dev}"

for tool in node npm npx; do
  found="$(command -v "$tool" 2>/dev/null || true)"
  [ -n "$found" ] || fail "$tool is missing in the development shell"
  case "$found" in
    /nix/store/*) ;;
    *) fail "$tool comes from the system and not from the store: $found" ;;
  esac
done

# A derivation that forbids substitutes is compiled from the sources. The full
# node of nixpkgs does exactly that, and the shell waited for it for twenty
# minutes before it started.
system="$(nix eval --raw --impure --expr builtins.currentSystem)"
drv="$(nix eval --raw ".#devShells.$system.default.drvPath")"
for reference in $(nix-store --query --references "$drv"); do
  case "$reference" in
    *.drv) ;;
    *) continue ;;
  esac
  if grep -q 'allowSubstitutes' "$reference" 2>/dev/null; then
    fail "the derivation $reference forbids substitutes and is compiled from the sources"
  fi
done

# The root of the shell outlives the shell itself.
nix-store --gc --print-roots 2>/dev/null | grep -F "$root -> " >/dev/null \
  || fail "the development shell is not kept in the store: $root"

printf 'dev shell: PASS\n'
