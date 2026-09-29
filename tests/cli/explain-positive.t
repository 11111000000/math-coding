mc explain resolves a `decision:<id>` reference to its on-disk
file under decisions/ and emits the documented JSON object on
stdout. The fixture scrubs the `digest` (it is a hex SHA-256 of
the verbatim file contents; the .t file asserts only that it is
exactly 64 lowercase hex characters, so the test does not bake
the current file digest in) and the `body` (the YAML body is
hundreds of bytes — including it verbatim would couple the test
to the file's exact contents). Per spec/semantics.md
"explain DETAIL_REF" the output object carries at least
{kind, id, digest, path, body}. Acceptance gate for obligation
mc-explain-dispatcher-shipped in
decisions/mc-explain-subcommand.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc explain decision:bootstrap-v3 | jq -c '{kind, id, path, digest_len: (.digest | length), body_present: (has("body") and (.body | length > 0))}'
  {"kind":"decision","id":"bootstrap-v3","path":"decisions/decision.yaml","digest_len":64,"body_present":true}
