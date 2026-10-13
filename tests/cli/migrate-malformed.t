`mathc migrate --manifest=PATH` exits 2 with a parse-error message
when the manifest is malformed. Two failure modes are checked:
(1) unknown migration kind (vocabulary overflow);
(2) non-object migration entry.

Both surface in stderr with the offending item name; the kernel
emits no plan and exits 2.

  $ cd "$DUNE_SOURCEROOT"

Unknown migration kind:

  $ mathc migrate \
  >     --root=tests/cli/fixtures/migrate \
  >     --manifest=tests/cli/fixtures/migrate/decisions/migrations/malformed.yaml \
  >     --format=json
  mathc migrate: manifest migrations[] errors: migration.kind: unknown kind `quantum-flip`
  [2]

Missing required field on a well-known kind (rename-field without `to`):

  $ cat > /tmp/incomplete.yaml <<EOF
  > ---
  > schema: math-coding/migration-manifest
  > from: math-coding/3.2
  > to: math-coding/3.2.1
  > intent: "incomplete test"
  > migrations:
  >   - kind: rename-field
  >     from: countercase
  > EOF
  $ mathc migrate \
  >     --root=tests/cli/fixtures/migrate \
  >     --manifest=/tmp/incomplete.yaml \
  >     --format=json
  mathc migrate: manifest migrations[] errors: rename-field requires from + to (both strings)
  [2]
