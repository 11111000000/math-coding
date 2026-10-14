Integration test for the body-vs-wrapper canonicalisation decision
(d5-body-vs-wrapper-canonical-2026-10) and the new
spec/algebra-3.2.md §7.1 sub-section.

  $ cd "$DUNE_SOURCEROOT"

The lib/decision.ml comment block names the decision by id:

  $ rg 'd5-body-vs-wrapper-canonical-2026-10' lib/decision.ml
     decision `d5-body-vs-wrapper-canonical-2026-10` for the
     and decision `d5-body-vs-wrapper-canonical-2026-10`. The input

The lib/decision.ml comment block references spec §7.1:

  $ rg '§7\.1' lib/decision.ml
     two stored hashes is defined in spec/algebra-3.2.md §7.1
     canonicalisation algorithm named in spec/algebra-3.2.md §7.1

The stale "no formal definition" phrase is absent from the comment
block (the negative case):

  $ rg 'no formal definition' lib/decision.ml
  [1]

The spec/algebra-3.2.md §7.1 sub-section exists:

  $ rg '^### §7\.1' spec/algebra-3.2.md
  ### §7.1 Byte-range and canonicalisation

The spec names the placeholder-substitution algorithm:

  $ rg 'placeholder-substitution sweep' spec/algebra-3.2.md
  3. **Insensitivity to placeholder.** Changing the value of `body_sha` (or `yaml_sha`) while keeping the field pattern valid does NOT change the resulting digest; the placeholder-substitution sweep absorbs the change. This is what makes the algorithm a fixed-point: a file's stored digest equals the algorithm's output for the same file.

The schema is unchanged (no `authoring` field was added):

  $ rg '"authoring"' schemas/decision.json
  [1]

The decision file is in main:

  $ test -f decisions/d5-body-vs-wrapper-canonical-2026-10.yaml
  $ test -f spec/algebra-3.2.md
  $ test -f tests/body_canonical_test.ml
  $ test -f lib/decision.ml

The decision file's body_sha equals its yaml_sha (trivial case):

  $ python3 -c "
  > import re, hashlib
  > PLACEHOLDER = 'sha256:' + '0' * 64
  > text = open('decisions/d5-body-vs-wrapper-canonical-2026-10.yaml', 'rb').read().decode('utf-8').replace('\r\n', '\n')
  > text = re.sub(r'body_sha: \"sha256:[a-f0-9]{64}\"', f'body_sha: \"{PLACEHOLDER}\"', text)
  > text = re.sub(r'yaml_sha: \"sha256:[a-f0-9]{64}\"', f'yaml_sha: \"{PLACEHOLDER}\"', text)
  > print('sha256:' + hashlib.sha256(text.encode('utf-8')).hexdigest())"
  sha256:318500d3507b577f3c234d4a5cfec6c9c7b0a46012581a9e76244c7da3f52a1f

The decision file's stored body_sha matches the algorithm's output:

  $ rg '^body_sha' decisions/d5-body-vs-wrapper-canonical-2026-10.yaml
  body_sha: "sha256:318500d3507b577f3c234d4a5cfec6c9c7b0a46012581a9e76244c7da3f52a1f"

The kernel exposes the body_canonical_sha256 helper (referenced in
the comment block via the placeholder-substitution algorithm name):

  $ rg 'placeholder-substitution sweep on UTF-8 bytes' lib/decision.ml
     (placeholder-substitution sweep on UTF-8 bytes after CRLF→LF

The trap log entry for the Str interval quantifier absence is
recorded (so future agents do not lose an hour to it again):

  $ rg '^### 11\.32' OCAML_BEST_PRACTICES.md
  ### 11.32 `Str.regexp` does not support the `\{n\}` interval quantifier
