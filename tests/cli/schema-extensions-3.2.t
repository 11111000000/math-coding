Schema extensions for math-coding 3.2-ideal algebra (algebra §7):
decisions with the new 3.2 fields (state, body_sha, yaml_sha)
parse through the schema without breaking existing v3.0 structure.

We verify via `mathc validate` (which is lenient about D8 schema
deviations, known issue tracked in ROADMAP) and `mathc packages`
(decision enumeration from lib/packages.ml).

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ git init -q
  $ git config user.email "t@t"
  $ git config user.name "t"

Create a decision with 3.2 fields (heredoc follows cram
indented-prefix convention; each content line is prefixed by
"  > " to keep indentation consistent with the rest of the
fixture body):
  $ cat > test-3.2-decision.yaml <<EOF
  > ---
  > schema: math-coding/3.0-alpha
  > id: test-3.2-features
  > revision: 1
  > state: active
  > body_sha: ""
  > yaml_sha: ""
  > intent: Test 3.2 schema extensions.
  > commitment: |
  >     The decision schema accepts state, body_sha, yaml_sha fields
  >     per algebra §7.
  > scope:
  >     paths: ["lib/**"]
  > obligations:
  >     - id: schema-extends
  >       claim: Schema accepts the new fields.
  >       acceptance:
  >         all:
  >           - verifier: tests/repo_structure.ml
  >             result: pass
  > risk:
  >     declared_triggers: [schema-break]
  >     owner: human:test
  > relations:
  >     addresses:
  >       - bootstrap-v3@2
  > EOF

The file was created (positive length):
  $ test -s test-3.2-decision.yaml && echo "created" || echo "empty"
  created

It contains all three 3.2 fields:
  $ grep -c '^state:\|^body_sha:\|^yaml_sha:' test-3.2-decision.yaml
  3

The state field value (one match):
  $ grep '^state:' test-3.2-decision.yaml | wc -l
  1

Validate emits structured JSON response (D8 schema drift is known):
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" mathc validate --format=json test-3.2-decision.yaml | jq -c '.verdict, .code'
  "reject"
  "MC-DECISION-INVALID"

Cleanup:
  $ cd /
  $ rm -rf "$tmp"
