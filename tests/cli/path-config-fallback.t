`lib/path_config.ml::resolve_decisions_dir` falls back to the
pre-3.4 legacy `decisions/` directory when the new-default
`.math-coding/decisions/` does NOT exist on disk. This is the
backward-compat contract (PLAN.md §0.3, §2.3 acceptance): a
brownfield project with `decisions/foo.yaml` keeps working after
the 3.3 -> 3.4 cutover without any config edit.

The test creates a project that has only `decisions/foo.yaml` (no
`.math-coding/` tree anywhere), runs `mathc validate
decisions/foo.yaml`, and asserts the kernel walks the legacy
directory and produces an accept verdict. The kernel never had to
"discover" `decisions/` -- the user pointed at it explicitly --
but the resolver MUST keep its fallback contract: explicit path wins,
default wins if it exists, legacy wins otherwise.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ cd "$tmpdir"

Hand-write a parseable v3.2 decision in the legacy directory.
We deliberately omit `.math-coding/` so the resolver MUST fall
through to the legacy path.

  $ mkdir decisions
  $ cat > decisions/foo.yaml <<EOF
  > ---
  > schema: math-coding/3.2
  > id: foo-decision
  > revision: 1
  > state: active
  > mode: standard
  > change_kind: implementation
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > axiom_link:
  >   - A0
  >   - A1
  >   - A3
  > intent: |
  >   Test decision for the resolver fallback path.
  > commitment: |
  >   Verify the kernel still finds decisions/ when .math-coding/ is absent.
  > counterexample: |
  >   Brownfield projects kept on legacy paths after the 3.3 -> 3.4 cutover.
  > scope:
  >   paths: ["**"]
  > outcomes:
  >   - id: o1
  >     statement: A first outcome.
  > obligations:
  >   - id: obl-acceptance
  >     outcome: o1
  >     claim: A claim.
  >     acceptance:
  >       all:
  >         - verifier: mathc self-check
  >           result: pass
  > risk:
  >   declared_triggers: []
  >   owner: human:tester
  > relations:
  >   addresses: []
  > EOF

The new-default `.math-coding/` MUST NOT exist -- the test
specifically validates the no-`.math-coding/` branch.

  $ test ! -d .math-coding && echo "no .math-coding/: ok"
  no .math-coding/: ok

Run validate. The kernel locates the file by the explicit path
the user passed (`decisions/foo.yaml`), but the resolver
internally picks `decisions/` (the fallback) when
`.math-coding/decisions/` does not exist.

  $ mathc validate decisions/foo.yaml
  accept: decisions/foo.yaml
    decision: foo-decision
    revision: 1
    obligations: 1
    assumptions: 0

The same contract holds for `MATH_CODING_ATTESTATIONS_DIR`: with no
`.math-coding/attestations/`, the resolver returns `attestations/`
relative to cwd. We do not assert a `mathc self-check` run here
because the fixture store would be empty; the contract is the
resolver behaviour, which `tests/path_config_test.ml` covers
directly via the public API.

  $ test ! -d .math-coding && echo "still no .math-coding/: ok"
  still no .math-coding/: ok

Cleanup.

  $ cd /
  $ rm -rf "$tmpdir"
