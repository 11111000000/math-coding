Integration test for the body-vs-wrapper canonicalisation decision
(d5-body-vs-wrapper-canonical-2026-10) and the canonicalisation the
kernel implements (kernel contract §7.1).

WHAT IS NOT PINNED HERE, AND WHY. This fixture used to assert that
the contract carried a §7.1 sub-section and that the sub-section named
the placeholder-substitution sweep. That mirror is what the contract's
shrink removes: a fixture that greps the prose breaks the moment the
prose is rewritten, and the prose is rewritten now. The algorithm is
the CODE's -- the kernel and the Python reference each carry it --
and the conformance test `tests/body_canonical_test.ml` pins its four
properties. What this fixture holds is the code.

  $ cd "$DUNE_SOURCEROOT"

The lib/decision.ml comment block names the decision by id:

  $ rg 'd5-body-vs-wrapper-canonical-2026-10' lib/decision.ml
     decision `d5-body-vs-wrapper-canonical-2026-10` for the
     and decision `d5-body-vs-wrapper-canonical-2026-10`. The input

The lib/decision.ml comment block references spec §7.1. Four
mentions now: the two that introduced the canonicalisation, plus
two added by the digest-recompute work, which had to spell out
why §7.1 says the scheme prefix appears exactly once.

  $ rg '§7\.1' lib/decision.ml
     two stored hashes is defined in spec/kernel-contract.md §7.1
     canonicalisation algorithm named in spec/kernel-contract.md §7.1
     Kernel contract §7.1 reads:
     neither §7.1, nor the Python reference

The stale "no formal definition" phrase is absent from the comment
block (the negative case):

  $ rg 'no formal definition' lib/decision.ml
  [1]

The Python reference carries the same placeholder the kernel
substitutes. The two implementations are the algorithm; the document
is only the index that says where they live.

  $ rg 'PLACEHOLDER = "sha256:" \+ "0" \* 64' scripts/axiom-link-seed.py
  PLACEHOLDER = "sha256:" + "0" * 64

The schema is unchanged (no `authoring` field was added):

  $ rg '"authoring"' schemas/decision.json
  [1]

The decision file is in main:

  $ test -f decisions/d5-body-vs-wrapper-canonical-2026-10.yaml
  $ test -f "$DUNE_SOURCEROOT/spec/kernel-contract.md"
  $ test -f tests/body_canonical_test.ml
  $ test -f lib/decision.ml

The decision file's body_sha equals its yaml_sha (trivial case).
The dynamic SHA is recomputed from the live file so the assertion
survives future edits to the decision's metadata (a content
change that did NOT also touch body_sha / yaml_sha would
recompute to a different hash, but since both lines live in
the same one-line replace map below, the printed hash will
match the algorithm's redigest of the canonical body):

  $ computed_hex=$(python3 -c "
  > import re, hashlib
  > PLACEHOLDER = 'sha256:' + '0' * 64
  > text = open('decisions/d5-body-vs-wrapper-canonical-2026-10.yaml', 'rb').read().decode('utf-8').replace('\r\n', '\n')
  > text = re.sub(r'body_sha: \"sha256:[a-f0-9]{64}\"', f'body_sha: \"{PLACEHOLDER}\"', text)
  > text = re.sub(r'yaml_sha: \"sha256:[a-f0-9]{64}\"', f'yaml_sha: \"{PLACEHOLDER}\"', text)
  > print(hashlib.sha256(text.encode('utf-8')).hexdigest())")
  $ stored_hex=$(rg '^body_sha' decisions/d5-body-vs-wrapper-canonical-2026-10.yaml | sed 's/^body_sha: "sha256:\([a-f0-9]\{64\}\)"/\1/')
  $ [ "$stored_hex" = "$computed_hex" ] && echo "stored body_sha matches algorithm output: ok"
  stored body_sha matches algorithm output: ok

The kernel exposes the body_canonical_sha256 helper (referenced in
the comment block via the placeholder-substitution algorithm name):

  $ rg 'placeholder-substitution sweep on UTF-8 bytes' lib/decision.ml
     (placeholder-substitution sweep on UTF-8 bytes after CRLF→LF

The trap log entry for the Str interval quantifier absence is
recorded (so future agents do not lose an hour to it again):
(OCAML_BEST_PRACTICES.md was renamed to OCAML_KERNEL_CONVENTIONS.md
in commit 45b21439; the trap log entry moved with the rest of the doc.)

  $ rg '^### 11\.32' OCAML_KERNEL_CONVENTIONS.md
  ### 11.32 `Str.regexp` does not support the `\{n\}` interval quantifier
