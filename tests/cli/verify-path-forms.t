`mathc verify` executes the path forms the decision corpus actually
writes, and refuses — loudly — the ones it cannot execute.

Before verify-path-forms-and-signed-attestations-2026-10 an
obligation like `tests/render_kernel.ml::mathjax_no_dollar_delimiters`,
`scripts/check.sh` or `dune build @install` was reported `skipped`:
`parse_verifier_string` read the first whitespace token as a scheme
name, and none of those tokens is one. `skipped` exits 0, so 80% of
the corpus looked verified while nothing ran. The path forms are now planned into an argv and
executed in the same sandbox the three original schemes use.

This fixture pins the half of that behaviour a cram test can
observe. It runs inside a `dune runtest` action, and a nested
`dune` refuses to start while the outer one holds the workspace
lock ("Another Dune instance is currently running"), so the forms
that reach dune (`tests/*.ml`, `tests/*.t`, bare `dune <args>`)
are asserted here only up to the point where they are REFUSED
before execution — a path that does not exist, a path that leaves
the repository, a command that needs a shell. The executing half is
covered by decisions/verify-path-forms-and-signed-attestations-2026-10
outcomes, measured outside a dune action.

The scratch project is the tmpdir itself (MATH_CODING_ROOT), so a
`scripts/` path that must be inside "the repository" resolves
against the tmpdir and the fixture can plant its own scripts.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d) && cd "$tmp"
  $ export MATH_CODING_ROOT="$tmp"
  $ mkdir -p scripts tests
  > # find_project_root only honours MATH_CODING_ROOT when the directory
  > # carries a dune-project, and falls back to DUNE_SOURCEROOT (the
  > # repository) otherwise -- which would resolve every scripts/ path
  > # against the real repo and pass for the wrong reason.
  $ touch dune-project
  $ printf '#!/bin/sh\nexit 0\n' > scripts/ok.sh
  $ printf '#!/bin/sh\nexit 3\n' > scripts/fail.sh
  $ chmod +x scripts/ok.sh scripts/fail.sh

