mathc gate and the EMPTY DIFF: three answers that used to be one.

The gate used to answer `pass` whenever the change set was empty,
because the base verdict was short-circuited on `changed_paths = []`
(lib/gate.ml:955-958, before `Gate.change_set`). An empty change set
is TWO facts, and the gate could not tell them apart:

1. "the two trees are the same" -- the change's question has nothing
to ask, and the scoped gate's answer is `pass`;
2. "git could not tell me what changed" -- the gate's own input is
missing, and the answer is `unknown`, with the reason in the gap list.

And a THIRD case fell into the same short-circuit without being an
empty diff at all: the AUDIT question (`--no-scope`), where the
question is "is the whole corpus still sound?". That question is
answered by the corpus's gaps, and on this repository the corpus has
hundreds of unmet obligations, so the honest answer is `unknown` -- not
`pass`.

MEASURED on this repository, before the change (2026-10-31):

mathc gate --no-scope --no-execute HEAD HEAD
{"verdict":"pass","obligations":468,"gaps_total":468,
 "gaps_by_kind":{"MissingEvidence":468}, ...}
exit 0

A green gate whose own document listed 468 reasons why it could not
conclude. The same tree one commit earlier, with a NON-empty diff,
answered `unknown` with the same 468 gaps: the only difference was
whether git had anything to report.

The obligation and gap counts move with the live decision set, so the
projections below assert INVARIANTS rather than counts.

MATH_CODING_DECISIONS_DIR is pinned to the repo's own `decisions/`
because this fixture runs from a temp git repo outside the project
root and `Path_config.resolve_with` probes its candidates relative to
the process cwd, not to MATH_CODING_ROOT. Without the pin the loader
finds no decisions at all and the gate reports `obligations: 0` /
verdict `pass` -- which is exactly the lie this fixture exists to
forbid.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ export tmp
  $ cd "$tmp"
  $ git init -q
  $ git config user.email "t@t"
  $ git config user.name "t"
  $ echo a > a.txt
  $ git add . && git commit -q -m initial
  $ echo b > b.txt
  $ git add . && git commit -q -m second

The AUDIT question with an EMPTY diff (base = head, so nothing
changed): every active decision is evaluated, the corpus has gaps, and
the verdict is computed FROM THE GAPS. Before the change this was
`pass` with exit 0 -- the green gate above.

  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_DECISIONS_DIR="decisions" MATH_CODING_POLICY="policies.yaml" MATH_CODING_ATTESTATION_STORE="$tmp/no-store" bash -c '$INSIDE_DUNE/bin/mathc.exe gate --no-scope --no-execute HEAD HEAD > "$tmp/audit.json" 2> "$tmp/audit.err"; ec=$?; jq -c "{verdict, gaps_positive: (.gaps_total > 0), gaps_match_obligations: (.gaps_total == .obligations)}" < "$tmp/audit.json"; echo "exit=$ec"'
  {"verdict":"unknown","gaps_positive":true,"gaps_match_obligations":true}
  exit=3

The CHANGE question with an EMPTY diff: nothing changed, so no
decision is touched, so there are no obligations and no gaps, and the
verdict is `pass`. This is the branch that must NOT have become
`unknown`: "nothing changed" is a fact, and the gate should say so.

  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_DECISIONS_DIR="decisions" MATH_CODING_POLICY="policies.yaml" MATH_CODING_ATTESTATION_STORE="$tmp/no-store" bash -c '$INSIDE_DUNE/bin/mathc.exe gate --scope --no-execute HEAD HEAD > "$tmp/scoped.json" 2> "$tmp/scoped.err"; ec=$?; jq -c "{verdict, obligations, gaps_total}" < "$tmp/scoped.json"; echo "exit=$ec"'
  {"verdict":"pass","obligations":0,"gaps_total":0}
  exit=0

THE THIRD BRANCH: the diff could not be READ. The two trees are the
same commit, but git cannot produce the diff: the tree object the
commit names is gone from the object store. `git rev-parse --verify
HEAD^{commit}` still succeeds (the COMMIT object is intact), so the
gate's ref check passes and the gate is asked its question -- and the
question cannot be answered.

This is not a synthetic failure mode: a repository with a damaged
object store is a repository whose diff cannot be read, and the old
code read that as "nothing changed" and answered `pass`. The verdict
is now `unknown`, and the REASON is in the gap list: a gap of its
own, whose cause names the unreadable diff.

  $ tree=$(git rev-parse HEAD^{tree})
  $ rm -f ".git/objects/${tree:0:2}/${tree:2}"
  $ git rev-parse --verify --quiet 'HEAD^{commit}' > /dev/null && echo "the commit object still resolves"
  the commit object still resolves
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_DECISIONS_DIR="decisions" MATH_CODING_POLICY="policies.yaml" MATH_CODING_ATTESTATION_STORE="$tmp/no-store" bash -c '$INSIDE_DUNE/bin/mathc.exe gate --scope --no-execute HEAD HEAD > "$tmp/unreadable.json" 2> "$tmp/unreadable.err"; ec=$?; jq -c "{verdict, gaps_total, kind: .gaps[0].kind, cause_names_the_diff: (.gaps[0].causes[0] | test(\"could not be read\"))}" < "$tmp/unreadable.json"; echo "exit=$ec"'
  {"verdict":"unknown","gaps_total":1,"kind":"Unknown","cause_names_the_diff":true}
  exit=3

The reason is a REASON, not a verdict string: the gap carries the
cause, so a reader of the document can tell "the corpus is unproven"
from "the gate could not read its own input".

  $ jq -r '.gaps[0].obligation_id' < "$tmp/unreadable.json"
  change-scope
  $ cd /
  $ rm -rf "$tmp"
