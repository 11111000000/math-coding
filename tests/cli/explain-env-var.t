mathc explain resolves a `decision:<id>` reference via
`decision_relpath`, which now returns a path rooted at the
resolver's `decisions_dir` (per F10 fix #1 in
decisions/path-resolver-audit-2026-11.yaml). The pre-fix
function hard-coded `"decisions/decision.yaml"` for the four
special-case ids and `"decisions/<id>.yaml"` for the general
case, so an env-var override was silently ignored.

Setup: an isolated project at `$tmpdir` with the active-policy
decision (id `bootstrap-v3`) at `.math-coding/decisions/decision.yaml`.
Export MATH_CODING_DECISIONS_DIR and `cd "$tmpdir"` so the
resolver's relative path opens correctly (same convention as
`tests/cli/env-var-resolver.t`).

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ echo '(lang dune 3.0)' > "$tmpdir/dune-project"
  $ mkdir -p "$tmpdir/.math-coding/decisions"
  $ cp decisions/decision.yaml "$tmpdir/.math-coding/decisions/decision.yaml"
  $ cd "$tmpdir"
  $ export MATH_CODING_ROOT="$tmpdir"
  $ export MATH_CODING_DECISIONS_DIR=".math-coding/decisions"

`mathc explain decision:bootstrap-v3` reports a `path` rooted at
`.math-coding/decisions/` (the resolver output), not the
hard-coded `decisions/decision.yaml`.

  $ $INSIDE_DUNE/bin/mathc.exe explain decision:bootstrap-v3 | jq -c '{kind, id, path}'
  {"kind":"decision","id":"bootstrap-v3","path":".math-coding/decisions/decision.yaml"}

Cleanup.

  $ cd /
  $ rm -rf "$tmpdir"
