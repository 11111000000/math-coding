#!/usr/bin/env bash
# scripts/generate-attestations-site-deploy-3.sh
#
# Adds attestations for the site-deploy@3 obligation
# `extended-markdown-subset`. Idempotent: existing files are
# overwritten with the same canonical-JSON-derived sha256.
#
# Usage:
#   scripts/generate-attestations-site-deploy-3.sh

set -euo pipefail
cd "$(dirname "$0")/.."

cat <<'EOF' | python3 scripts/generate-attestations.py 2>&1
site-deploy	extended-markdown-subset	test	ci:fixture:cram	pass
EOF