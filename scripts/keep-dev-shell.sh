#!/bin/sh
# Keep the development shell in the Nix store.
#
# `nix develop` roots the shell only while the shell is open. Once the shell
# is closed the collector of garbage may take the whole toolchain away, and
# the next start of the shell downloads it again. This script leaves a root of
# its own in the cache of the user: the root lives in a directory the user
# owns, so no administrator is needed for it.
#
# The environment variable MATHC_DEV_ROOT moves the root to another place, and
# MATHC_DEV_SHELL_PATH says which path of the store is kept.
set -eu

root="${MATHC_DEV_ROOT:-${XDG_CACHE_HOME:-$HOME/.cache}/nix/roots/math-coding-dev}"
path="${MATHC_DEV_SHELL_PATH:-${NIX_GCROOT:-}}"

if [ -z "$path" ]; then
  # Outside the development shell the path is asked from the flake itself.
  # The script lives next to the flake, both in the repository and in the
  # copy of the source the store keeps.
  here="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
  flake="$(CDPATH= cd -- "$here/.." && pwd)"
  system="$(nix eval --raw --impure --expr builtins.currentSystem)"
  path="$(nix eval --raw "$flake#devShells.$system.default")"
fi

case "$path" in
  /nix/store/*) ;;
  *)
    printf 'keep-dev-shell: not a path of the store: %s\n' "$path" >&2
    exit 1
    ;;
esac

mkdir -p "$(dirname "$root")"
previous="$(readlink "$root" 2>/dev/null || true)"
nix-store --add-root "$root" --realise "$path" >/dev/null

# The root is worth a word only when it was not there before.
if [ "$previous" = "$path" ]; then
  exit 0
fi
printf 'dev shell root: %s -> %s\n' "$root" "$path" >&2
