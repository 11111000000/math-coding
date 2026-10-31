mathc attest-batch end-to-end coverage. Three branches.

Case 1 - `--help` returns the documented usage.

Case 2 - `--manifest=... --dry-run` prints one canonical-JSON
attestation per manifest row to stdout and writes ZERO files
in the output dir (non-destructive).

Case 3 - new-decision -> manifest -> attest-batch flips the
`mathc self-check` verdict for a 5-obligation decision from
`unknown` (no attestations) to `pass` (5 fresh pass
attestations).

This file is the consolidated acceptance crate for the
`a3-attest-batch-shipped` obligation. The four pre-existing
attest-batch cram tests (positive, malformed, dry-run,
from-decisions) cover the deeper unit surfaces; this file
pins the A3 acceptance contract end-to-end.

All branches share the `applies_to whole_subtree` cram rule
in `tests/cli/dune`. Each branch sets up its own hermetic
tmpdir and cleans up before exit.

The cram runner does NOT propagate the host's PATH; calling
`mathc` (the binary name) silently resolves to whichever
`mathc` happens to be first in the cram sandbox's PATH,
which is whatever the operator installed system-wide. To
anchor the test on the binary dune just built, every
branch prefixes with `mathc="$INSIDE_DUNE/bin/mathc.exe"`
(see OCAML_BEST_PRACTICES 11.8 for the rationale).

========================================================================
Case 1 — `mathc attest-batch --help` returns usage on stdout and
exit 0. The dispatch table must register the subcommand; without
the `| "attest-batch" -> do_attest_batch ()` arm the caller
gets `mathc: unknown command: attest-batch` and exit 2.
The end-to-end consequence tested here: the binary returns 0
and the body of the help output contains the literal
"attest-batch" string (so a reader can detect the registered
subcommand without re-running --help twice).
========================================================================

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d) && cd "$tmpdir"
  $ git init -q "$tmpdir"
  $ git -C "$tmpdir" config user.email "t@t"
  $ git -C "$tmpdir" config user.name "t"
  $ git -C "$tmpdir" commit -q --allow-empty -m initial
  $ mathc="$INSIDE_DUNE/bin/mathc.exe"
  $ "$mathc" attest-batch --help > attest-batch-help.txt
  $ echo "exit=$?"
  exit=0
  $ grep -q "attest-batch" attest-batch-help.txt && echo "help contains attest-batch: ok"
  help contains attest-batch: ok
  $ grep -q "^usage:" attest-batch-help.txt && echo "help has usage line: ok"
  help has usage line: ok
  $ cd /
  $ rm -rf "$tmpdir"

========================================================================
Case 2 — `mathc attest-batch --manifest=foo.tsv --dry-run` prints
the would-write payloads to stdout (one JSON line per manifest
row) and writes NO files. This is the operator's preview path:
run the manifest through the binary before committing to the
attestation store.
========================================================================

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d) && cd "$tmpdir"
  $ git init -q "$tmpdir"
  $ git -C "$tmpdir" config user.email "t@t"
  $ git -C "$tmpdir" config user.name "t"
  $ git -C "$tmpdir" commit -q --allow-empty -m initial
  $ export MATH_CODING_DECISIONS_DIR=".test-math-coding/decisions"
  $ export MATH_CODING_ATTESTATIONS_DIR=".test-math-coding/attestations"
  $ mkdir -p "$MATH_CODING_ATTESTATIONS_DIR"  # present, empty
  $ before=$(ls "$MATH_CODING_ATTESTATIONS_DIR" | wc -l)
  $ "$mathc" attest-batch \
  >   --manifest="$DUNE_SOURCEROOT/tests/cli/fixtures/attest-batch/manifest.tsv" \
  >   --run="printf probe" \
  >   --dry-run > /tmp/attest-batch-dry-run.stdout.jsonl

