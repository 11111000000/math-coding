#!/bin/sh
set -eu

mode="${1:-default}"
work="$(mktemp -d "${TMPDIR:-/tmp}/mathc-package-smoke.XXXXXX")"
trap 'rm -rf "$work"' EXIT HUP INT TERM
project="$work/project"

case "$mode" in
  default)
    nix build .#default .#stand --no-link
    mathc_bin="$(nix path-info .#default)/bin/mathc"
    stand_bin="$(nix path-info .#stand)/bin/stand"
    ;;
  portable)
    nix build .#portable --no-link
    package="$(nix path-info .#portable)"
    mkdir -p "$work/bin"
    cp "$package/bin/mathc" "$work/bin/mathc"
    cp "$package/bin/stand" "$work/bin/stand"
    mathc_bin="$work/bin/mathc"
    stand_bin="$work/bin/stand"
    for binary in "$mathc_bin" "$stand_bin"; do
      file "$binary" | grep -q 'statically linked'
      if ldd "$binary" >/dev/null 2>&1; then
        printf 'portable binary is dynamically linked: %s\n' "$binary" >&2
        exit 1
      fi
    done
    MATHC_PACKAGE="$package" MATHC_INSTALL_DIR="$work/installed-bin" \
      MATHC_SKILL_DIR="$work/agent-skill" sh install.sh
    mathc_bin="$work/installed-bin/mathc"
    stand_bin="$work/installed-bin/mathc-stand"
    test -f "$work/agent-skill/SKILL.md"
    test -f "$work/agent-skill/references/PROJECT-SETUP.md"
    test -f "$work/agent-skill/references/METHODOLOGY.md"
    ;;
  *)
    printf 'usage: sh test/package_smoke.sh [default|portable]\n' >&2
    exit 2
    ;;
esac

"$mathc_bin" --version
"$mathc_bin" --help >/dev/null
git init -q "$project"
"$mathc_bin" --root "$project" init
"$mathc_bin" --root "$project" goal "the subject is expected" subject.txt owner
printf 'expected\n' > "$project/subject.txt"
"$mathc_bin" --root "$project" add sample "the subject is expected" subject.txt "not expected" fact \
  --requirement "verifier:grep -q expected subject.txt" \
  --control "printf broken > subject.txt"
"$mathc_bin" --root "$project" run
"$mathc_bin" --root "$project" map
"$stand_bin" "$project" \
  --human-minutes 1 --agent-tokens 100 --person-minute-cost 1 \
  --machine-second-cost 0.1 --token-cost 0.01 --defect-cost 100
"$mathc_bin" --root "$project" install
"$mathc_bin" --root "$project" doctor
printf 'package smoke (%s): PASS\n' "$mode"
