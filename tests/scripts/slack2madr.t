scripts/slack2madr.py reads a Slack export zip and writes one
MADR-shaped markdown file per decision-like message. A message
is "decision-like" when it is a thread starter with at least one
reply, or when it has at least two reactions across all reaction
names. The output is a draft: the reviewer fills the TBD
sections before passing each .md to `mathc import-adr`.

The cram shell's cwd is a bwrap tmp dir. python3 is on the
PATH. The fixture zip lives in tests/fixtures/.

`--help`-style bad-arg: missing positional args.

  $ cd "$DUNE_SOURCEROOT"
  $ if python3 scripts/slack2madr.py 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on missing args"; exit 1
  > else
  >   echo "missing args refused (exit $?)"
  > fi
  missing args refused (exit 2)

`--help`-style bad-arg: zip path that is not a file.

  $ cd "$DUNE_SOURCEROOT"
  $ if python3 scripts/slack2madr.py /tmp/does-not-exist.zip /tmp/x 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on missing zip"; exit 1
  > else
  >   echo "missing zip refused (exit $?)"
  > fi
  missing zip refused (exit 2)

Happy path: the slack-sample fixture has a thread starter
("Let's switch to Postgres...") with one reply, and the reply
itself has 3 reactions of one name. Both qualify as
decision-like.

  $ cd "$DUNE_SOURCEROOT"
  $ out=$(mktemp -d)
  $ python3 scripts/slack2madr.py tests/fixtures/slack-sample.zip "$out" >/dev/null
  $ test "$(ls "$out" | wc -l)" = "2" && echo "two .md files written"
  two .md files written
  $ test -f "$out/0001-test-channel-2023-10-01.md" && echo "first .md filename is 0001-test-channel-2023-10-01.md"
  first .md filename is 0001-test-channel-2023-10-01.md
  $ head -1 "$out/0001-test-channel-2023-10-01.md"
  ---
  $ grep -q '^status: proposed$' "$out/0001-test-channel-2023-10-01.md" && \
  >   echo "frontmatter has status: proposed"
  frontmatter has status: proposed
  $ grep -q '^## Context$' "$out/0001-test-channel-2023-10-01.md" && \
  >   echo "MADR body has ## Context section"
  MADR body has ## Context section
  $ grep -q '^## Decision$' "$out/0001-test-channel-2023-10-01.md" && \
  >   echo "MADR body has ## Decision section"
  MADR body has ## Decision section
  $ grep -q '^## Counterexample$' "$out/0001-test-channel-2023-10-01.md" && \
  >   echo "MADR body has ## Counterexample section"
  MADR body has ## Counterexample section
  $ grep -q 'Postgres' "$out/0001-test-channel-2023-10-01.md" && \
  >   echo "body text carries the source message text"
  body text carries the source message text
  $ rm -rf "$out"