A manifest row that declares a RUNTIME kind with no --run behind
it is refused: the tool would otherwise print `result: pass` for a
run that never happened. The --from=decisions branch has refused this
since v3.3.3; the --manifest branch did not, and that hole is what
decisions/attest-per-obligation-2026-10 closes.

  $ "$mathc" attest-batch \
  >   --manifest="$DUNE_SOURCEROOT/tests/cli/fixtures/attest-batch/manifest.tsv" \
  >   --dry-run 2>&1; echo "exit=$?"
  mathc attest-batch: the manifest declares test attestation(s), and a test attestation claims something ran. Without --run=<command> this command would print `result: pass` for a run that never happened, for every such row. Use --run="dune runtest" (or whatever command produces the artefact) or declare those rows as `review`.
  exit=2
Three manifest rows -> three stdout lines (asserted via
python, which avoids depending on cram glob handling of
nix-shell sandbox tmp paths).

  $ python3 -c "
  > import sys
  > n = 0
  > for line in open('/tmp/attest-batch-dry-run.stdout.jsonl'):
  >     assert line.endswith('\n'), repr(line)
  >     assert line.count('{') == line.count('}'), line
  >     n += 1
  > assert n == 3, ('expected 3 dry-run rows, got', n)
  > print('dry-run rows:', n)
  > "
  dry-run rows: 3

No file appeared in the output dir (the would-write filenames
`<decision>-<obligation>.json` would have appeared if --dry-run
were a no-op rather than a stdout-only path). We assert the
file count via shell `wc -l` rather than glob matching so the
test is robust to the nix-shell-sandbox path layout.

  $ after=$(ls "$MATH_CODING_ATTESTATIONS_DIR" | wc -l)
  $ test "$before" = "$after" && echo "dry-run wrote 0 files (file count $before)"
  dry-run wrote 0 files (file count 0)

The JSON shape matches what --dry-run prints: every line has
schema, kind, subject{decision,obligation,candidate_tree,materials_digest},
kind_, producer{identity}, result, issued_at, and id (sha256:...).
The `id` is the canonical-JSON SHA-256 of the body excluding
`id`, matching the `scripts/generate-attestations.py` byte-for-byte
at the digest boundary.

  $ python3 -c "
  > import hashlib, json
  > ok = 0
  > for line in open('/tmp/attest-batch-dry-run.stdout.jsonl'):
  >     d = json.loads(line)
  >     body = {k: v for k, v in d.items() if k != 'id'}
  >     payload = json.dumps(body, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
  >     expected = 'sha256:' + hashlib.sha256(payload).hexdigest()
  >     assert d['id'] == expected, (d['subject'], d['id'], expected)
  >     ok += 1
  > print('dry-run rows with valid id:', ok)
  > "
  dry-run rows with valid id: 3
  $ rm -f /tmp/attest-batch-dry-run.stdout.jsonl
  $ cd /
  $ rm -rf "$tmpdir"
  $ unset MATH_CODING_DECISIONS_DIR
  $ unset MATH_CODING_ATTESTATIONS_DIR

========================================================================
Case 3 — end-to-end verdict flip for a 5-obligation decision.

Setup: a hermetic tmp project root (with `dune-project` marker
so `find_project_root` resolves via `MATH_CODING_ROOT`) holding
exactly one decision with 5 obligations, all verifiers
`mathc self-check`. The decision's `mode` is `light` so the
counterexample dialectical slot is optional; axiom_link is
present so the axiom-link pre-check passes.

Before attestations: `mathc self-check` walks the only decision
and emits MissingEvidence gaps for all 5 obligations; the top
verdict is `unknown` (5 unknown obligations -> aggregate
Unknown).

After attestations: `mathc attest-batch --manifest=...` writes
5 attestation files (one per obligation, kind_=review,
result=pass, materials_digest="" wildcard); self-check now
finds 5 current pass attestations -> no gaps -> aggregate Pass
-> top verdict `pass`.
========================================================================

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d) && cd "$tmpdir"
  $ git init -q "$tmpdir"
  $ git -C "$tmpdir" config user.email "t@t"
  $ git -C "$tmpdir" config user.name "t"
  $ git -C "$tmpdir" commit -q --allow-empty -m initial
  $ echo '(lang dune 3.21)' > dune-project
  $ mkdir -p decisions attestations
  $ export MATH_CODING_ROOT="$tmpdir"
  $ git init -q "$tmpdir"
  $ git -C "$tmpdir" config user.email "t@t"
  $ git -C "$tmpdir" config user.name "t"
  $ git -C "$tmpdir" commit -q --allow-empty -m initial

