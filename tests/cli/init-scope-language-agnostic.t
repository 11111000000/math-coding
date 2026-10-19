mathc init in a fresh directory must default to language-agnostic scope.paths
(`src/**`, `tests/**`, `docs/**`, `scripts/**`, `schemas/**`, `site/**`)
that exist in any multi-language project. The previous OCaml-only defaults
(`lib/**`, `bin/**`, `spec/**`) caused silent zero-monitoring in adapters
running `mathc self-check` against a Python / Go / Rust / JS project, since
none of those paths existed in their source tree. Per
`decisions/defense-and-init-scope-2026-11.yaml`.

The test is hermetic: env-vars override the resolver prefix, the cram cwd
is a `bwrap` tmp dir, the test `cd`s into a `mktemp -d`.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ export MATH_CODING_DECISIONS_DIR=".test-math-coding/decisions"
  $ export MATH_CODING_ATTESTATIONS_DIR=".test-math-coding/attestations"
  $ export MATH_CODING_POLICY=".test-math-coding/policy.yaml"
  $ cd "$tmpdir"
  $ mathc init . --no-install
  mathc init: created ./.test-math-coding/decisions, ./.test-math-coding/attestations
    decision.yaml: schema math-coding/3.2, scope paths editable
    pre-commit hook: skipped (--no-install)

Language-agnostic paths MUST be present in the scaffolded policy:

  $ grep -Fxq '    - "src/**"'     .test-math-coding/policy.yaml && echo "src/**: ok"
  src/**: ok
  $ grep -Fxq '    - "tests/**"'   .test-math-coding/policy.yaml && echo "tests/**: ok"
  tests/**: ok
  $ grep -Fxq '    - "docs/**"'    .test-math-coding/policy.yaml && echo "docs/**: ok"
  docs/**: ok
  $ grep -Fxq '    - "scripts/**"' .test-math-coding/policy.yaml && echo "scripts/**: ok"
  scripts/**: ok
  $ grep -Fxq '    - "schemas/**"' .test-math-coding/policy.yaml && echo "schemas/**: ok"
  schemas/**: ok
  $ grep -Fxq '    - "site/**"'    .test-math-coding/policy.yaml && echo "site/**: ok"
  site/**: ok

The previous OCaml-only defaults MUST NOT be present (this is the
regression pin for `decisions/defense-and-init-scope-2026-11.yaml:25-37`):

  $ ! grep -Fxq '    - "lib/**"'   .test-math-coding/policy.yaml && echo "no lib/**: ok"
  no lib/**: ok
  $ ! grep -Fxq '    - "bin/**"'   .test-math-coding/policy.yaml && echo "no bin/**: ok"
  no bin/**: ok
  $ ! grep -Fxq '    - "spec/**"'  .test-math-coding/policy.yaml && echo "no spec/**: ok"
  no spec/**: ok

Scaffolded policy must still validate cleanly (the language-agnostic
defaults do not break the schema):

  $ mathc validate .test-math-coding/policy.yaml
  parse-ok: .test-math-coding/policy.yaml
    decision: bootstrap-v3
    revision: 1
    obligations: 1
    assumptions: 0

Cleanup. `unset` ensures a stale env-var in the cram shell does not
leak into later tests in the same cram run.

  $ cd /
  $ rm -rf "$tmpdir"
  $ unset MATH_CODING_DECISIONS_DIR
  $ unset MATH_CODING_ATTESTATIONS_DIR
  $ unset MATH_CODING_POLICY
