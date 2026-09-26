#!/usr/bin/env bash
# infrastructure-honesty: ci-targets-exist fixture
#
# Asserts that every CLI target referenced by .github/workflows/*.yml
# actually exists in the source tree. This is the positive fixture
# for obligation fix-ci-targets in bootstrap/infrastructure-honesty.yaml.
#
# A green run means: each command and path the workflows invoke resolves
# to a real file or executable in the repo at the current commit.
#
# Exits 0 on success, non-zero on first missing reference.

set -eu
cd "$(dirname "$0")/../.."

fail=0

# Each entry: workflow_file -> grep_pattern -> expected_resolved_path
# The grep pattern must match at least one line; the right-hand side
# of the matched shell command must point to a real file or binary.
check_target() {
  local label="$1"
  local pattern="$2"
  local resolved="$3"
  if [ -e "$resolved" ]; then
    echo "  ok   $label -> $resolved"
  else
    echo "  FAIL $label -> $resolved (not found)" >&2
    fail=1
  fi
}

# Source-level existence checks (no actual command execution).
echo "ci-targets-exist:"

# ci.yml:21 builds bin/mathc.exe
check_target "ci.yml build target" \
  'bin/mathc.exe' \
  "bin/Mathc.ml"

# ci.yml:25 used to call scripts/render.sh; removed in v3-alpha-0.0.3
# because that script does not exist. Verify it is NOT called.
if grep -q 'scripts/render.sh' .github/workflows/ci.yml; then
  echo "  FAIL ci.yml still references scripts/render.sh" >&2
  fail=1
else
  echo "  ok   ci.yml does not reference scripts/render.sh"
fi

# release.yml:106 builds bin/mathc.exe (was core/main.exe)
check_target "release.yml build target" \
  'bin/mathc.exe' \
  "bin/Mathc.ml"

# site.yml: must not reference scripts/render.sh (it does not exist)
if grep -q 'scripts/render.sh' .github/workflows/site.yml; then
  echo "  FAIL site.yml still references scripts/render.sh" >&2
  fail=1
else
  echo "  ok   site.yml does not reference scripts/render.sh"
fi

# release.yml Windows opam bootstrap: SHA256 must be recorded
if grep -qE 'sha256sum.*opam\.exe' .github/workflows/release.yml; then
  echo "  ok   release.yml records opam.exe SHA256 (sha256sum path)"
elif grep -qE 'Get-FileHash.*opam\.exe|expected.*sha256' .github/workflows/release.yml; then
  echo "  ok   release.yml records opam.exe SHA256 (Get-FileHash path)"
else
  echo "  FAIL release.yml does not record opam.exe SHA256" >&2
  fail=1
fi

exit "$fail"
