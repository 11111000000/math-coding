# DEPRECATED: this script was used to generate the v3.0.0.20 attestation
# batch. The v3.1.0-alpha algebra-3.2 batch (7 attestations) was
# generated via direct git commit at fd7ea8b rather than this script.
# For new attestation batches, write the manifest directly and use
# scripts/generate-attestations.py.
#!/usr/bin/env bash
# scripts/generate-attestations-v3.0.0.20.sh
#
# Reads the v3.0.0.20 attestation manifest from stdin and emits
# one attestation JSON per row to attestations/. Mirrors the
# convention in attestation-source-map.md §"Notes for the
# generating agent".
#
# Usage:
#   scripts/generate-attestations-v3.0.0.20.sh
#
# Idempotent: existing files are overwritten with the same
# canonical-JSON-derived sha256, so re-running is safe.

set -euo pipefail
cd "$(dirname "$0")/.."

# v3.0.0.20 batch. 10 obligations across 4 new decisions.
cat <<'EOF' | python3 scripts/generate-attestations.py 2>&1
D6-bootstrap-v3-verifiers-implemented	D6-verifiers-machine-checked	build	ci:build:self-check	pass
mc-packages-subcommand	packages-kernel-walker	build	ci:build:packages	pass
mc-packages-subcommand	packages-cli-dispatcher	test	ci:fixture:cram	pass
mc-packages-subcommand	packages-site-bridge	build	ci:build:render	pass
process-principles-close-branches	close-branches-impl	test	ci:fixture:shell	pass
process-principles-close-branches	pre-commit-hook-impl	test	ci:fixture:shell	pass
site-deploy	render-kernel-impl	build	ci:build:render	pass
site-deploy	site-content-self-referential	test	ci:fixture:shell	pass
site-deploy	site-deploy-pipeline	build	ci:workflow:site	pass
site-deploy	site-pinned-ubuntu	review	human:maintainer	pass
EOF