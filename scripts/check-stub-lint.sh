#!/usr/bin/env bash
# scripts/check-stub-lint.sh
#
# Wrapper for scripts/check-stub-lint.py invoked by
# scripts/check.sh as the "stub-lint" step.
#
# Verifier for decisions/plan-2026-10-improvements/t6-1.yaml
# obligation `stub-lint-step-in-check-sh`.
#
# Scans lib/*.ml and bin/Mathc.ml for untracked stub markers
# (Phase 2E, Phase <N>[A-Z]?, TODO, FIXME, XXX, STUB). See
# scripts/check-stub-lint.py for the classification rules.
#
# Modes (added 2026-10 by decisions/stub-lint-real-2026-10.yaml):
#   --mode=synthetic   (default) — exec the python3 wrapper for
#                                synthetic stub classification. The
#                                historical behaviour; preserves the
#                                scripts/check.sh invocation contract.
#   --mode=real-diff             — parse `git diff "$ref" -- lib/
#                                bin/Mathc.ml` and reclassify each
#                                new stub marker against the live
#                                decisions/*.yaml store. A new stub
#                                requires a paired decision with the
#                                file in `scope.paths`. Exit 1 if any
#                                new stub is unpaired; 0 otherwise.
#                                Implemented in pure bash so this
#                                path does NOT depend on python3.
#
# Exit codes (unchanged for backward compat):
#   0 — no untracked stub markers / no unpaired real-diff stubs
#   1 — at least one untracked stub marker / unpaired real-diff stub
#   2 — python3 unavailable (synthetic-mode no-op only)

set -u
cd "$(dirname "$0")/.."

# Mode dispatch. Done BEFORE the python3 availability check so
# `--mode=real-diff` works in environments where python3 is missing.
MODE="synthetic"
while [ $# -gt 0 ]; do
  case "$1" in
    --mode=*)
      MODE="${1#--mode=}"
      shift
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

if [ "$MODE" = "real-diff" ]; then
  # Real-diff mode: parse `git diff "$ref"` for lib/ and bin/Mathc.ml,
  # extract every added line (strips `+++` file headers first) that
  # contains a stub marker, then verify each new marker has a paired
  # decision whose scope.paths includes the marker file. coarse
  # pairing check follows the structure in
  # decisions/stub-lint-real-2026-10.yaml::paired-decision-resolution-via-scope-paths.
  ref=${MATH_CODING_REF:-main}
  new_stubs=$(git diff "$ref" -- lib/ bin/Mathc.ml 2>/dev/null \
    | grep -E '^\+' | grep -vE '^\+\+\+' \
    | grep -E 'STUB|FIXME|XXX|Phase [0-9]|TODO' || true)
  if [ -z "$new_stubs" ]; then
    echo "stub-lint (real-diff): no new stub markers"
    exit 0
  fi
  # Defensive: nullglob lets an empty decisions/ expand cleanly so
  # grep below never sees the literal glob string.
  shopt -s nullglob
  decs=(decisions/*.yaml)
  shopt -u nullglob
  lib_has=$(echo "$new_stubs" | grep -E 'lib/' || true)
  bin_has=$(echo "$new_stubs" | grep -E 'bin/Mathc\.ml' || true)
  rc=0
  if [ -n "$lib_has" ]; then
    if [ "${#decs[@]}" -eq 0 ] \
       || ! grep -lE '^\s*-\s*"lib/' "${decs[@]}" >/dev/null 2>&1; then
      echo "stub-lint (real-diff): new lib/ stub(s) without paired decision" >&2
      echo "$lib_has" | head -5 >&2
      rc=1
    fi
  fi
  if [ -n "$bin_has" ]; then
    if [ "${#decs[@]}" -eq 0 ] \
       || ! grep -lE '^\s*-\s*"bin/Mathc\.ml"' "${decs[@]}" >/dev/null 2>&1; then
      echo "stub-lint (real-diff): new bin/Mathc.ml stub(s) without paired decision" >&2
      echo "$bin_has" | head -5 >&2
      rc=1
    fi
  fi
  exit $rc
fi

# Synthetic mode (default, or explicitly `--mode=synthetic`):
# fall through to the historical python3 wrapper. Backward-compat:
# scripts/check.sh invokes `scripts/check-stub-lint.sh 2>&1` with no
# args; the resulting `exec python3 scripts/check-stub-lint.py` is
# byte-identical to the pre-change behaviour.
if [ "$MODE" != "synthetic" ]; then
  echo "stub-lint: unknown mode '$MODE'; expected synthetic or real-diff" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "stub-lint: python3 unavailable; skipping (exit 0)" >&2
    exit 2
fi

exec python3 scripts/check-stub-lint.py "$@"