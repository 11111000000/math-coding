#!/usr/bin/env bash
# tests/fixtures/ci-prereqs-precede-consumers.sh
#
# Failure-first fixture for the two red-CI causes observed on
# 2026-10-20, both pre-existing for 8-10 consecutive commits:
#
# (A) ORDERING. `.github/workflows/ci.yml` sets
#     `build-dir = /tmp/nix-build` in the install-nix step's
#     extra_nix_config, but install-nix-action does not CREATE that
#     directory. A "Prepare nix build dir" step exists and even
#     documents the crash verbatim — but it sits ~27 lines BELOW
#     the `scripts/dev verify` step that needs it. So verify dies
#     with:
#         error: creating directory
#         '/tmp/nix-build/nix-build-math-coding-dev-test-env.drv-0':
#         No such file or directory
#     The fix that already exists in the file is simply applied too
#     late to help. This fixture asserts ordering, not presence.
#
# (B) MISSING SOURCE. Dockerfile.debian-slim stage 1 copies only
#     flake.nix, flake.lock and VERSION, but builds `.#default`,
#     whose `packages.default` declares `src = ./.` — the whole
#     tree. With no lib/ and bin/ in /src, the derivation fails:
#         Error: Don't know how to build bin/mathc.exe
#     This fixture asserts the Dockerfile stages the source.
#
# Neither (A) nor (B) was introduced by
# decisions/nix-develop-store-lock-contention-2026-10.yaml; both
# predate it. They are asserted here so the red CI has a named,
# reproducible owner instead of being rediscovered each push.

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
ok()  { printf 'ok: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; fail=1; }

wf=".github/workflows/ci.yml"

# --- (A) ordering --------------------------------------------------------
if [ ! -f "$wf" ]; then
  bad "$wf missing"
else
  mkdir_line=$(grep -n 'mkdir -p /tmp/nix-build' "$wf" | head -1 | cut -d: -f1)
  verify_line=$(grep -n 'run: ./scripts/dev verify' "$wf" | head -1 | cut -d: -f1)

  if [ -z "$mkdir_line" ]; then
    bad "no 'mkdir -p /tmp/nix-build' step in $wf"
  elif [ -z "$verify_line" ]; then
    bad "no 'run: ./scripts/dev verify' step in $wf"
  elif [ "$mkdir_line" -lt "$verify_line" ]; then
    ok "build dir is prepared (line $mkdir_line) before scripts/dev verify (line $verify_line)"
  else
    bad "build dir prepared at line $mkdir_line, AFTER scripts/dev verify at line $verify_line — verify crashes on a fresh runner"
  fi
fi

# --- (B) docker stage-1 source ------------------------------------------
df="Dockerfile.debian-slim"
if [ ! -f "$df" ]; then
  bad "$df missing"
else
  # Does the build stage copy the tree, not just the flake files?
  if grep -qE '^COPY[[:space:]]+(\.|src/|lib/|bin/)' "$df"; then
    ok "$df stages repository source into the build stage"
  else
    bad "$df copies only flake/VERSION; '.#default' has src = ./. and cannot find bin/mathc.exe"
  fi

  # A naive 'COPY . /src/' would drag _build (283 MB) and .git into
  # the build context unless excluded, so require the exclusions.
  if [ -f .dockerignore ]; then
    ok ".dockerignore present"
    missing=""
    for pat in _build .git; do
      grep -qx "$pat" .dockerignore 2>/dev/null || missing="$missing $pat"
    done
    if [ -z "$missing" ]; then
      ok ".dockerignore excludes _build and .git"
    else
      bad ".dockerignore does not exclude:$missing"
    fi
  else
    bad ".dockerignore missing; 'COPY . /src/' would ship _build (283 MB) into the image"
  fi

  # (B2) The nix-built binary bakes an absolute ELF interpreter path
  # into /nix/store/<hash>-glibc-*/lib/ld-linux-x86-64.so.2. The
  # runtime stage must therefore carry the nix closure at its original
  # store paths, or `mathc version` fails with a misleading
  # "not found" that looks like a missing file rather than a missing
  # loader. Same root cause as OCAML_KERNEL_CONVENTIONS.md 11.22.
  if grep -q 'nix-store --query --requisites' "$df" && grep -q 'COPY --from=build /tmp/closure/nix /nix' "$df"; then
    ok "$df ships the nix runtime closure at its original store paths"
  else
    bad "$df does not ship /nix/store closure; the nix-linked binary cannot start"
  fi
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "ci-prereqs-precede-consumers: PASS"
  exit 0
fi
echo "ci-prereqs-precede-consumers: FAIL"
exit 1