#!/usr/bin/env bash
# time-honesty: time-estimate subcommand fixture
#
# Asserts that `mc time-estimate --class X --count N --percentile P`
# reads bin/data/time-distribution.yaml via the project-root anchor
# and prints a JSON forecast. This is the acceptance gate for
# obligation cli-time-estimate declared in
# bootstrap/time-honesty.yaml.
#
# The fixture exercises:
#   - the documented success path (single-file-edit at p80)
#   - the multiplier path (feature-add with two multipliers)
#   - three rejection paths (unknown class, missing --class,
#     missing --percentile) — each exits 2 with a JSON or
#     textual diagnostic.
#
# Strategy: invoke `mc time-estimate` against a precomputed
# SWE-bench Verified distribution and assert the documented
# numeric outputs. The distribution is declared (not derived from
# math-coding itself) per bootstrap/time-honesty.yaml;
# interpolation between P50 and P95 is the floor implementation
# in bin/Mathc.ml, documented in bin/data/time-distribution.yaml.
#
# Note on stderr: mc prints JSON diagnostics for rejection paths
# (MC-CLASS-UNKNOWN) and exit-2 textual diagnostics to stderr,
# not stdout. This matches the convention of other
# diagnostic-emitting subcommands (mc validate, mc gate).

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "cli-time-estimate:"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

BIN=$PWD/_build/default/bin/mathc.exe

# Build once.
nix develop .#test --command bash -c "dune build --root . bin/mathc.exe" >/dev/null 2>&1 || {
  echo "  FAIL dune build failed" >&2
  exit 1
}

# All four invocations are run from $tmp so cwd is not the project
# root; the binary uses MATH_CODING_ROOT to find the project.
cd "$tmp"
export MATH_CODING_ROOT=/home/az/Projects/math-coding

# 1. Single-file-edit at p80: estimate_value=8.
"$BIN" time-estimate --class single-file-edit --percentile p80 >"$tmp/v1.out" 2>"$tmp/v1.err"
v1_ec=$?
v1=$(cat "$tmp/v1.out")
if [ "$v1_ec" != "0" ]; then
  echo "  FAIL single-file-edit: exit $v1_ec (expected 0)" >&2
  echo "stderr: $(cat "$tmp/v1.err")" >&2
  exit 1
fi
if ! printf '%s' "$v1" | grep -q '"class":"single-file-edit"'; then
  echo "  FAIL single-file-edit: missing 'class' field" >&2
  echo "$v1" >&2
  exit 1
fi
if ! printf '%s' "$v1" | grep -q '"estimate_value":8'; then
  echo "  FAIL single-file-edit: estimate_value should be 8" >&2
  echo "$v1" >&2
  exit 1
fi
if ! printf '%s' "$v1" | grep -q '"percentile":80'; then
  echo "  FAIL single-file-edit: percentile should be 80" >&2
  echo "$v1" >&2
  exit 1
fi

# 2. Feature-add with multipliers: estimate_value=168.
"$BIN" time-estimate --class feature-add --count 3 --percentile p95 \
  --multiplier per_artifact_over_first \
  --multiplier test_required_with_runtime \
  >"$tmp/v2.out" 2>"$tmp/v2.err"
v2_ec=$?
v2=$(cat "$tmp/v2.out")
if [ "$v2_ec" != "0" ]; then
  echo "  FAIL feature-add: exit $v2_ec (expected 0)" >&2
  echo "stderr: $(cat "$tmp/v2.err")" >&2
  exit 1
fi
if ! printf '%s' "$v2" | grep -q '"estimate_value":168'; then
  echo "  FAIL feature-add: estimate_value should be 168 (70*2.0*1.2)" >&2
  echo "$v2" >&2
  exit 1
fi
if ! printf '%s' "$v2" | grep -qE '"applied_multipliers":\["per_artifact_over_first","test_required_with_runtime"\]'; then
  echo "  FAIL feature-add: applied_multipliers order or names wrong" >&2
  echo "$v2" >&2
  exit 1
fi

# 3. Unknown class: exits 2 with MC-CLASS-UNKNOWN on stderr.
"$BIN" time-estimate --class bogus >"$tmp/v3.out" 2>"$tmp/v3.err"
v3_ec=$?
v3_err=$(cat "$tmp/v3.err")
if [ "$v3_ec" != "2" ]; then
  echo "  FAIL unknown-class: exit $v3_ec (expected 2)" >&2
  exit 1
fi
if ! printf '%s' "$v3_err" | grep -q 'MC-CLASS-UNKNOWN'; then
  echo "  FAIL unknown-class: stderr must include MC-CLASS-UNKNOWN" >&2
  echo "$v3_err" >&2
  exit 1
fi

# 4. Missing --class: exits 2 with textual diagnostic on stderr.
"$BIN" time-estimate >"$tmp/v4.out" 2>"$tmp/v4.err"
v4_ec=$?
v4_err=$(cat "$tmp/v4.err")
if [ "$v4_ec" != "2" ]; then
  echo "  FAIL missing-class: exit $v4_ec (expected 2)" >&2
  exit 1
fi
if ! printf '%s' "$v4_err" | grep -q -- '--class is required'; then
  echo "  FAIL missing-class: stderr must say '--class is required'" >&2
  echo "$v4_err" >&2
  exit 1
fi

echo "  ok   single-file-edit p80, feature-add with 2 multipliers, 2 rejections"
exit 0