#!/usr/bin/env bash
# scripts/export-core.sh -- cut the transferable protocol core out of this
# repository.
#
# The boundary in docs/plans/redundancy-and-portability-2026-11.md is not a
# promise made only in prose. This script is its executable form:
#
#   * the kernel is lib/ and bin/;
#   * policies.yaml is the policy artifact;
#   * decisions/ and attestations/ are exported as EMPTY protocol artifact
#     directories, never as this repository's corpus and evidence store;
#   * adoption/SKILL.md is the canonical agent skill;
#   * dune-project, math-coding.opam and VERSION are the build metadata and
#     version identity needed to build and run the exported kernel.
#
# Everything else in this repository is project support and stays behind:
# the site, the plugin, the conformance corpus, release tooling and the book.
# The script prints both sides of that cut and refuses to publish a tree that
# contains anything outside the allowlist.
#
# Usage: scripts/export-core.sh [DEST]
#
# DEST defaults to _build/export/core/. A relative DEST is resolved from the
# current working directory. An existing DEST is replaced only when it is
# empty or carries this script's marker; the script will not delete an
# unrelated directory.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
readonly SCRIPT_DIR ROOT
readonly MARKER=".export-core-boundary"

usage() {
  printf 'usage: %s [DEST]\n' "${0##*/}"
  printf '       default DEST: %s\n' "$ROOT/_build/export/core"
}

die() {
  printf 'export-core: %s\n' "$*" >&2
  exit 1
}

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi

dest_arg="${1:-$ROOT/_build/export/core}"
if [[ "$dest_arg" = /* ]]; then
  dest="$dest_arg"
else
  dest="$(pwd -P)/$dest_arg"
fi
dest="$(realpath -m -- "$dest")"

# The destination must not be the repository itself, an ancestor of it, or a
# directory inside one of the copied source trees. The default lives under
# _build/, which is safe and is ignored by git.
case "$dest" in
  "/"|"$ROOT")
    die "refusing to use '$dest' as the export destination"
    ;;
esac
case "$ROOT/" in
  "$dest/"*)
    die "refusing to use '$dest': it is an ancestor of the repository"
    ;;
esac
case "$dest/" in
  "$ROOT/lib/"*|"$ROOT/bin/"*|"$ROOT/adoption/"*)
    die "refusing to export into a source tree: '$dest'"
    ;;
esac

if [ -e "$dest" ]; then
  [ -d "$dest" ] || die "destination exists and is not a directory: '$dest'"
  [ ! -L "$dest" ] || die "destination is a symbolic link: '$dest'"
  if [ -n "$(find "$dest" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    [ -f "$dest/$MARKER" ] ||
      die "destination is not empty and was not created by export-core: '$dest'"
  fi
fi

parent="$(dirname -- "$dest")"
mkdir -p -- "$parent"
stage="$(mktemp -d "$parent/.export-core-stage.XXXXXX")"
cleanup() {
  if [ -n "${stage:-}" ] && [ -d "$stage" ]; then
    rm -rf -- "$stage"
  fi
}
trap cleanup EXIT INT TERM

cp -a -- "$ROOT/lib" "$ROOT/bin" "$stage/"
cp -- "$ROOT/dune-project" "$ROOT/math-coding.opam" \
  "$ROOT/VERSION" "$ROOT/policies.yaml" "$stage/"
mkdir -p -- "$stage/adoption" "$stage/decisions" "$stage/attestations"
cp -- "$ROOT/adoption/SKILL.md" "$stage/adoption/SKILL.md"

cat > "$stage/$MARKER" <<'EOF'
math-coding exportable-core-boundary/1

This marker identifies a directory produced by scripts/export-core.sh.
The export contains the kernel, policies.yaml, the three protocol artifact
locations (decisions/, attestations/, policies.yaml), the canonical skill,
and the build metadata needed to compile the kernel. It contains no project
site, plugin, conformance corpus, release tooling or book.
EOF

# Check the staged tree before publishing it. This is intentionally an exact
# path allowlist: a file that is merely mentioned by a forbidden directory
# must not escape because its name is unfamiliar.
check_export_tree() {
  local tree="$1"
  local path
  local rc=0

  for required in \
    VERSION \
    dune-project \
    math-coding.opam \
    policies.yaml \
    adoption/SKILL.md \
    lib/dune \
    bin/dune; do
    if [ ! -f "$tree/$required" ]; then
      printf 'export-core: required path is missing: %s\n' "$required" >&2
      rc=1
    fi
  done

  while IFS= read -r path; do
    case "$path" in
      VERSION|dune-project|math-coding.opam|policies.yaml|\
      .export-core-boundary|adoption|adoption/SKILL.md|\
      lib|lib/*|bin|bin/*|decisions|attestations)
        ;;
      *)
        printf 'export-core: path is not part of the protocol: %s\n' "$path" >&2
        rc=1
        ;;
    esac
  done < <(cd "$tree" && find . -mindepth 1 -printf '%P\n' | LC_ALL=C sort)

  for artifact_dir in decisions attestations; do
    if [ ! -d "$tree/$artifact_dir" ]; then
      printf 'export-core: protocol artifact directory is missing: %s\n' \
        "$artifact_dir" >&2
      rc=1
    elif [ -n "$(find "$tree/$artifact_dir" -mindepth 1 -print -quit)" ]; then
      printf 'export-core: protocol artifact directory is not empty: %s\n' \
        "$artifact_dir" >&2
      rc=1
    fi
  done

  if [ -n "$(find "$tree" -type l -print -quit)" ]; then
    printf 'export-core: the export contains a symbolic link\n' >&2
    rc=1
  fi

  return "$rc"
}

if ! check_export_tree "$stage"; then
  die "the staged export does not satisfy the protocol boundary"
fi

if [ -e "$dest" ]; then
  rm -rf -- "$dest"
fi
mv -- "$stage" "$dest"
stage=""
trap - EXIT INT TERM

lib_files="$(find "$dest/lib" -type f | wc -l | tr -d ' ')"
bin_files="$(find "$dest/bin" -type f | wc -l | tr -d ' ')"

printf 'export-core: wrote %s\n\n' "$dest"
printf 'included (part of the protocol):\n'
printf '  bin/ (%s files)\n' "$bin_files"
printf '  lib/ (%s files)\n' "$lib_files"
printf '  policies.yaml (policy artifact; also artifact 3/3 in plan section 0)\n'
printf '  decisions/ (artifact 1/3: empty protocol artifact directory)\n'
printf '  attestations/ (artifact 2/3: empty protocol artifact directory)\n'
printf '  adoption/SKILL.md (canonical agent skill)\n'
printf '  VERSION, dune-project, math-coding.opam (build and version metadata)\n'

printf '\nnot part of the protocol (remains in the source repository):\n'
while IFS= read -r entry; do
  case "$entry" in
    .git|_build|bin|lib|adoption|decisions|attestations|VERSION|\
    dune-project|math-coding.opam|policies.yaml)
      ;;
    *)
      if [ -d "$ROOT/$entry" ]; then
        printf '  %s/\n' "$entry"
      else
        printf '  %s\n' "$entry"
      fi
      ;;
  esac
done < <(find "$ROOT" -mindepth 1 -maxdepth 1 -printf '%f\n' | LC_ALL=C sort)
printf '  adoption/ (only the canonical SKILL.md was exported)\n'
printf '  decisions/ (this repository corpus stays; the exported artifact directory is empty)\n'
if [ -d "$ROOT/attestations" ]; then
  printf '  attestations/ (this repository evidence store stays; the exported artifact directory is empty)\n'
fi
