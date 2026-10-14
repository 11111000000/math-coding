mathc new-decision <id> scaffolds a new decision YAML from a
canonical template. The dispatcher prints to stdout (default),
writes to decisions/<id>.yaml (--write), or runs the
--interactive stub (no-op in this slice). The id is validated
against the same kebab-case regex used by mathc validate.

The cram shell's cwd is a bwrap tmp dir. mathc is on the PATH
(deps %{bin:mathc} in tests/cli/dune). Each case creates a
fresh mktemp dir as the project root, runs `mathc new-decision`
with MATH_CODING_ROOT pointed at it, then asserts on the output.

Print path: id is kebab-case; mathc exits 0 and emits a YAML
template with `id: <id>` and `schema: math-coding/3.2`.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ MATH_CODING_ROOT="$tmpdir" mathc new-decision jwt-rotation
  --- (glob)
     schema: math-coding/3.2
     id: jwt-rotation (glob)
  $ grep -q '^schema: math-coding/3.2' <(MATH_CODING_ROOT="$tmpdir" mathc new-decision jwt-rotation) \
  >   && echo "schema-string: ok"
  schema-string: ok
  $ rm -rf "$tmpdir"

Write path: --write creates decisions/<id>.yaml in the project
root and prints the path. The directory is created if absent.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ MATH_CODING_ROOT="$tmpdir" mathc new-decision jwt-rotation --write
  mathc new-decision: wrote *tmpdir/decide*/jwt-rotation.yaml (glob)
  $ test -f "$tmpdir/decisions/jwt-rotation.yaml" && echo "file: ok"
  file: ok
  $ grep -q '^id: jwt-rotation' "$tmpdir/decisions/jwt-rotation.yaml" \
  && echo "id in file: ok"
  id in file: ok
  $ rm -rf "$tmpdir"

Force-overwrite guard: a second --write without --force exits
1 and prints a 'pass --force to overwrite' message; the
existing file content is untouched.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ MATH_CODING_ROOT="$tmpdir" mathc new-decision jwt-rotation --write >/dev/null
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
  $ MATH_CODING_ROOT="$tmpdir" mathc new-decision jwt-rotation --interactive | head -1
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