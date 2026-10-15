scripts/confluence2madr.py reads a Confluence export JSON
file and writes one MADR-shaped markdown file per page. The
output is a draft: the reviewer fills the TBD sections before
passing each .md to `mathc import-adr`.

The cram shell's cwd is a bwrap tmp dir. python3 is on the
PATH. The fixture JSON lives in tests/fixtures/.

`--help`-style bad-arg: missing positional args.

  $ cd "$DUNE_SOURCEROOT"
  $ if python3 scripts/confluence2madr.py 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on missing args"; exit 1
  > else
  >   echo "missing args refused (exit $?)"
  > fi
  missing args refused (exit 2)

`--help`-style bad-arg: input path that is not a file.

  $ cd "$DUNE_SOURCEROOT"
  $ if python3 scripts/confluence2madr.py /tmp/does-not-exist.json /tmp/x 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on missing input"; exit 1
  > else
  >   echo "missing input refused (exit $?)"
  > fi
  missing input refused (exit 2)

Happy path: the confluence-sample fixture has one page whose
title is "Use Postgres for new billing service" and whose
storage HTML contains "Postgres" and "ACID".

  $ cd "$DUNE_SOURCEROOT"
  $ out=$(mktemp -d)
  $ python3 scripts/confluence2madr.py tests/fixtures/confluence-sample.json "$out" >/dev/null
  $ test "$(ls "$out" | wc -l)" = "1" && echo "one .md file written"
  one .md file written
  $ test -f "$out/0001-use-postgres-for-new-billing-service.md" && echo "filename kebab-cased from title"
  filename kebab-cased from title
  $ head -1 "$out/0001-use-postgres-for-new-billing-service.md"
  ---
  $ grep -q '^status: proposed$' "$out/0001-use-postgres-for-new-billing-service.md" && \
  >   echo "frontmatter has status: proposed"
  frontmatter has status: proposed
  $ grep -q '^## Context$' "$out/0001-use-postgres-for-new-billing-service.md" && \
  >   echo "MADR body has ## Context section"
  MADR body has ## Context section
  $ grep -q 'Postgres' "$out/0001-use-postgres-for-new-billing-service.md" && \
  >   echo "body text carries the page content (Postgres preserved)"
  body text carries the page content (Postgres preserved)
  $ grep -q 'ACID' "$out/0001-use-postgres-for-new-billing-service.md" && \
  >   echo "body text strips HTML and keeps reasons (ACID preserved)"
  body text strips HTML and keeps reasons (ACID preserved)
  $ grep -q '^## Decision$' "$out/0001-use-postgres-for-new-billing-service.md" && \
  >   echo "MADR body has ## Decision section"
  MADR body has ## Decision section
  $ rm -rf "$out"