Hand-write a parseable v3.2 decision with 5 obligations. The two
SHA fields are stamped with the 64-zero placeholder, which is
length-preserving but no longer sufficient: the kernel recomputes
the digest of the file's own bytes (spec/kernel-contract.md §7.1),
and `mathc self-check` forces the verdict to Block when the stored
value is stale (`MC-SHA-DIGEST-STALE`). So the fixture is rehashed
before either snapshot below. Without that, `before` and `after`
would BOTH be `fail` -- a stale digest forces the verdict after
waiver aggregation, so the five attestations could never move it,
and this case would assert nothing at all.

  $ printf '%s\n' \
  >   '---' \
  >   'schema: math-coding/3.2' \
  >   'id: ship-attest-batch-case3' \
  >   'revision: 1' \
  >   'state: active' \
  >   'mode: light' \
  >   'change_kind: implementation' \
  >   'body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"' \
  >   'yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"' \
  >   'axiom_link:' \
  >   '  - A0' \
  >   '  - A3' \
  >   'intent: |' \
  >   '  Case-3 fixture: a 5-obligation decision used to' \
  >   '  verify that $INSIDE_DUNE/bin/mathc.exe attest-batch flips the self-check' \
  >   '  verdict from unknown to pass.' \
  >   'commitment: |' \
  >   '  Five obligations; each verifier mathc self-check.' \
  >   'counterexample: |' \
  >   '  Hand-rolled batch attestations could over-claim. The' \
  >   '  verifier-half of every obligation is mathc self-check,' \
  >   '  so the run path is the same as production.' \
  >   'scope:' \
  >   '  paths: ["**"]' \
  >   'outcomes:' \
  >   '  - id: o1' \
  >   '    statement: First outcome.' \
  >   'obligations:' \
  >   '  - id: obl-1' \
  >   '    outcome: o1' \
  >   '    claim: First obligation.' \
  >   '    acceptance:' \
  >   '      all:' \
  >   '        - verifier: mathc self-check' \
  >   '  - id: obl-2' \
  >   '    outcome: o1' \
  >   '    claim: Second obligation.' \
  >   '    acceptance:' \
  >   '      all:' \
  >   '        - verifier: mathc self-check' \
  >   '  - id: obl-3' \
  >   '    outcome: o1' \
  >   '    claim: Third obligation.' \
  >   '    acceptance:' \
  >   '      all:' \
  >   '        - verifier: mathc self-check' \
  >   '  - id: obl-4' \
  >   '    outcome: o1' \
  >   '    claim: Fourth obligation.' \
  >   '    acceptance:' \
  >   '      all:' \
  >   '        - verifier: mathc self-check' \
  >   '  - id: obl-5' \
  >   '    outcome: o1' \
  >   '    claim: Fifth obligation.' \
  >   '    acceptance:' \
  >   '      all:' \
  >   '        - verifier: mathc self-check' \
  >   'risk:' \
  >   '  declared_triggers: []' \
  >   '  owner: human:tester' \
  >   'relations:' \
  >   '  addresses: []' \
  >   > decisions/ship-attest-batch-case3.yaml

  $ "$mathc" rehash decisions/ship-attest-batch-case3.yaml --write | sed '/^$/d'
    STAMP ship-attest-batch-case3.yaml
  rehash: 1 changed, 0 already current, 0 skipped (written)

Validate the fixture before exercising the attest flow.

  $ "$mathc" validate decisions/ship-attest-batch-case3.yaml
  parse-ok: decisions/ship-attest-batch-case3.yaml
    decision: ship-attest-batch-case3
    revision: 1
    obligations: 5
    assumptions: 0

