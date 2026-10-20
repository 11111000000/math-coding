mathc init in a fresh directory defaults to the new minimal-pollution
layout (`.math-coding/decisions/`, `.math-coding/attestations/`,
`.math-coding/policy.yaml`). This is the forward path for greenfield
projects (per PLAN.md §0.1, §2.2; sub-decision
`decisions/ux-3-minimal-pollution-2026-10.yaml`). The test is
hermetic: it overrides every resolver with a non-default env-var
prefix so it cannot pollute the host checkout even if a previous
test failed mid-run. Cram's cwd is a bwrap tmp dir already; the
test then `cd`s into a fresh `mktemp -d` and runs `mathc init` there.

When the env-vars point at a `.test-math-coding/` prefix, `mathc init`
MUST honour them and create exactly that layout -- not the default
`.math-coding/`. The test asserts that `.test-math-coding/decisions/`,
`.test-math-coding/attestations/`, `.test-math-coding/policy.yaml`
all exist after init; the default `.math-coding/` is NOT created
(forward pollution guard for hermetic runs); and the scaffolded
policy validates cleanly (regression pin for the P2 axiom_link +
counterexample template fix).

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

  $ test -d .test-math-coding/decisions && echo "decisions/: ok"
  decisions/: ok
  $ test -d .test-math-coding/attestations && echo "attestations/: ok"
  attestations/: ok
  $ test -f .test-math-coding/policy.yaml && echo "policy.yaml: ok"
  policy.yaml: ok

The default `.math-coding/` MUST NOT be created when the env-vars
override the resolver. This is the regression pin for the new
defaults (per `decisions/ux-3-minimal-pollution-2026-10.yaml`):
a greenfield project under env-var control picks up the
operator-named directory, not the hardcoded default.

  $ test ! -d .math-coding && echo "no default .math-coding/: ok"
  no default .math-coding/: ok

The scaffolded policy must validate cleanly. This is the
regression pin for the P2 axiom_link + counterexample template fix
(per `decisions/kernel-bugs-v3.4-2026-10.yaml`): without the fix,
`mathc init` would scaffold a policy that fails validation with
`MC-MISSING-INTENT` or `MC-COUNTEREXAMPLE-MISSING`.

  $ mathc validate .test-math-coding/policy.yaml
  parse-ok: .test-math-coding/policy.yaml
    decision: bootstrap-v3
    revision: 1
    obligations: 1
    assumptions: 0

The init MUST NOT create a `schemas/` directory in the project root.
Brownfield projects don't need on-disk JSON schemas (the kernel
embeds them per `lib/schema_embedded.ml`).

  $ test ! -d schemas && echo "no schemas/ on disk: ok"
  no schemas/ on disk: ok

Cleanup. We use `unset` so a stale env-var in the cram shell does
not leak into later tests in the same cram run.

  $ cd /
  $ rm -rf "$tmpdir"
  $ unset MATH_CODING_DECISIONS_DIR
  $ unset MATH_CODING_ATTESTATIONS_DIR
  $ unset MATH_CODING_POLICY
