mathc init, when the env-vars point at the pre-3.4 legacy layout
(`decisions/`, `attestations/`, `decisions/decision.yaml`), MUST
honour them and create exactly the legacy tree -- not the new
`.math-coding/` defaults. This is the backward-compat path
required by PLAN.md §0.3 and `decisions/ux-3-minimal-pollution-2026-10.yaml`
("Brownfield projects with `decisions/` and `attestations/` continue
to work without edits"). The test is hermetic: a `tmpdir` is
fresh for each run and the env-vars are unset before exit so they
do not leak into later tests in the same cram shell.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ export MATH_CODING_DECISIONS_DIR="decisions"
  $ export MATH_CODING_ATTESTATIONS_DIR="attestations"
  $ export MATH_CODING_POLICY="decisions/decision.yaml"
  $ cd "$tmpdir"
  $ $INSIDE_DUNE/bin/mathc.exe init . --no-install
  mathc init: created ./decisions, ./attestations
    decision.yaml: schema math-coding/3.2, scope paths editable
    pre-commit hook: skipped (--no-install)
    applicability envelope (spec/algebra-3.2.md §28, default-on):
      path: Path A. Installed by default, a single maintainer included.
        To skip, the project must be throwaway — prototype,
        MVP, spike, one-day hackathon — and the rationale goes
        in the README, per §23.
      signals that lift the ceremony above the light floor:
        - two or more AI agents (or humans) editing this repository
        - regulatory or contractual audit needs a tamper-evident trail
        - three or more maintainers on a five-or-more-year horizon
        - an AI agent writes into the repository (one human is enough)
      the one Path C class:
        - prototype / MVP / spike / throwaway: no expected continuity
      floor: no policies.yaml here, so the kernel uses its lowest rung
        (Tiny). Declare mode_floor in the project's policies.yaml to
        match reality. `mathc init` sees one writer and cannot detect
        the signals above; they are yours to declare.

  $ test -d decisions && echo "decisions/: ok"
  decisions/: ok
  $ test -d attestations && echo "attestations/: ok"
  attestations/: ok
  $ test -f decisions/decision.yaml && echo "decision.yaml: ok"
  decision.yaml: ok

The new-default `.math-coding/` MUST NOT be created when the env-vars
override the resolver with legacy paths. This is the regression pin
for env-var precedence (per `lib/path_config.ml`: env-var wins over
default, and default wins over fallback, but env-var must NEVER
coexist with the default).

  $ test ! -d .math-coding && echo "no .math-coding/: ok"
  no .math-coding/: ok

The scaffolded legacy decision.yaml MUST validate cleanly. The
master template carries `axiom_link` + `counterexample` per the
kernel-bugs v3.4 fix; legacy layout is otherwise structurally
identical to the new layout (one master file, two store
directories).

  $ $INSIDE_DUNE/bin/mathc.exe validate decisions/decision.yaml
  parse-ok: decisions/decision.yaml
    decision: bootstrap-v3
    revision: 1
    obligations: 1
    assumptions: 0

The init MUST NOT create a `schemas/` directory in the project root
in the legacy layout either.

  $ test ! -d schemas && echo "no schemas/: ok"
  no schemas/: ok

Cleanup. The `unset` calls ensure env-vars do not leak.

  $ cd /
  $ rm -rf "$tmpdir"
  $ unset MATH_CODING_DECISIONS_DIR
  $ unset MATH_CODING_ATTESTATIONS_DIR
  $ unset MATH_CODING_POLICY
