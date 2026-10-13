`mathc migrate --from=X --to=X` against a tree whose decision
already carries schema-string X is a no-op for that file: the
planner emits an `actions: []` `warnings: []` plan. The kernel
never mutates files; this is the "idempotent" property an agent
relies on to avoid spurious churn when re-running a plan.

The fixture tree at `tests/cli/fixtures/migrate/` has two files;
this test asserts only on `a.yaml` (at `math-coding/3.2`). The
`b.yaml` fixture (at `math-coding/3.2.1`) intentionally emits a
manual-review warning when the manifest is `from=3.2 to=3.2`,
proving the planner distinguishes "already at target" from "off
target".

  $ cd "$DUNE_SOURCEROOT"
  $ cat > /tmp/noop.yaml <<EOF
  > ---
  > schema: math-coding/migration-manifest
  > from: math-coding/3.2
  > to: math-coding/3.2
  > intent: "noop test manifest"
  > migrations: []
  > EOF
  $ mathc migrate \
  >     --root=tests/cli/fixtures/migrate \
  >     --manifest=/tmp/noop.yaml \
  >     --format=json \
  >     | jq -c 'map(select(.file | endswith("a.yaml"))) | .[0] | {file: (.file | split("/") | last), current_schema, actions, warnings}'
  {"file":"a.yaml","current_schema":"math-coding/3.2","actions":[],"warnings":[]}