A decision whose obligations cover every classification the planner
can reach.

  $ cat > scratch.yaml <<'YAML'
  > schema: math-coding/3.3
  > id: scratch-verify-pathforms-2026-10
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent:
  >   source: scratch
  >   text: |
  >     scratch decision for path-form verifier coverage.
  > commitment: |
  >   Path forms run; the ones that cannot run fail with a reason.
  > outcomes:
  >   - id: o1
  >     statement: trivially true.
  > scope:
  >   paths:
  >     - "bin/Mathc.ml"
  > obligations:
  >   - id: script-passes
  >     claim: an executable script runs
  >     acceptance:
  >       all:
  >         - verifier: scripts/ok.sh
  >           result: pass
  >   - id: script-fails
  >     claim: a script's exit code is the verdict
  >     acceptance:
  >       all:
  >         - verifier: scripts/fail.sh
  >           result: pass
  >   - id: script-missing
  >     claim: a script that is not there fails, loudly
  >     acceptance:
  >       all:
  >         - verifier: scripts/missing.sh
  >           result: pass
  >   - id: script-escapes
  >     claim: a path leaving the repository fails, loudly
  >     acceptance:
  >       all:
  >         - verifier: scripts/../outside.sh
  >           result: pass
  >   - id: script-not-executable
  >     claim: a non-executable script fails, loudly
  >     acceptance:
  >       all:
  >         - verifier: scripts/ok.sh.bak
  >           result: pass
  >   - id: script-needs-a-shell
  >     claim: a shell one-liner is refused, not skipped
  >     acceptance:
  >       all:
  >         - verifier: scripts/ok.sh | grep ok
  >           result: pass
  >   - id: module-missing
  >     claim: a tests/*.ml path is recognised and checked
  >     acceptance:
  >       all:
  >         - verifier: tests/absent_module.ml
  >           result: pass
  >   - id: module-case-missing
  >     claim: a tests/*.ml::case path is recognised and checked
  >     acceptance:
  >       all:
  >         - verifier: tests/absent_module.ml::some_case
  >           result: pass
  >   - id: cram-missing
  >     claim: a tests/*.t path is recognised and checked
  >     acceptance:
  >       all:
  >         - verifier: tests/cli/absent.t
  >           result: pass
  >   - id: dune-needs-a-shell
  >     claim: a dune one-liner with a pipe is refused
  >     acceptance:
  >       all:
  >         - verifier: dune build @install | tail -1
  >           result: pass
  >   - id: unknown-scheme
  >     claim: an unrecognised scheme is still skipped
  >     acceptance:
  >       all:
  >         - verifier: this-decision-file-present
  >           result: pass
  > axiom_link:
  >   - A0
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > relations:
  >   addresses:
  >     - bootstrap-v3@3
  > counterexample: |
  >   None — synthetic.
  > YAML
  $ printf 'not a script\n' > scripts/ok.sh.bak

A script runs: the exit code IS the verdict.

  $ $INSIDE_DUNE/bin/mathc.exe verify scratch.yaml 2>/dev/null | grep -E 'script-passes|script-fails'
    script-passes: pass
    script-fails: fail

A path that is not in the repository is `fail` with the reason —
never `skipped`. The reason names the rule that broke.

  $ $INSIDE_DUNE/bin/mathc.exe verify scratch.yaml 2>&1 >/dev/null | sed "s|$tmp|<TMP>|g" | grep 'no such file' | head -2
  mathc verify: scripts/missing.sh — scripts/missing.sh: no such file in the repository (looked in <TMP>)
  mathc verify: tests/absent_module.ml — tests/absent_module.ml: no such file in the repository (looked in <TMP>)

The `..` rule and the executable rule each have their own message.

  $ $INSIDE_DUNE/bin/mathc.exe verify scratch.yaml 2>&1 >/dev/null | grep '`\.\.` segment'
  mathc verify: scripts/../outside.sh — scripts/../outside.sh: `..` segment; a verifier names a file inside the repository
  $ $INSIDE_DUNE/bin/mathc.exe verify scratch.yaml 2>&1 >/dev/null | grep 'not executable'
  mathc verify: scripts/ok.sh.bak — scripts/ok.sh.bak: not executable

Every `tests/` path form is planned before anything runs, so a
missing module, a missing case selector and a missing cram file all
fail the same way. Four hits: scripts/missing.sh, tests/absent_module.ml,
the same module through its `::case` form, and tests/cli/absent.t.
Under the old resolver all four were `skipped`.

  $ $INSIDE_DUNE/bin/mathc.exe verify scratch.yaml 2>&1 >/dev/null | grep -c 'no such file in the repository'
  4

A verifier that needs a shell names the metacharacter that stopped
it. The kernel never spawns /bin/sh, and an obligation that did not
run is not a `skipped` obligation.

  $ $INSIDE_DUNE/bin/mathc.exe verify scratch.yaml 2>&1 >/dev/null | grep "shell metacharacter"
  mathc verify: scripts/ok.sh | grep ok — scripts/ok.sh: contains the shell metacharacter '|'; `mathc verify` never runs a shell, so this obligation cannot be checked here
  mathc verify: dune build @install | tail -1 — contains the shell metacharacter '|'; `mathc verify` never runs a shell, so this obligation cannot be checked here

Back-compat: a token that is neither a scheme nor a path form is
still `skipped`, and `skipped` still exits 0 for that obligation.

  $ $INSIDE_DUNE/bin/mathc.exe verify scratch.yaml 2>/dev/null | grep 'unknown-scheme'
    unknown-scheme: skipped

Cleanup.

  $ cd /
  $ unset MATH_CODING_ROOT
  $ rm -rf "$tmp"
