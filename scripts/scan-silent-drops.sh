#!/usr/bin/env bash
# scripts/scan-silent-drops.sh -- reproducible scan for YAML the kernel
# does not read all of.
#
# Every occurrence of MC-UNPARSED-TAIL or MC-DUPLICATE-KEY is a place
# where a decision file says more than the kernel reads.  The
# diagnostic already exists; this script makes the LIST reproducible,
# because a defect class nobody can re-run is a defect class nobody
# re-fixes.  It is the command recorded under the obligation
# `corpus-scan-is-reproducible` in
# decisions/corpus-silent-drop-inventory-2026-10.yaml.
#
# Usage:
#   scripts/scan-silent-drops.sh                 # scan decisions/ + policies.yaml
#   scripts/scan-silent-drops.sh --all           # scan every tracked *.yaml / *.yml
#   scripts/scan-silent-drops.sh --validity      # additionally ask an independent
#                                                 # YAML reader (yq) whether each
#                                                 # offender is valid YAML at all
#
# `yq` is used only when --validity is passed and yq is on PATH; it is
# advisory, never load-bearing.  The verdict this script prints comes
# from the kernel, which is the thing under test.
#
# Exit codes:
#   0  scan completed (offenders may be present; they are printed)
#   2  the mathc binary is missing or unusable
#
# This script is a REPORT, not a gate.  The gate is
# tests/corpus_no_silent_drops/corpus_no_silent_drops.exe, which fails
# when the measured set stops matching the recorded one.

set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 2

MATHC="${MATHC_BIN:-_build/install/default/bin/mathc}"
scope="decisions"
with_validity=0

for arg in "$@"; do
  case "$arg" in
    --all) scope="all" ;;
    --validity) with_validity=1 ;;
    -h | --help)
      # Print every leading comment line.  A fixed line range rots the
      # moment the header grows -- an earlier revision of this script
      # cut the "Exit codes" section off by one line and said nothing.
      sed -n '2,${/^#/!q;s/^# \?//p;}' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

if [ ! -x "$MATHC" ]; then
  echo "scan-silent-drops: $MATHC not built." >&2
  echo "  build it with:  nix develop .#test --command dune build --root . @install" >&2
  echo "  or point MATHC_BIN at a built binary." >&2
  exit 2
fi

if [ "$scope" = "all" ]; then
  mapfile -t files < <(git ls-files '*.yaml' '*.yml' | sort)
else
  mapfile -t files < <(printf '%s\n' decisions/*.yaml policies.yaml)
fi

# Every line the kernel prints for a file, stderr included: the
# diagnostics live on stderr while the verdict line goes to stdout.
scan_one() {
  "$MATHC" validate "$1" 2>&1 |
    grep -oE 'MC-(DUPLICATE-KEY|UNPARSED-TAIL)' |
    sort -u |
    paste -sd, -
}

validity_of() {
  # Three values, and the third one exists because a two-valued
  # answer lies here:
  #   VALID     an independent reader parsed the file as one document
  #   MULTI-DOC the file is a YAML STREAM (>= 2 top-level `---` markers).
  #             That is legal YAML 1.2, but the kernel reads one document
  #             per decision file, so the reader below refuses it for
  #             being a stream rather than for being malformed. Reporting
  #             INVALID here would blame the author for our own contract.
  #   INVALID   the reader rejected a single-document file
  #   unknown   no independent reader on PATH
  local markers
  markers=$(grep -c '^---[[:space:]]*$' "$1" 2>/dev/null || echo 0)
  if [ "$markers" -ge 2 ]; then
    echo MULTI-DOC
  elif ! command -v yq >/dev/null 2>&1; then
    echo unknown
  elif yq -e '.' "$1" >/dev/null 2>&1; then
    echo VALID
  else
    echo INVALID
  fi
}

offenders=0
total=0
for f in "${files[@]}"; do
  [ -f "$f" ] || continue
  total=$((total + 1))
  codes="$(scan_one "$f")"
  [ -n "$codes" ] || continue
  offenders=$((offenders + 1))
  if [ "$with_validity" -eq 1 ]; then
    printf '%s\t%s\t%s\n' "$(validity_of "$f")" "$codes" "$f"
  else
    printf '%s\t%s\n' "$codes" "$f"
  fi
done

echo "scan-silent-drops: $offenders of $total file(s) carry a silent-drop diagnostic" >&2
[ "$with_validity" -eq 1 ] &&
  echo "column 1 is an independent reader's verdict: INVALID = the AUTHOR wrote invalid YAML, VALID/MULTI-DOC = the KERNEL lost it" >&2
exit 0
