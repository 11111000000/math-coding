mc explain exits 2 and emits a typed JSON diagnostic on stderr
when the kind is unrecognised. Per spec/semantics.md
"explain DETAIL_REF": on an unresolvable ref a typed diagnostic
is emitted on stderr with `code`
(MC-REF-UNKNOWN | MC-REF-AMBIGUOUS | MC-REF-INVALID). Cram
captures stderr to the expected output and the `[2]` line
asserts the exit code. Acceptance gate for obligation
mc-explain-dispatcher-shipped in
decisions/mc-explain-subcommand.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc explain nonexistent:foo
  {"code":"MC-REF-UNKNOWN","id":"foo","kind":"nonexistent","message":"kind 'nonexistent' is not addressable to a single file in this revision; the dispatcher resolves decision/spec/axiom/doc only"}
  [2]
