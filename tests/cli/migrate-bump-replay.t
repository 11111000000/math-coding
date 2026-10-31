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
`archive/decisions/schema-string-bump-3.0-alpha-to-3.2-2026-10.yaml`.

  $ cd "$DUNE_SOURCEROOT"
  $ $INSIDE_DUNE/bin/mathc.exe migrate \
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

The migration plan-of-record invariant: on a post-bump live
tree, the manifest at `decisions/migrations/3.0-alpha-to-3.2.yaml`
must NOT emit any `actions` (the planner's "rewrite this file"
list). It MAY emit `warnings` for files already on a schema
beyond 3.2 (current decisions sit at `math-coding/3.3`) or on
the `math-coding/obligations-3.0-alpha` alias -- those are
informational and don't change disk state. We assert the
ACTIONS invariant via jq rather than hardcoding counts, since
the repo's decision inventory grows over time and the test
would otherwise pin a stale literal.

  $ $INSIDE_DUNE/bin/mathc.exe migrate \
  >     --from=math-coding/3.0-alpha \
  >     --to=math-coding/3.2 \
  >     --format=json \
  >     > /tmp/migrate.json
  $ actions=$(jq '[.[].actions | length] | add' /tmp/migrate.json)
  $ echo "actions=$actions total=$(jq 'length' /tmp/migrate.json)" | sed 's|total=.*|total=<N>|g'
  actions=0 total=<N>
  $ [ "$actions" = "0" ] && echo "post-bump invariant: zero rewrite actions emitted"
  post-bump invariant: zero rewrite actions emitted
  $ rm -f /tmp/migrate.json
