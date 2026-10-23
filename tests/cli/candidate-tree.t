`subject.candidate_tree` is the field that answers "which tree was
this observed at". It carried the literal `HEAD` from
`bin/Mathc.ml:3302` for the whole 3.3 series, so no attestation in
the committed store named a tree and none could be reproduced or
refuted. These cases pin the two halves of the fix: that a write now
resolves a real commit id, and that when it cannot, the command
refuses instead of inventing a value.

Acceptance gates for `decisions/candidate-tree-resolves-to-a-commit-2026-10.yaml`:
- obligation `new-attestation-carries-a-commit-id`
- obligation `missing-git-refuses-rather-than-falls-back`
- obligation `gate-comment-describes-implemented-filter`

  $ cd "$DUNE_SOURCEROOT"

Hermetic by construction: every case builds its OWN repository and
points `MATH_CODING_ROOT` at it, so nothing here depends on whether
the checkout running the suite happens to be under version control.

  $ tmp=$(mktemp -d)
  $ mkdir -p "$tmp/tree"
  $ cd "$tmp/tree"
  $ git init -q .
  $ git config user.email "t@t"
  $ git config user.name "t"
  $ echo a > a && git add . && git commit -q -m initial
  $ sha=$(git rev-parse --verify HEAD)
  $ export MATH_CODING_ROOT="$tmp/tree"
  $ manifest="$DUNE_SOURCEROOT/tests/cli/fixtures/attest-batch/manifest.tsv"

A batch written into a tree that HAS a commit carries that commit's
id -- a full object id, not a symbolic ref:

  $ mkdir -p "$tmp/out"
  $ mathc attest-batch --manifest="$manifest" --out="$tmp/out" --run="printf probe" > /dev/null 2>&1
  $ one="$tmp/out/d1-onboarding-d1-obl-acceptance.json"
  $ test -f "$one" && echo "attestation written: ok"
  attestation written: ok
  $ grep -oE '"candidate_tree":"[0-9a-f]{40}"' "$one" > /dev/null && echo "candidate_tree is a 40-hex object id: ok"
  candidate_tree is a 40-hex object id: ok
  $ test "$(grep -o '"candidate_tree":"[^"]*"' "$one")" = "\"candidate_tree\":\"$sha\"" && echo "equals git rev-parse --verify HEAD: ok"
  equals git rev-parse --verify HEAD: ok
  $ grep -q '"candidate_tree":"HEAD"' "$one" && echo "REGRESSED: wrote the literal HEAD" || echo "literal HEAD not written: ok"
  literal HEAD not written: ok

Now the three ways the tree can fail to resolve. Each must exit 2,
name the reason, and leave the output directory empty. The `HEAD`
grep is the load-bearing one: a fallback that printed `HEAD` and
still exited nonzero would satisfy the exit-code check alone.

  $ mkdir -p "$tmp/notrepo" "$tmp/outA"
  $ MATH_CODING_ROOT="$tmp/notrepo" mathc attest-batch --manifest="$manifest" --out="$tmp/outA" > "$tmp/a.out" 2> "$tmp/a.err"; echo "EXIT=$?"
  EXIT=2
  $ test "$(ls -A "$tmp/outA" | wc -l)" = 0 && echo "no file written: ok"
  no file written: ok
  $ grep -q 'refusing to write an attestation with an unanchored candidate_tree' "$tmp/a.err" && echo "refusal names the field: ok"
  refusal names the field: ok
  $ grep -q '"candidate_tree":"HEAD"' "$tmp/a.out" "$tmp/a.err" && echo "REGRESSED: fell back to HEAD" || echo "no HEAD fallback: ok"
  no HEAD fallback: ok

A repository with no commits has no tree to name, and is refused on
the same terms:

  $ mkdir -p "$tmp/outB"
  $ git init -q "$tmp/empty"
  $ MATH_CODING_ROOT="$tmp/empty" mathc attest-batch --manifest="$manifest" --out="$tmp/outB" > "$tmp/b.out" 2> "$tmp/b.err"; echo "EXIT=$?"
  EXIT=2
  $ test "$(ls -A "$tmp/outB" | wc -l)" = 0 && echo "no file written: ok"
  no file written: ok
  $ grep -q '"candidate_tree":"HEAD"' "$tmp/b.out" "$tmp/b.err" && echo "REGRESSED: fell back to HEAD" || echo "no HEAD fallback: ok"
  no HEAD fallback: ok

And with `git` absent from PATH entirely. `mathc` is invoked by
absolute path because the PATH override removes it too:

  $ mkdir -p "$tmp/nopath" "$tmp/outC"
  $ mathc_bin=$(command -v mathc)
  $ PATH="$tmp/nopath" "$mathc_bin" attest-batch --manifest="$manifest" --out="$tmp/outC" > "$tmp/c.out" 2> "$tmp/c.err"; echo "EXIT=$?"
  EXIT=2
  $ grep -q 'refusing to write an attestation with an unanchored candidate_tree' "$tmp/c.err" && echo "refusal names the field: ok"
  refusal names the field: ok
  $ test "$(ls -A "$tmp/outC" | wc -l)" = 0 && echo "no file written: ok"
  no file written: ok

The gate comment is the third obligation. It previously claimed a
`ra_scope_paths` filter that the function does not implement. Two
assertions, one on each side of the same claim: the comment must say
the predicate is unenforced, and the function must actually not read
it.

  $ cd "$DUNE_SOURCEROOT"
  $ awk '/required_attestation_satisfied$/{f=1} f{print} f && /^    store$/{exit}' lib/gate.ml > "$tmp/rat.ml"
  $ test "$(grep -c 'String.equal' "$tmp/rat.ml")" = 2 && echo "filter has exactly two predicates (kind_, producer): ok"
  filter has exactly two predicates (kind_, producer): ok
  $ test "$(grep -c 'ra_scope_paths' "$tmp/rat.ml")" = 0 && echo "filter never reads ra_scope_paths: ok"
  filter never reads ra_scope_paths: ok
  $ grep -q 'ra_scope_paths` is NOT enforced' lib/gate.ml && echo "comment states the predicate is unenforced: ok"
  comment states the predicate is unenforced: ok

  $ cd /
  $ rm -rf "$tmp"
