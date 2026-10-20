mathc counters --format=json reports the live schema introspection
keys (decision_required_fields, schema_enum, intent_oneOf,
scope_oneOf) under the `schema` object. Each value must reflect
the parsed `schemas/decision.json` from the project root, not
an empty stub. This is the regression fixture for
`bin/Mathc.ml::do_counters`'s section 7 "schema info" path
walkers, which previously under-reported `schema_enum` as `[]`
and `intent_oneOf` / `scope_oneOf` as `false` because the
`get` helper's empty-path base case returned `None` instead of
`Some v` (the fix is recorded in
`decisions/counters-schema-introspection-fix-2026-10`).

NOTE: a prior revision of this file carried an "Acceptance
contract:" bullet list indented `  - ` that cram silently
parsed as four negative-match expectations (two-space,
dash, space), not as comments. The bullet list moved inline
with each positive jq check below so the documentation
remains but the negative-match footgun does not trip future
runs.

Acceptance contract: schema.decision_required_fields is a
7-element array listing every value in
schemas/decision.json::required; schema.schema_enum is a
non-empty array carrying at least the 3.3, 3.2, and
3.0-alpha family forms (six entries today:
math-coding/3.0-alpha, math-coding/3.0-alpha/decision,
math-coding/3.2, math-coding/3.2/decision,
math-coding/3.3, math-coding/3.3/decision), the fixture
asserts `>= 4` to tolerate future enum widening;
schema.intent_oneOf == true (the schema declares an intent
oneOf with two branches: a YAML-form string and a JSON-form
object); schema.scope_oneOf == true (the schema declares a
scope oneOf with two branches: a YAML-form object and a
JSON-form $ref to common.json#/definitions/scope).

Cram cwd is a bwrap tmp dir; the real project root is exposed
by dune as $DUNE_SOURCEROOT. `mathc counters` is invoked with
MATH_CODING_ROOT pointed at the source root, so the schema
walk reads `schemas/decision.json` from the live tree.

  $ cd "$DUNE_SOURCEROOT"

The four schema keys are present and well-typed:

  $ mathc counters --format=json | jq -e '.schema | (has("decision_required_fields") and (.decision_required_fields | type == "array")) and (has("schema_enum") and (.schema_enum | type == "array")) and (has("intent_oneOf") and (.intent_oneOf | type == "boolean")) and (has("scope_oneOf") and (.scope_oneOf | type == "boolean"))'
  true

decision_required_fields carries the seven root `required` keys
in any order. Asserting via the length check (the order is
preserved by the parser but not relied on by the fixture).

  $ mathc counters --format=json | jq -e '.schema.decision_required_fields | length == 7'
  true

The seven required values, in their parsed order, are exactly
the `required` array from `schemas/decision.json`:

  $ python3 -c "import json; print(' '.join(json.load(open('schemas/decision.json'))['required']))"
  schema id intent commitment scope outcomes obligations

The reported array matches that set (order-independent):

  $ mathc counters --format=json | jq -r '.schema.decision_required_fields | sort | join(" ")'
  commitment id intent obligations outcomes schema scope

schema_enum is non-empty and carries at least four entries
(the current 3.3, 3.2, and 3.0-alpha family forms, six total):

  $ mathc counters --format=json | jq -e '.schema.schema_enum | length >= 4'
  true

The six enum values are present (each appears in the array):

  $ mathc counters --format=json | jq -e '.schema.schema_enum | index("math-coding/3.0-alpha") != null'
  true
  $ mathc counters --format=json | jq -e '.schema.schema_enum | index("math-coding/3.0-alpha/decision") != null'
  true
  $ mathc counters --format=json | jq -e '.schema.schema_enum | index("math-coding/3.2") != null'
  true
  $ mathc counters --format=json | jq -e '.schema.schema_enum | index("math-coding/3.2/decision") != null'
  true
  $ mathc counters --format=json | jq -e '.schema.schema_enum | index("math-coding/3.3") != null'
  true
  $ mathc counters --format=json | jq -e '.schema.schema_enum | index("math-coding/3.3/decision") != null'
  true

intent_oneOf is `true` (the schema's `properties.intent` object
carries a `oneOf` key):

  $ mathc counters --format=json | jq -e '.schema.intent_oneOf == true'
  true

scope_oneOf is `true` (the schema's `properties.scope` object
carries a `oneOf` key):

  $ mathc counters --format=json | jq -e '.schema.scope_oneOf == true'
  true

Negative witness: a missing `enum` or `oneOf` in the schema
would surface as a non-`true` boolean. The fixture is positive
only; the negative side is the live `mathc counters` report
itself, which is the regression artifact.
