mathc validate on a decision whose mapping declares the same key twice
exits 0 and prints ONE MC-DUPLICATE-KEY line naming the key and both line
numbers. The kernel still reads the first block; the diagnostic is what
makes the unreachable block visible.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc validate tests/cli/fixtures/duplicate-keys/duplicate-obligations-key.yaml
  [warn] conflict/MC-DUPLICATE-KEY: mapping key obligations is declared 2 times in the same scope (lines 21, 30); the kernel reads the FIRST occurrence and the other 1 block is unreachable — that content never reaches the gate. A repeated key is not appended and not overridden; merge the 2 declarations into one.
  parse-ok: tests/cli/fixtures/duplicate-keys/duplicate-obligations-key.yaml
    decision: dup-key-demo
    revision: 1
    obligations: 1
    assumptions: 0
  $ mathc explain-diagnostic MC-DUPLICATE-KEY | jq -c '{code, def_len: (.definition | length), occ_len: (.occurs_when | length), rem_len: (.remediation | length)}'
  {"code":"MC-DUPLICATE-KEY","def_len":142,"occ_len":777,"rem_len":637}

mathc validate on a decision the loader cannot read to EOF prints
MC-UNPARSED-TAIL naming the first unread line and keeps the verdict at
parse-ok. Before the diagnostic the same file validated silently with its
whole tail -- including a second obligations block and risk -- missing.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc validate tests/cli/fixtures/duplicate-keys/unparsed-tail.yaml
  [warn] input/MC-UNPARSED-TAIL: the parser stopped at line 36 ("hit the wrong binary. Mitigation: rename the") and could not read the rest of the file and 15 more line(s); every top-level key from there to EOF is missing from the kernel's reading, so whatever that tail promised is outside the gate. The usual cause is a multi-line scalar the loader cannot follow: a folded plain scalar whose continuation carries a colon ("Mitigation: ..."), a quoted sequence item continued on deeper lines, or a sequence item indented less than its siblings. Put such prose in a `|` block scalar, or align the indentation — the wording does not have to change.
  parse-ok: tests/cli/fixtures/duplicate-keys/unparsed-tail.yaml
    decision: unparsed-tail-demo
    revision: 1
    obligations: 1
    assumptions: 1
  $ mathc explain-diagnostic MC-UNPARSED-TAIL | jq -c '{code, def_len: (.definition | length), occ_len: (.occurs_when | length), rem_len: (.remediation | length)}'
  {"code":"MC-UNPARSED-TAIL","def_len":159,"occ_len":994,"rem_len":517}
