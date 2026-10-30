`mathc migrate --write` applies auto-translatable actions
(rename-field, add-field, bump-schema-string) to a sibling
`<file>.migrated.yaml` alongside each input, NEVER overwrites
the original, and emits a per-file JSON summary of what was
applied. `--write` always uses the JSON summary format; any
`--format` argument is ignored. `--dry-run` with `--write`
prints the per-file plan without touching the disk.

Fixture: `tests/cli/fixtures/migrate-bump/decisions/pre-bump.yaml`
declares the legacy schema-string `math-coding/3.0-alpha`.
Running `mathc migrate --from=math-coding/3.0-alpha
--to=math-coding/3.2 --root=tests/cli/fixtures/migrate-bump
--write --dry-run` against the fixture produces a one-element
JSON summary with `outcome: "dry-run"` and reports the
intended migrated path; with `--dry-run` removed it writes
a sibling `.migrated.yaml` containing the bumped schema-string
and leaves the original untouched.

  $ cd "$DUNE_SOURCEROOT"
  $ rm -f tests/cli/fixtures/migrate-bump/decisions/pre-bump.yaml.migrated.yaml

Dry-run first: no file appears; the summary records the
intended path.

  $ $INSIDE_DUNE/bin/mathc.exe migrate \
  >     --from=math-coding/3.0-alpha \
  >     --to=math-coding/3.2 \
  >     --root=tests/cli/fixtures/migrate-bump \
  >     --manifest=decisions/migrations/3.0-alpha-to-3.2.yaml \
  >     --write \
  >     --dry-run \
  >     | jq -c '.[0] | {outcome, migrated_to, current_schema}'
  {"outcome":"dry-run","migrated_to":"(dry-run)","current_schema":"math-coding/3.0-alpha"}
  $ test ! -f tests/cli/fixtures/migrate-bump/decisions/pre-bump.yaml.migrated.yaml && echo "no leaked file"
  no leaked file

Now without `--dry-run`: the sibling file appears; the
summary records `outcome: "wrote"`. The original file is
untouched (still at `math-coding/3.0-alpha`).

  $ $INSIDE_DUNE/bin/mathc.exe migrate \
  >     --from=math-coding/3.0-alpha \
  >     --to=math-coding/3.2 \
  >     --root=tests/cli/fixtures/migrate-bump \
  >     --manifest=decisions/migrations/3.0-alpha-to-3.2.yaml \
  >     --write \
  >     | jq -c '.[0] | {outcome, current_schema, migrated_to_short: (.migrated_to | split("/") | last)}'
  {"outcome":"wrote","current_schema":"math-coding/3.0-alpha","migrated_to_short":"pre-bump.yaml.migrated.yaml"}
  $ grep -E '^schema: ' tests/cli/fixtures/migrate-bump/decisions/pre-bump.yaml.migrated.yaml | head -1
  schema: math-coding/3.2
  $ grep -E '^schema: ' tests/cli/fixtures/migrate-bump/decisions/pre-bump.yaml | head -1
  schema: math-coding/3.0-alpha
  $ rm -f tests/cli/fixtures/migrate-bump/decisions/pre-bump.yaml.migrated.yaml
