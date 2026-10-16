mathc attest-batch --from=decisions walks every parseable `*.yaml`
under MATH_CODING_DECISIONS_DIR (default `.math-coding/decisions`)
and emits one attestation per obligation. Each row uses the
`--kind`, `--producer`, `--result` flags (or their defaults).

This is the operator's "stamp every obligation with a default
review" path: useful after a brownfield adoption to seed the
attestation store so subsequent `mathc self-check` runs have
something to read.

Hermetic: the test points MATH_CODING_DECISIONS_DIR and
MATH_CODING_ATTESTATIONS_DIR at operator-named directories under
the tmpdir so it cannot pollute the host checkout.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d) && cd "$tmpdir"
  $ export MATH_CODING_DECISIONS_DIR=".test-math-coding/decisions"
  $ export MATH_CODING_ATTESTATIONS_DIR=".test-math-coding/attestations"
  $ mkdir -p "$MATH_CODING_DECISIONS_DIR" "$MATH_CODING_ATTESTATIONS_DIR"

Hand-write a minimal-but-parseable v3.2 decision with two
obligations. The decision is written via `printf` rather than a
heredoc because cram's `>` continuation syntax collides with shell
heredoc lines that already start with `> ` (RFC: cram lacks an
"ignore-next-line" mechanism, so we use printf + escaped newlines).

  $ printf '%s\n' \
  >   '---' \
  >   'schema: math-coding/3.2' \
  >   'id: foo-decision' \
  >   'revision: 1' \
  >   'state: active' \
  >   'mode: standard' \
  >   'change_kind: implementation' \
  >   'body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"' \
  >   'yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"' \
  >   'axiom_link:' \
  >   '  - A0' \
  >   '  - A1' \
  >   '  - A3' \
  >   'intent: |' \
  >   '  Test decision for the attest-batch --from=decisions path.' \
  >   'commitment: |' \
  >   '  Verify that every obligation emits exactly one attestation.' \
  >   'counterexample: |' \
  >   '  Walked but never committed; the test asserts no leak.' \
  >   'scope:' \
  >   '  paths: ["**"]' \
  >   'outcomes:' \
  >   '  - id: o1' \
  >   '    statement: A first outcome.' \
  >   'obligations:' \
  >   '  - id: obl-acceptance' \
  >   '    outcome: o1' \
  >   '    claim: A claim.' \
  >   '    acceptance:' \
  >   '      all:' \
  >   '        - verifier: mathc self-check' \
  >   '          result: pass' \
  >   '  - id: obl-noise' \
  >   '    outcome: o1' \
  >   '    claim: Another claim.' \
  >   '    acceptance:' \
  >   '      all:' \
  >   '        - verifier: mathc self-check' \
  >   '          result: pass' \
  >   'risk:' \
  >   '  declared_triggers: []' \
  >   '  owner: human:tester' \
  >   'relations:' \
  >   '  addresses: []' \
  >   > "$MATH_CODING_DECISIONS_DIR/foo-decision.yaml"

Validate the fixture before exercising --from=decisions.

  $ mathc validate "$MATH_CODING_DECISIONS_DIR/foo-decision.yaml"
  accept: .test-math-coding/decisions/foo-decision.yaml
    decision: foo-decision
    revision: 1
    obligations: 2
    assumptions: 0

Run --from=decisions. Two obligations -> two files.

  $ mathc attest-batch --from=decisions --producer=human:integration-test --kind=review
  wrote .test-math-coding/attestations/foo-decision-obl-acceptance.json
  wrote .test-math-coding/attestations/foo-decision-obl-noise.json
  $ ls .test-math-coding/attestations
  foo-decision-obl-acceptance.json
  foo-decision-obl-noise.json

The producer identity MUST come from --producer (not from the
manifest's row, since there is no manifest). The kind_ MUST come
from --kind.

  $ python3 -c "
  > import json, glob
  > for path in sorted(glob.glob('.test-math-coding/attestations/*.json')):
  >     d = json.load(open(path))
  >     assert d['producer']['identity'] == 'human:integration-test', d['producer']
  >     assert d['kind_'] == 'review', d['kind_']
  >     assert d['result'] == 'pass', d['result']
  >     print(d['subject']['decision'], d['subject']['obligation'], 'flags ok')
  > "
  foo-decision obl-acceptance flags ok
  foo-decision obl-noise flags ok

A directory with NO parseable decisions is exit 2 (input error),
not exit 0. This prevents silent zero-output runs from being
mistaken for success. We pass MATH_CODING_DECISIONS_DIR pointing
at a brand-new empty directory so the default-dir fallback does
not pick up the populated `.test-math-coding/decisions` from the
earlier step.

  $ empty=$(mktemp -d)
  $ if MATH_CODING_DECISIONS_DIR="$empty" mathc attest-batch --from=decisions --out="$empty" 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on empty dir"; exit 1
  > else
  >   echo "empty decisions dir refused (exit $?)"
  > fi
  empty decisions dir refused (exit 2)

  $ cd /
  $ rm -rf "$tmpdir" "$empty"
  $ unset MATH_CODING_DECISIONS_DIR
  $ unset MATH_CODING_ATTESTATIONS_DIR


