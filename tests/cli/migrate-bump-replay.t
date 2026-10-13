`mathc migrate --from=math-coding/3.0-alpha
--to=math-coding/3.2` replays the manifest at
`decisions/migrations/3.0-alpha-to-3.2.yaml` against a
legacy-form synthetic tree
(`tests/cli/fixtures/migrate-bump/decisions/pre-bump.yaml`),
producing a per-file plan with a single
`bump-schema-string` action from `math-coding/3.0-alpha`
to `math-coding/3.2`. The fixture's `schema:` line reads
`math-coding/3.0-alpha`; this is the legacy form the
schema enum (`schemas/decision.json`) still admits as a
soft-deprecated form per
`decisions/schema-string-bump-3.0-alpha-to-3.2-2026-10.yaml`.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc migrate \
  >     --root=tests/cli/fixtures/migrate-bump \
  >     --manifest=decisions/migrations/3.0-alpha-to-3.2.yaml \
  >     --format=json \
  >     | jq -c '.[0] | {file: (.file | split("/") | last), current_schema, actions: .actions, warnings}'
  {"file":"pre-bump.yaml","current_schema":"math-coding/3.0-alpha","actions":[{"from":"math-coding/3.0-alpha","kind":"bump-schema-string","to":"math-coding/3.2"}],"warnings":[]}

Same command against the LIVE tree (post-bump): every
live decision carries `math-coding/3.2` (the manifest's
target), so the planner emits a no-op plan (zero plans
or one plan per file with empty actions and empty
warnings).

  $ mathc migrate \
  >     --from=math-coding/3.0-alpha \
  >     --to=math-coding/3.2 \
  >     --format=json \
  >     | jq -c '{total_plans: (length | tostring), noop_plans: (map(select((.actions | length) == 0 and (.warnings | length) == 0)) | length | tostring)}'
  {"total_plans":"74","noop_plans":"73"}
