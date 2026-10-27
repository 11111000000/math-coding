#!/usr/bin/env bash
# math-coding 3.3: the formatting gate.
#
# obligation ocamlformat-fmt-clean: the OCaml tree is fully
# normalized. Returns 0 iff it is.
#
# WHY THIS IS NOT `dune fmt --preview`.
#
# It was, until 2026-10-27, and it was a source of red steps that
# had nothing to do with formatting. dune's `fmt --preview` with
# promotion disabled MAY NOT WRITE, and a dune command that may not
# write cannot be handed over to a running dune instance -- it
# aborts with "Another Dune instance is currently running". So the
# check failed whenever the previous step happened to leave a dune
# instance alive, and the tree was perfectly formatted.
#
# That is the worst shape for a gate: a red step decided by
# scheduling. Measured on 2026-10-27 in `scripts/dev verify`: stage
# 2 runs `dune test`, stage 3 runs this check, and stage 3 failed
# with the message above on a formatted tree. The formatting check
# was failing in CI for a month and nobody could see why, because
# the message was about a lock and not about a format.
#
# `ocamlformat --check` asks the same question with no lock at all:
# it reads the same `.ocamlformat` (profile = conventional, margin =
# 80) that dune's `fmt` reads, and it answers "would this file
# change?" per file. The gate is the same gate; it just does not
# need the build directory.
#
# The files checked are the ones git tracks, under lib/, bin/ and
# tests/ -- the OCaml tree.
#
# THE NEGATIVE CONTROL. A check that cannot fail is a decoration, so
# the gate proves it can: it formats a deliberately misformatted
# probe and requires the check to REJECT it. Without the control, a
# gate whose file list came out empty would report "clean" and mean
# nothing.
#
# EXIT: 0 when the tree is formatted. 1 when it is not, or when the
# control failed. 2 when the measurement could not be taken.

set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v ocamlformat >/dev/null 2>&1; then
  echo "fmt-check: SKIP (ocamlformat is not on PATH)" >&2
  exit 2
fi

files=$(git ls-files '*.ml' '*.mli' 2>/dev/null)
if [ -z "$files" ]; then
  echo "fmt-check: FAIL -- no OCaml files are tracked, so there is nothing" \
       "to check and 'clean' would mean nothing" >&2
  exit 1
fi

bad=""
for f in $files; do
  if ! ocamlformat --check "$f" >/dev/null 2>&1; then
    bad="$bad $f"
  fi
done

if [ -n "$bad" ]; then
  echo "fmt-check: FAIL -- these files are not formatted:" >&2
  for f in $bad; do
    echo "  $f" >&2
    ocamlformat --diff "$f" 2>/dev/null | head -20 >&2 || true
  done
  echo "run 'dune fmt' to normalize them." >&2
  exit 1
fi

# The negative control: a misformatted file MUST be rejected.
control_dir=$(mktemp -d)
trap 'rm -f "$control_dir/probe.ml" "$control_dir/probe.ml.formatted"; rm -rf "$control_dir"' EXIT
cat > "$control_dir/probe.ml" <<'PROBE'
let probe=match[]with[]->1
let ()=ignore probe
PROBE
# The probe lives outside the repository, so it inherits no
# `.ocamlformat`; give it the same one the tree uses, or the
# control would be measuring a different profile than the gate.
cp .ocamlformat "$control_dir/.ocamlformat" 2>/dev/null || true
if ocamlformat --check "$control_dir/probe.ml" >/dev/null 2>&1; then
  echo "fmt-check: FAIL -- the negative control was ACCEPTED, so the check" \
       "accepts unformatted files and the gate above proves nothing" >&2
  exit 1
fi

echo "fmt-check: clean ($(echo "$files" | wc -w | tr -d ' ') files)"
exit 0
