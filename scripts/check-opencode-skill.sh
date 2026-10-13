#!/usr/bin/env bash
# Verifier wrapper for ux-3-repo-tracked-opencode-skill-2026-10.yaml.
# Closes the obligation by checking that
# .opencode/skills/math-coding/SKILL.md is a verbatim copy of
# adoption/SKILL.md (the canonical skill source).
#
# Exits 0 on full pass, 1 on any failure.

set -eu

cd "$(git rev-parse --show-toplevel)"

src="adoption/SKILL.md"
target=".opencode/skills/math-coding/SKILL.md"

if [ ! -f "$src" ]; then
  echo "FAIL: source $src does not exist" >&2
  exit 1
fi

if [ ! -f "$target" ]; then
  echo "FAIL: $target does not exist" >&2
  echo "  Re-run: cp $src $target" >&2
  exit 1
fi

if ! cmp -s "$src" "$target"; then
  echo "FAIL: $target is not byte-for-byte identical to $src" >&2
  echo "  Re-run: cp $src $target" >&2
  exit 1
fi

echo "PASS: opencode skill in-repo matches $src byte-for-byte"
