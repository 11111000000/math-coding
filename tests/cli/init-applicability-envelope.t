The applicability envelope is default-on: `mathc init` installs the
kernel for any project expected to outlive the next refactor, a
single maintainer included (spec/algebra-3.2.md §28 rev 2,
decision `solo-default-on-2026-10@1`). The single Path C class is
`prototype_or_throwaway`.

Three surfaces are pinned here:
1. `mathc init` prints the envelope at deploy time, and the print
names the single-maintainer default explicitly.
2. Neither the print nor the scaffolded policy carries the rev-1
exclusion ("A single person maintains it without AI assistance",
Path B) that this decision removed.
3. The scaffolded policy's `counterexample` is the friction objection
reframed as a mode choice, not as a reason to skip.

Unlike the older `init*.t` fixtures, no expected line here embeds a
`mktemp -d` path: the assertions are greps over captured output, so
this file is path-stable and passes on a clean tree.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ export MATH_CODING_DECISIONS_DIR=".mc/decisions"
  $ export MATH_CODING_ATTESTATIONS_DIR=".mc/attestations"
  $ export MATH_CODING_POLICY=".mc/policy.yaml"
  $ cd "$tmpdir"
  $ mathc init . --no-install > init.log 2>&1
  $ echo "init exit: $?"
  init exit: 0

The envelope is printed, and it names the default.

  $ grep -q 'applicability envelope' init.log && echo "envelope printed: ok"
  envelope printed: ok
  $ grep -q 'single maintainer included' init.log && echo "solo default named: ok"
  solo default named: ok
  $ grep -q 'the one Path C class' init.log && echo "exclusion class named: ok"
  exclusion class named: ok

The rev-1 exclusion is gone from the print.

  $ ! grep -q 'without AI assistance' init.log && echo "rev-1 solo exclusion gone: ok"
  rev-1 solo exclusion gone: ok

The scaffolded policy still validates, and its counterexample now
argues mode choice rather than skip.

  $ mathc validate .mc/policy.yaml > /dev/null && echo "scaffolded policy: parse-ok"
  scaffolded policy: parse-ok
  $ grep -q 'default-on' .mc/policy.yaml && echo "counterexample cites default-on: ok"
  counterexample cites default-on: ok
  $ ! grep -q 'Path B' .mc/policy.yaml && echo "no Path B in scaffold: ok"
  no Path B in scaffold: ok
  $ grep -q 'mode_floor: light' .mc/policy.yaml && echo "counterexample names light floor: ok"
  counterexample names light floor: ok

Cleanup.

  $ cd "$DUNE_SOURCEROOT"
  $ rm -rf "$tmpdir"
