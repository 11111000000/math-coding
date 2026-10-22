mathc new-decision <id> scaffolds a new decision YAML from a
canonical template. The dispatcher prints to stdout (default),
writes to <resolved-dir>/<id>.yaml (--write), or runs the
--interactive stub (no-op in this slice). The id is validated
against the same kebab-case regex used by mathc validate.

The cram shell's cwd is a bwrap tmp dir. mathc is on the PATH
(deps %{bin:mathc} in tests/cli/dune). Each case creates a
fresh mktemp dir as the project root, runs `mathc new-decision`
with MATH_CODING_ROOT pointed at it, then asserts on the output.

The kernel emits the canonical 47-line template on `print`
and `write`, plus a soft stderr warning
`deficit/MC-AXIOM-LINK-INFERENCE-EMPTY: ...` whenever the
template lacks `axiom_link`. We `2>/dev/null` the warning
out of each assertion (the warning is exercised by a
dedicated test, axiom-link-inference-2026-10) and grep or
sed for the structural tokens we care about.

Print path: id is kebab-case; mathc exits 0 and emits a YAML
template with `id: <id>` and `schema: math-coding/3.2`.
We pin the first three lines (`--- schema: ..., id: <id>`)
to verify the YAML front-matter without depending on the
full body shape, which is load-bearing in a separate test.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ MATH_CODING_ROOT="$tmpdir" mathc new-decision jwt-rotation 2>/dev/null | head -3
  ---
  schema: math-coding/3.2
  id: jwt-rotation
  $ grep -q '^schema: math-coding/3.2' <(MATH_CODING_ROOT="$tmpdir" mathc new-decision jwt-rotation 2>/dev/null) \
  >   && echo "schema-string: ok"
  schema-string: ok
  $ rm -rf "$tmpdir"

Write path: --write creates <id>.yaml under the resolved decisions
directory of the project root and prints the path. The directory
is created if absent, parents included.

The project root here is a fresh `mktemp -d`, i.e. an empty tree.
`Path_config.layout_of` answers `New` for a tree carrying no
layout marker, so the resolved directory is `.math-coding/decisions`.
That is the same answer `mathc init` gives for the same input -- see
`init.t`, which pins `.math-coding/` for a fresh tmpdir and pins
`decisions/` only under explicit legacy env-vars (`init-legacy.t`).
An earlier revision of this file asserted `<TMP>/decisions/`, which
contradicted its own sibling fixture and could never have passed.

