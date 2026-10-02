#!/usr/bin/env bash
# scripts/generate-attestations-site-deploy-2.sh
#
# Adds attestations for the 6 new site-deploy@2 obligations
# (tufte-stylesheet, sidenote-syntax, mathjax-wiring,
# bilingual-pairs, base-href-subpath, site-pages-extended).
# Idempotent: existing files are overwritten with the same
# canonical-JSON-derived sha256.
#
# Usage:
#   scripts/generate-attestations-site-deploy-2.sh

set -euo pipefail
cd "$(dirname "$0")/.."

cat <<'EOF' | python3 scripts/generate-attestations.py 2>&1
site-deploy	tufte-stylesheet	test	ci:fixture:cram	pass
site-deploy	sidenote-syntax	test	ci:fixture:cram	pass
site-deploy	mathjax-wiring	test	ci:fixture:cram	pass
site-deploy	bilingual-pairs	test	ci:fixture:cram	pass
site-deploy	base-href-subpath	test	ci:fixture:cram	pass
site-deploy	site-pages-extended	test	ci:fixture:cram	pass
EOF