mathc validate emits a structured error message that names the
specific missing required field, not a generic "missing or invalid
required field" (D8 actionable-validator improvement). This closes
the user-visible gap: an author looking at the rejection knows
which field to add.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cd "$tmp"

Missing field `commitment` (the first in our required-fields list
that is absent):
  $ cat > missing-commitment.yaml <<EOF
  > schema: math-coding/3.0-alpha
  > id: missing-commitment-demo
  > intent: Test missing commitment field
  > scope:
  >     paths: ["lib/**"]
  > outcomes:
  >     - id: o
  >       statement: y
  > obligations: []
  > EOF
  $ mathc validate --format=json missing-commitment.yaml | jq -c '{verdict, code, message}'
  {"verdict":"reject","code":"MC-DECISION-INVALID","message":"missing required field: commitment"}

Missing field `outcomes` (later in the list):
  $ cat > missing-outcomes.yaml <<EOF
  > schema: math-coding/3.0-alpha
  > id: missing-outcomes-demo
  > intent: Test missing outcomes field
  > commitment: |
  >     A commitment.
  > scope:
  >     paths: ["lib/**"]
  > obligations: []
  > EOF
  $ mathc validate --format=json missing-outcomes.yaml | jq -c '{verdict, code, message}'
  {"verdict":"reject","code":"MC-DECISION-INVALID","message":"missing required field: outcomes"}

The first missing field is reported (not all of them): the file below
is missing both `commitment` and `outcomes`, but the validator
surfaces `commitment` first because it appears earlier in the
required-fields list. This is intentional — the user gets a
single, actionable next step.

  $ cat > missing-many.yaml <<EOF
  > schema: math-coding/3.0-alpha
  > id: missing-many-demo
  > intent: Test multiple missing fields
  > scope:
  >     paths: ["lib/**"]
  > obligations: []
  > EOF
  $ mathc validate --format=json missing-many.yaml | jq -c '{verdict, code, message}'
  {"verdict":"reject","code":"MC-DECISION-INVALID","message":"missing required field: commitment"}

Cleanup:
  $ cd /
  $ rm -rf "$tmp"
