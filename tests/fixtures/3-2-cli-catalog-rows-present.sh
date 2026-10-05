#!/usr/bin/env bash
# tests/fixtures/3-2-cli-catalog-rows-present.sh
#
# Verifier for decisions/3-2-cli-catalog.yaml obligations
# `mode-subcommand-spec-row`, `rebuttals-subcommand-spec-row`,
# `re-evaluate-subcommand-spec-row`, and
# `readme-cli-table-grows-by-three`. The script checks that:
#   - spec/semantics.md contains the three new subcommand rows
#     (`### \`mode`, `### \`rebuttals`, `### \`re-evaluate`)
#   - README.md's CLI table contains the three new subcommand
#     rows (`mathc mode`, `mathc rebuttals`, `mathc re-evaluate`)

set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
spec=spec/semantics.md
readme=README.md

# spec/semantics.md: three `### \`<subcommand>\`` rows
for sub in mode rebuttals re-evaluate; do
  if ! grep -qE "^### \`$sub(\b|[[:space:]])" "$spec"; then
    echo "FAIL: $spec missing '### \`$sub ...' subcommand row"
    fail=1
  else
    echo "ok: $spec has '### \`$sub ...' row"
  fi
done

# README.md: three new subcommand rows
for sub in mode rebuttals re-evaluate; do
  if ! grep -qE "^\| \`mathc $sub " "$readme"; then
    echo "FAIL: $readme missing '| \`mathc $sub ...' table row"
    fail=1
  else
    echo "ok: $readme has '| \`mathc $sub ...' table row"
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "ok: 3.2-cli-catalog spec+README rows all present"
exit 0
