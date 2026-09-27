#!/usr/bin/env bash
# spec-cli-catalog: spec-cli-catalog-promoted fixture
#
# Asserts that spec/semantics.md contains a section listing every
# mathc CLI subcommand present in bin/Mathc.ml at HEAD:
# version, validate, context, assess, attest, gate, session-start,
# record, stats, time-estimate. The spec describes what the CLI
# does (per bootstrap/spec-cli-catalog.md); the fixture exists to
# trip if the catalog disappears from the spec or if a
# subcommand is added to bin/Mathc.ml without a spec row.
#
# This is the acceptance gate for obligation
# spec-cli-catalog-promoted in bootstrap/spec-cli-catalog.md.
#
# Strategy: locate a heading in spec/semantics.md that names the
# CLI surface (case-insensitive: "CLI subcommands" or
# "subcommands"); capture the body lines until the next ##-level
# heading; assert each canonical subcommand name appears as a
# word in the body. The check is a pure POSIX shell + grep; no
# new dependencies, no kernel change.
#
# Verdict:
#   exit 0 - spec/semantics.md contains a CLI subcommands section
#            that names every canonical subcommand.
#   exit 1 - the heading is absent, or one or more subcommand
#            names are not mentioned in the section. The fixture
#            prints the missing names on stderr.

set -uo pipefail
cd "$(dirname "$0")/../.."

echo "spec-catalog-present:"

spec=spec/semantics.md

# Canonical list of mathc subcommands at HEAD. Each must appear
# in the body of a "CLI subcommands" section in spec/semantics.md.
# Order in the spec is not asserted; presence is.
declare -a canonical=(
  version
  validate
  context
  assess
  attest
  gate
  session-start
  record
  stats
  time-estimate
)

if [ ! -f "$spec" ]; then
  echo "  FAIL $spec missing" >&2
  exit 1
fi

# Locate the body of a "CLI subcommands" section (## heading or
# equivalent). We accept any heading line whose lowercase text
# mentions both "cli" and "subcommand" (covers "CLI subcommands",
# "CLI Subcommands", and the "CLI subcommand" phrasing). We
# capture the body lines from that heading until the next ##-
# level (or #-level) heading or EOF.
section_body=$(awk '
  BEGIN { in_section = 0 }
  /^# / || /^## / || /^### / || /^#### / {
      if (in_section) exit
      lc = tolower($0)
      if (lc ~ /cli/ && lc ~ /subcommand/) {
          in_section = 1
          next
      }
  }
  in_section { print }
' "$spec")

if [ -z "$section_body" ]; then
  echo "  FAIL no 'CLI subcommands' section in $spec" >&2
  echo "  hint: add a '## CLI subcommands' section BEFORE 'Context-prioritisation'." >&2
  exit 1
fi

missing=()
for name in "${canonical[@]}"; do
  # Match the subcommand name as a word in the section body.
  # Hyphenated names (session-start, time-estimate) match on
  # the literal hyphen; the grep escapes it.
  if ! printf '%s\n' "$section_body" | grep -qE "(^|[^[:alnum:]_])${name}([^[:alnum:]_]|$)"; then
    missing+=("$name")
  fi
done

if [ ${#missing[@]} -gt 0 ]; then
  echo "  FAIL spec/semantics.md 'CLI subcommands' missing:" >&2
  for m in "${missing[@]}"; do
    echo "    - $m" >&2
  done
  exit 1
fi

echo "  ok   spec/semantics.md CLI subcommands section lists all ${#canonical[@]} canonical subcommands"
exit 0
