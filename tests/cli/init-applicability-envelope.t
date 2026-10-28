The scaffolded policy is the adopter's FIRST decision, and it is
about the adopter's own tree. Three surfaces are pinned here:
1. `mathc init` prints the envelope at deploy time, and the print
names the single-maintainer default explicitly.
2. Neither the print nor the scaffolded policy carries the rev-1
exclusion ("A single person maintains it without AI assistance",
Path B) that this decision removed.
3. The scaffolded policy's obligation is EXECUTABLE and names the
adopter's own tree -- `file-exists` on the first entry of
`scope.paths` -- and NOT the kernel's own `mathc self-check`. A
scaffold that hands the adopter a self-referential obligation gives
them an infinite road on day one: the claim "the corpus is healthy"
is not a claim about their change.
4. The scaffolded policy's `counterexample` is a SLOT with an
instruction in it, not an argument written FOR the adopter. The
kernel used to ship a counterexample whose text argued against
skipping the protocol -- an argument the adopter had not made.

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

The scaffolded policy still validates, and it now asks the adopter
about THEIR tree instead of about the kernel's own corpus.

  $ mathc validate .mc/policy.yaml > /dev/null && echo "scaffolded policy: parse-ok"
  scaffolded policy: parse-ok
  $ grep -q 'verifier: file-exists src' .mc/policy.yaml && echo "obligation names the adopter's tree: ok"
  obligation names the adopter's tree: ok
  $ ! grep -q 'verifier: mathc self-check' .mc/policy.yaml && echo "no self-referential obligation: ok"
  no self-referential obligation: ok
  $ ! grep -q 'Path B' .mc/policy.yaml && echo "no Path B in scaffold: ok"
  no Path B in scaffold: ok
  $ grep -q 'TODO(adopter)' .mc/policy.yaml && echo "counterexample is a slot, not a written argument: ok"
  counterexample is a slot, not a written argument: ok
  $ ! grep -q 'default-on' .mc/policy.yaml && echo "no fabricated default-on argument: ok"
  no fabricated default-on argument: ok

Cleanup.

  $ cd "$DUNE_SOURCEROOT"
  $ rm -rf "$tmpdir"
