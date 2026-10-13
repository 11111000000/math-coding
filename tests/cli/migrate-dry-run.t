`mathc migrate --root=DIR --manifest=PATH` walks `decisions/`
under DIR and applies the manifest at PATH to every YAML. The
planner emits per-file JSON; an agent reads it and edits manually.

The synthetic tree at `tests/cli/fixtures/migrate/` has two
files. `a.yaml` declares schema math-coding/3.2 and lacks
counterexample; `b.yaml` declares schema math-coding/3.2.1 and
carries one. The synthetic manifest at
`tests/cli/fixtures/migrate/decisions/migrations/3.2-to-3.2.1.yaml`
declares an add-field for counterexample plus a schema-string bump.
Plan expectations normalised to basename via jq so the cram
snapshot is portable across machines and `_build/` layouts:
`a.yaml` should show two actions (add-field, bump-schema-string)
and zero warnings; `b.yaml` is already at the target schema-string
so it shows zero actions and zero warnings.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc migrate \
  >     --root=tests/cli/fixtures/migrate \
  >     --manifest=tests/cli/fixtures/migrate/decisions/migrations/3.2-to-3.2.1.yaml \
  >     --format=json \
  >     | jq -c 'sort_by(.file) | map({file: (.file | split("/") | last), current_schema, actions, warnings})'
  [{"file":"a.yaml","current_schema":"math-coding/3.2","actions":[{"default":"(none on file)","kind":"add-field","path":"counterexample"},{"from":"math-coding/3.2","kind":"bump-schema-string","to":"math-coding/3.2.1"}],"warnings":[]},{"file":"b.yaml","current_schema":"math-coding/3.2.1","actions":[],"warnings":[]}]