Snap the verdict BEFORE running attest-batch. With no
attestations in the store, the decision's 5 obligations all
surface MissingEvidence gaps; aggregate Unknown; top verdict
`unknown`.

  $ export MATH_CODING_ATTESTATIONS_DIR="$tmpdir/attestations"
  $ before=$(MATH_CODING_ROOT="$tmpdir" MATH_CODING_ATTESTATIONS_DIR="$tmpdir/attestations" \
  >          "$mathc" self-check \
  >          | python3 -c "import sys, json; d=json.load(sys.stdin); print([s['verdict'] for s in d['subjects'] if s['name']=='ship-attest-batch-case3'][0])")
  $ echo "before: $before"
  before: unknown

Generate a TSV manifest with one row per obligation. The
default `kind_=review` and `result=pass` match the surface
that operators would hand-write for a brownfield adoption.

  $ cat > "$tmpdir/manifest.tsv" <<TSV
  > # 5-row manifest for ship-attest-batch-case3
  > ship-attest-batch-case3	obl-1	review	human:integration-test	pass
  > ship-attest-batch-case3	obl-2	review	human:integration-test	pass
  > ship-attest-batch-case3	obl-3	review	human:integration-test	pass
  > ship-attest-batch-case3	obl-4	review	human:integration-test	pass
  > ship-attest-batch-case3	obl-5	review	human:integration-test	pass
  > TSV
  $ awk 'NF && $1 !~ /^#/' "$tmpdir/manifest.tsv" > "$tmpdir/manifest-real.tsv"
  $ mv "$tmpdir/manifest-real.tsv" "$tmpdir/manifest.tsv"

Run attest-batch. Five rows -> five files written into the
attestations dir. The `wrote <path>` per-file log goes to
stderr; we redirect to /dev/null and assert the file count via
`ls` (the path is host-sandbox-dependent in nix-shell
environments, so we don't pattern-match on the exact string).

  $ "$mathc" attest-batch \
  >   --manifest="$tmpdir/manifest.tsv" \
  >   --out="$tmpdir/attestations" 2>/dev/null
  $ ls -1 "$tmpdir/attestations" | sort
  ship-attest-batch-case3-obl-1.json
  ship-attest-batch-case3-obl-2.json
  ship-attest-batch-case3-obl-3.json
  ship-attest-batch-case3-obl-4.json
  ship-attest-batch-case3-obl-5.json

Commit them. The store admits only git-TRACKED files
(`store_keep_for` in bin/Mathc.ml): a file that is on disk but
in no commit is not evidence about any tree. Now that this
tmpdir is a real work tree, that admission rule applies, and
five untracked files would read as "no evidence at all" --
which is the correct reading, and would leave the verdict at
`unknown`.
  $ git -C "$tmpdir" add -A
  $ git -C "$tmpdir" commit -q -m attestations

Snap the verdict AFTER attest-batch. The 5 obligations are now
backed by current pass attestations (materials_digest="" is
the self-check wildcard; the kind_/producer pair is
review/human); aggregate Pass; top verdict `pass`. The flip
is the acceptance contract.

  $ after=$(MATH_CODING_ROOT="$tmpdir" MATH_CODING_ATTESTATIONS_DIR="$tmpdir/attestations" \
  >         "$mathc" self-check \
  >         | python3 -c "import sys, json; d=json.load(sys.stdin); print([s['verdict'] for s in d['subjects'] if s['name']=='ship-attest-batch-case3'][0])")
  $ echo "after: $after"
  after: pass

The flip from `unknown` -> `pass` is the assertion the
`a3-attest-batch-shipped` obligation closes. If `before` had
been `pass`, the flip would not be observable and the test
would silently no-op; if `after` is anything other than
`pass`, the binary lost the freshness check.

  $ test "$before" = "unknown" && test "$after" = "pass" \
  >   && echo "verdict flipped: $before -> $after"
  verdict flipped: unknown -> pass

  $ cd /
  $ rm -rf "$tmpdir"
  $ unset MATH_CODING_ROOT
  $ unset MATH_CODING_ATTESTATIONS_DIR
