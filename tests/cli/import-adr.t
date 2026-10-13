mathc import-adr reads an existing ADR file (MADR or
adr-tools shape) and emits a math-coding decision YAML. By
default the YAML is printed to stdout; with --write, the YAML
is written to decisions/<id>.yaml and mathc validate accepts it
(after the reviewer fills in scope.paths).

The cram shell's cwd is a bwrap tmp dir. mathc is on the PATH
(deps %{bin:mathc} in tests/cli/dune). Each case creates a
fresh mktemp dir, writes a small ADR file, runs `mathc
import-adr`, then asserts on the output (or the resulting
decisions/ tree in --write mode).

MADR-shaped file (frontmatter with `status:`) is detected and
the status is mapped to the math-coding state.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ cat > "$tmpdir/adr1.md" <<EOF
  > ---
  > status: accepted
  > date: 2024-01-15
  > ---
  > 
  > # Use PostgreSQL
  > 
  > ## Context and Problem Statement
  > 
  > We need a primary database.
  > 
  > ## Decision Outcome
  > 
  > Chosen option: "PostgreSQL", because JSON support.
  > 
  > ### Consequences
  > 
  > Good JSON support.
  > EOF
  $ mathc import-adr "$tmpdir/adr1.md" | head -5
  ---
  schema: math-coding/3.2
  id: use-postgresql
  revision: 1
  state: active
  $ mathc import-adr "$tmpdir/adr1.md" | grep -q '^id: use-postgresql$' && \
  >   echo "id derived from title (kebab-case) ok"
  id derived from title (kebab-case) ok
  $ mathc import-adr "$tmpdir/adr1.md" | grep -q 'state: active$' && \
  >   echo "MADR 'accepted' mapped to state=active ok"
  MADR 'accepted' mapped to state=active ok
  $ rm -rf "$tmpdir"

adr-tools-shaped file (no frontmatter, `## Status` section) is
detected.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ cat > "$tmpdir/adr2.md" <<EOF
  > # 5. Use Redis for caching
  > 
  > Date: 2024-03-20
  > 
  > ## Status
  > 
  > Accepted
  > 
  > ## Context
  > 
  > We have repeated queries to our primary DB.
  > 
  > ## Decision
  > 
  > We will use Redis as a caching layer.
  > EOF
  $ mathc import-adr "$tmpdir/adr2.md" | head -5
  ---
  schema: math-coding/3.2
  id: 5-use-redis-for-caching
  revision: 1
  state: active
  $ mathc import-adr "$tmpdir/adr2.md" | grep -q 'state: active$' && \
  >   echo "adr-tools 'Accepted' mapped to state=active ok"
  adr-tools 'Accepted' mapped to state=active ok
  $ mathc import-adr "$tmpdir/adr2.md" | grep -q '^commitment: |' && \
  >   echo "decision section mapped to commitment ok"
  decision section mapped to commitment ok
  $ rm -rf "$tmpdir"

--write writes the file to decisions/<id>.yaml and the output
passes mathc validate (the reviewer fills in scope.paths, which
is left as a placeholder glob).

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ cat > "$tmpdir/adr3.md" <<EOF
  > # Sample
  > 
  > ## Status
  > 
  > Accepted
  > 
  > ## Context
  > 
  > Context here.
  > 
  > ## Decision
  > 
  > Decision here.
  > EOF
  $ cd "$tmpdir"
  $ mathc import-adr adr3.md --write
  wrote decisions/sample.yaml (id=sample, source_kind=adr-tools)
  $ cd "$DUNE_SOURCEROOT"
  $ test -f "$tmpdir/decisions/sample.yaml" && echo "decisions/sample.yaml: ok"
  decisions/sample.yaml: ok
  $ mathc validate "$tmpdir/decisions/sample.yaml" | head -3
  accept: /tmp/nix-shell.U1N979/build_feb560_dune/tmp.o4XbUgj12f/decisions/sample.yaml
    decision: sample
    revision: 1
  $ rm -rf "$tmpdir"

Missing PATH: exit 2 with usage.

  $ cd "$DUNE_SOURCEROOT"
  $ if mathc import-adr 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on missing PATH"; exit 1
  > else
  >   echo "missing PATH refused (exit $?)"
  > fi
  missing PATH refused (exit 2)

File not found: exit 1 with a clear message.

  $ cd "$DUNE_SOURCEROOT"
  $ if mathc import-adr /tmp/definitely-does-not-exist.md 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on missing file"; exit 1
  > else
  >   echo "missing file refused (exit $?)"
  > fi
  missing file refused (exit 1)
