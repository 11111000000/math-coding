#!/bin/sh
set -eu

repo="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
bin_dir="${MATHC_INSTALL_DIR:-$HOME/.local/bin}"
skill_dir="${MATHC_SKILL_DIR:-$HOME/.agents/skills/math-coding}"
force="${MATHC_INSTALL_FORCE:-0}"

usage() {
  cat <<'EOF'
usage: sh install.sh [--bin-dir DIR] [--skill-dir DIR] [--force]

Install static mathc and mathc-stand, then the math-coding agent skill.
Defaults:
  binaries: ~/.local/bin
  skill:    ~/.agents/skills/math-coding

MATHC_PACKAGE may name an existing portable package for offline installation.
MATHC_INSTALL_DIR and MATHC_SKILL_DIR provide the same path overrides.
--force permits upgrades and preserves replaced files as NAME.backup[.PID].
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --bin-dir)
      [ "$#" -ge 2 ] || { printf 'install: --bin-dir needs a path\n' >&2; exit 2; }
      bin_dir="$2"
      shift 2
      ;;
    --skill-dir)
      [ "$#" -ge 2 ] || { printf 'install: --skill-dir needs a path\n' >&2; exit 2; }
      skill_dir="$2"
      shift 2
      ;;
    --force)
      force=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'install: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "${MATHC_PACKAGE:-}" ]; then
  (cd "$repo" && nix build .#portable --no-link)
  package="$(cd "$repo" && nix path-info .#portable)"
else
  package="$MATHC_PACKAGE"
fi

if [ ! -x "$package/bin/mathc" ] || [ ! -x "$package/bin/stand" ]; then
  printf 'install: not a mathc portable package: %s\n' "$package" >&2
  exit 2
fi
for required in \
  "$repo/skills/math-coding/SKILL.md" \
  "$repo/skills/math-coding/references/PROJECT-SETUP.md" \
  "$repo/skills/math-coding/references/METHODOLOGY.md"
do
  if [ ! -f "$required" ]; then
    printf 'install: agent skill file is missing: %s\n' "$required" >&2
    exit 2
  fi
done

mkdir -p "$bin_dir" "$skill_dir/references"
cleanup() {
  rm -f "$bin_dir/mathc.tmp.$$" "$bin_dir/mathc-stand.tmp.$$" \
    "$bin_dir/mathc.candidate.$$" "$bin_dir/mathc-stand.candidate.$$" \
    "$bin_dir/mathc.build-id.tmp.$$" "$skill_dir/SKILL.md.tmp.$$" \
    "$skill_dir/references/PROJECT-SETUP.md.tmp.$$" \
    "$skill_dir/references/METHODOLOGY.md.tmp.$$"
}
trap cleanup EXIT HUP INT TERM

copy_file() {
  source="$1"
  destination="$2"
  mode="$3"
  if [ -e "$destination" ] && ! cmp -s "$source" "$destination"; then
    if [ "$force" != "1" ]; then
      printf 'install: refusing to overwrite %s; inspect it or use --force\n' "$destination" >&2
      exit 2
    fi
    backup="$destination.backup"
    if [ -e "$backup" ]; then backup="$backup.$$"; fi
    cp -p "$destination" "$backup"
    printf 'backup: %s\n' "$backup"
  fi
  temporary="$destination.tmp.$$"
  if [ "$source" != "$temporary" ]; then cp "$source" "$temporary"; fi
  chmod "$mode" "$temporary"
  mv -f "$temporary" "$destination"
}

candidate="$bin_dir/mathc.candidate.$$"
candidate_stand="$bin_dir/mathc-stand.candidate.$$"
cp "$package/bin/mathc" "$candidate"
cp "$package/bin/stand" "$candidate_stand"
chmod 0755 "$candidate" "$candidate_stand"
if ! version="$("$candidate" --version 2>&1)"; then
  printf 'install: candidate mathc does not run:\n%s\n' "$version" >&2
  exit 1
fi
if ! printf '%s\n' "$version" | grep -q '^mathc 5$'; then
  printf 'install: unexpected mathc version:\n%s\n' "$version" >&2
  exit 1
fi
if ! "$candidate_stand" --help >/dev/null 2>&1; then
  printf 'install: candidate mathc-stand does not run\n' >&2
  exit 1
fi
copy_file "$candidate" "$bin_dir/mathc" 0755
copy_file "$candidate_stand" "$bin_dir/mathc-stand" 0755
rm -f "$candidate" "$candidate_stand"

build="$(sha256sum "$bin_dir/mathc")"
build="${build%% *}"
metadata="$bin_dir/mathc.build-id.tmp.$$"
printf 'version=5\nbuild=%s\n' "$build" > "$metadata"
copy_file "$metadata" "$bin_dir/mathc.build-id" 0644

copy_file "$repo/skills/math-coding/SKILL.md" "$skill_dir/SKILL.md" 0644
copy_file "$repo/skills/math-coding/references/PROJECT-SETUP.md" \
  "$skill_dir/references/PROJECT-SETUP.md" 0644
copy_file "$repo/skills/math-coding/references/METHODOLOGY.md" \
  "$skill_dir/references/METHODOLOGY.md" 0644

printf 'mathc: %s\nmathc-stand: %s\nskill: %s\n' \
  "$bin_dir/mathc" "$bin_dir/mathc-stand" "$skill_dir/SKILL.md"
case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) printf 'Add the binaries to PATH:\n  export PATH="%s:$PATH"\n' "$bin_dir" ;;
esac
printf 'next: mathc --help\n'
