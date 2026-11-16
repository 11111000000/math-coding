#!/bin/sh
# The development shell is ready for work.
#
# The check proves three things. The tools of the shell come from the store
# and not from the system, so the shell says the same on every machine. The
# node of the shell can be taken from the binary cache instead of being
# compiled from the sources, which took twenty minutes on a fresh machine.
# And the shell stays in the store after the shell is closed, so the next
# start of the shell does not download the whole toolchain again.
#
# The check speaks about the shell of this project and not about the
# environment around it. A caller often runs the check from a shell that has
# its own node and npm, and a check that looked at the path around it would
# praise a shell that has neither.
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

# The tools of the shell are the packages of the shell. The shell keeps them
# as references of its own path, and the tools of a package live in the bin
# directory of that package. The check therefore looks into the store and
# asks the shell for its own tools, and it does not ask the path around it.
shell_path="${NIX_GCROOT:-}"
[ -n "$shell_path" ] || fail "the development shell does not name its own path"

references="$(nix-store --query --references "$shell_path" 2>/dev/null || true)"
[ -n "$references" ] || fail "the development shell names no packages: $shell_path"

package_of() {
  for reference in $references; do
    if [ -x "$reference/bin/$1" ]; then
      printf '%s\n' "$reference"
      return 0
    fi
  done
  return 1
}

for tool in node npm npx; do
  package="$(package_of "$tool" || true)"
  [ -n "$package" ] || fail "the development shell does not provide $tool from the store"
  case "$package" in
    /nix/store/*) ;;
    *) fail "$tool of the development shell comes from the system and not from the store: $package" ;;
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
#
# The collector names a root the way the user named it in a single-user
# install and under a name of its own in a multi-user install. The check
# therefore asks the collector which roots point at the shell instead of
# looking for one name, and it leaves out the root of the running shell: that
# one dies with the shell, and the claim is about what stays after it.
[ "$(readlink "$root" 2>/dev/null || true)" = "$shell_path" ] \
  || fail "the root of the development shell does not point at the shell: $root"

stays=no
protecting=""
roots="$(nix-store --query --roots "$shell_path" 2>/dev/null || true)"
while IFS= read -r line; do
  [ -n "$line" ] || continue
  case "$line" in
    *" -> "*) gcroot="${line%% -> *}"; target="${line#* -> }" ;;
    *) gcroot="$line"; target="$shell_path" ;;
  esac
  [ "$target" = "$shell_path" ] || continue
  case "$gcroot" in
    "$shell_path" | '{censored}') continue ;;
  esac
  protecting="$protecting $gcroot"
  link="$(readlink "$gcroot" 2>/dev/null || true)"
  case "$gcroot" in
    "$root") stays=yes; break ;;
  esac
  case "$link" in
    "$root" | "$shell_path") stays=yes; break ;;
  esac
done <<ROOTS
$roots
ROOTS

printf 'dev shell: the collector keeps the shell through:%s\n' "${protecting:- nothing}"
[ "$stays" = yes ] || fail "the development shell is not kept in the store: $root"

printf 'dev shell: PASS\n'
