`mathc self-check` must find the project's decisions regardless of
the directory the process was launched from.

`Path_config.resolve_*` used to probe candidate layouts relative to
the process cwd while their callers composed the result onto the
project root. When those two disagreed, every path that walks the
decisions directory collected nothing. In `do_gate` that produced a
`{"verdict":"pass","obligations":0}` result against a repository holding 199 decisions with 666 unmet
obligations -- an invariant violation rather than a degraded mode,
because `unknown` is laundered into `pass`.

This fixture pins the invariant on `self-check`, which reports a
`subjects` array whose length is derived from the decisions actually
loaded. Running it from an unrelated working directory with only
MATH_CODING_ROOT naming the project must still report a non-zero
subject count. The pre-fix binary satisfies a `verdict` assertion by
finding nothing at all, so only the count distinguishes a real verdict
from an empty scan.

`self-check` is used rather than `gate` because `gate` shells out to
`git` in the process cwd, which fails for reasons unrelated to path
resolution and would mask what this fixture is asserting. `gate`
depends on `git` honouring MATH_CODING_ROOT, which is a separate
defect with a separate fix.

The assertion is `> 0`, never an exact count, so adding a decision
does not break this test. $DUNE_SOURCEROOT is unset on purpose: it
would otherwise be consulted as a root and mask the very disagreement
being tested.

  $ cd "$DUNE_SOURCEROOT"
  $ $INSIDE_DUNE/bin/mathc.exe="$DUNE_SOURCEROOT/_build/default/bin/mathc.exe"
  $ elsewhere=$(mktemp -d)
  $ printf '%s\n' \
  >   '#!/usr/bin/env bash' \
  >   'cd "$1"' \
  >   'exec env -u DUNE_SOURCEROOT MATH_CODING_ROOT="$2" "$3" self-check' \
  >   > run.sh
  $ bash run.sh "$elsewhere" "$DUNE_SOURCEROOT" "$mathc" | jq -e '.subjects | length > 0' >/dev/null && echo "ok: decisions resolved from an unrelated cwd"
  ok: decisions resolved from an unrelated cwd
  $ rm -f run.sh
  $ rm -rf "$elsewhere"
