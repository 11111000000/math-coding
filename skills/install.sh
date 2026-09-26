#!/bin/sh
# skills/install.sh — math-coding one-line installer.
#
# Canonical entry-point, referenced from documentation as:
#   curl -fsSL https://raw.githubusercontent.com/11111000000/math-coding/main/skills/install.sh | sh
#
# Delegates to skills/math-coding/install.sh, the real installer
# (binary download with source-build fallback, agent-skill drop,
# post-install smoke test).
#
# This file is intentionally tiny so the URL above is stable even if
# the internal layout of skills/math-coding/ changes.

set -eu

DIR="$(cd "$(dirname "$0")" && pwd)"
exec sh "$DIR/math-coding/install.sh" "$@"
