#!/usr/bin/env bash
# infrastructure-honesty: flake-ref-is-commit fixture
#
# Asserts that flake.nix inputs.nixpkgs points to a specific commit
# hash, not a branch reference. This is the positive fixture for
# obligation pin-nixpkgs-commit in
# bootstrap/infrastructure-honesty.yaml.
#
# Exits 0 if nixpkgs is pinned to a commit hash, non-zero if it
# tracks a branch.

set -eu
cd "$(dirname "$0")/../.."

echo "flake-ref-is-commit:"

# Extract nixpkgs URL from flake.nix. We use grep + cut for portability;
# parsing full Nix is overkill for a single URL check.
url=$(grep -E '^\s*nixpkgs\.url\s*=' flake.nix | head -1 | sed -E 's/.*=\s*"([^"]+)".*/\1/')

if [ -z "$url" ]; then
  echo "  FAIL no nixpkgs.url found in flake.nix" >&2
  exit 1
fi

echo "  nixpkgs.url = $url"

# nixpkgs URL forms:
#   github:NixOS/nixpkgs/nixos-unstable          <- branch, NOT OK
#   github:NixOS/nixpkgs/<40-char-hex>           <- commit, OK
#   github:NixOS/nixpkgs/release-24.05           <- release branch, NOT OK
#
# A commit is a 40-character SHA1 hex string.
case "$url" in
  github:NixOS/nixpkgs/[a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9])
    echo "  ok   nixpkgs is pinned to a commit hash"
    exit 0 ;;
  github:NixOS/nixpkgs/*)
    echo "  FAIL nixpkgs tracks a branch or tag: ${url##*/}" >&2
    echo "       (per A1 reproducibility, only commit hashes are accepted)" >&2
    exit 1 ;;
  *)
    echo "  FAIL unrecognised nixpkgs URL: $url" >&2
    exit 1 ;;
esac