The printed path is mktemp-random so we sed-normalise the
prefix to `<TMP>` (kernel writes both stdout and stderr;
`2>/dev/null` would suppress the soft axiom-link warning but
also hide the path on hosts where --write uses stderr; we
sed-strip the tmpdir prefix instead).

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ MATH_CODING_ROOT="$tmpdir" mathc new-decision jwt-rotation --write 2>&1 | sed "s|$tmpdir|<TMP>|g"
  deficit/MC-AXIOM-LINK-INFERENCE-EMPTY: scope.paths includes <path/glob/that/this/decision/touches/**>; top candidates: A0 (separation); add axiom_link
  mathc new-decision: wrote <TMP>/.math-coding/decisions/jwt-rotation.yaml
  $ test -f "$tmpdir/.math-coding/decisions/jwt-rotation.yaml" && echo "file: ok"
  file: ok
  $ grep -q '^id: jwt-rotation' "$tmpdir/.math-coding/decisions/jwt-rotation.yaml" && echo "id in file: ok"
  id in file: ok

The scaffolded file carries the digest of its OWN bytes, not the
64-zero placeholder earlier revisions wrote. `mathc rehash` is the
oracle here: it reports `0 changed` only when the stored digest is
already what the kernel would compute, so this asserts the property
instead of pinning a hex literal — the digest is a function of the
whole template, so every template edit would otherwise move the
expectation for no reason. A scaffold that shipped the placeholder
would report `1 changed` here, and the file would not validate.

  $ mathc rehash "$tmpdir/.math-coding/decisions/jwt-rotation.yaml" | tail -1
  rehash: 0 changed, 1 already current, 0 skipped (dry-run)
  $ rm -rf "$tmpdir"

Force-overwrite guard: a second --write without --force exits
1 and prints a 'pass --force to overwrite' message; the
existing file content is untouched.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ MATH_CODING_ROOT="$tmpdir" mathc new-decision jwt-rotation --write >/dev/null 2>/dev/null
  $ if MATH_CODING_ROOT="$tmpdir" mathc new-decision jwt-rotation --write 2>/dev/null; then
  >   echo "FAIL: expected exit 1 on overwrite"; exit 1
  > else
  >   echo "second --write refused (exit $?)"
  > fi
  second --write refused (exit 1)
  $ rm -rf "$tmpdir"

Interactive path: --interactive is a no-op stub in this slice;
mathc prints the template with a one-line note and exits 0.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ MATH_CODING_ROOT="$tmpdir" mathc new-decision jwt-rotation --interactive 2>/dev/null | head -1
  mathc new-decision: --interactive is a no-op stub in this slice; the printed template below is the scaffold.
  $ rm -rf "$tmpdir"

Negative case: invalid id (uppercase) exits 2 with the regex
violation message.

  $ cd "$DUNE_SOURCEROOT"
  $ if mathc new-decision BadID 2>/dev/null; then
  >   echo "FAIL: expected non-zero exit on invalid id"; exit 1
  > else
  >   echo "invalid id refused (exit $?)"
  > fi
  invalid id refused (exit 2)

Minimal template: `--template=minimal` emits the 5-7 user-editable
field stub on schema `math-coding/3.3`. The output includes
`state: active` and links `bootstrap-v3@3` via `relations.addresses`.
The output passes `mathc validate` (the kernel's `parse-ok`
verdict is the live accept token; the soft
`deficit/MC-COUNTEREXAMPLE-MISSING` warning is expected because
the user fills the stub in).

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ stub=$tmpdir/min-stub.yaml
  $ MATH_CODING_ROOT="$tmpdir" mathc new-decision test-min-id --template=minimal > "$stub"
  $ grep -q '^schema: math-coding/3.3' "$stub" && echo "schema 3.3: ok"
  schema 3.3: ok
  $ grep -q '^state: active' "$stub" && echo "state active: ok"
  state active: ok
  $ grep -q '^  addresses:' "$stub" && grep -q '^    - bootstrap-v3@3' "$stub" \
  >   && echo "relations.bootstrap-v3: ok"
  relations.bootstrap-v3: ok
  $ mathc validate "$stub" 2>&1 | grep -qE '^(parse-ok|accept):' && echo "validate: ok"
  validate: ok
  $ rm -rf "$tmpdir"

Full template default: the existing 47-line output structure is
preserved on schema `math-coding/3.2` (the shape ships from
`ux-3-new-decision-subcommand-2026-10@1`). `--template=full`
explicit and the bare default emit the same content.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ stub=$tmpdir/full-stub.yaml
  $ default=$tmpdir/full-default.yaml
  $ MATH_CODING_ROOT="$tmpdir" mathc new-decision test-full-id --template=full > "$stub" 2>/dev/null
  $ MATH_CODING_ROOT="$tmpdir" mathc new-decision test-full-id > "$default" 2>/dev/null
  $ diff -u "$stub" "$default" >/dev/null && echo "default == --template=full: ok"
  default == --template=full: ok
  $ grep -q '^schema: math-coding/3.2' "$stub" && echo "schema 3.2: ok"
  schema 3.2: ok
  $ rm -rf "$tmpdir"

Invalid --template value: `--template=invalid` exits 2 with the
"expected minimal|full" diagnostic.

  $ cd "$DUNE_SOURCEROOT"
  $ if mathc new-decision test-id --template=invalid 2>/dev/null; then
  >   echo "FAIL: expected exit 2 on invalid --template"; exit 1
  > else
  >   echo "invalid template refused (exit $?)"
  > fi
  invalid template refused (exit 2)

Minimal-pipes-validation round-trip: the minimal stub round-trips
through `mathc validate --format=json` (via a temp file because
`mathc validate` takes FILE not stdin) and exits 0 with verdict
`parse-ok` (the live accept token after the validate-protocol
bump; the older `accept` is kept as a tolerated alias for
in-tree callers).

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ stub=$tmpdir/min-stub.yaml
  $ MATH_CODING_ROOT="$tmpdir" mathc new-decision test-id --template=minimal > "$stub"
  $ mathc validate --format=json "$stub" 2>/dev/null | jq -r '.verdict' 2>/dev/null || echo "no jq available"
  parse-ok
  $ rm -rf "$tmpdir"
