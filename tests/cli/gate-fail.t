mathc gate BASE HEAD with an attestation store whose entries include
a decisive fail attestation for one obligation emits verdict
"block" and exits 1 (constitution.md Invariant 14 — exit honesty).
The remaining obligations either pass or surface as
MissingEvidence; the aggregate ignores MissingEvidence and treats
only FailedEvidence as the blocking signal per the
gate-attestation-store-fill commitment. Acceptance gate for
obligation gate-real-verdict (negative case) and
gate-exit-honest in bootstrap/gate-attestation-store-fill-decision.yaml.

MATH_CODING_DECISIONS_DIR is pinned to the repo's own `decisions/`
because this fixture runs from a temp git repo outside the project
root and `Path_config.resolve_with` probes its candidates relative
to the process cwd, not to MATH_CODING_ROOT. Without the pin the
loader finds no decisions, so no obligation can fail and the gate
would report verdict `pass` with exit 0. The obligation count
moves with the live decision set, so the projection asserts
invariants rather than counts.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ git init -q
  $ git config user.email "t@t"
  $ git config user.name "t"
  $ echo a > a.txt
  $ git add . && git commit -q -m initial
  $ echo b > b.txt
  $ git add . && git commit -q -m second
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_DECISIONS_DIR="decisions" MATH_CODING_ATTESTATION_STORE="$DUNE_SOURCEROOT/tests/fixtures/gate-fail/attestations" bash -c 'mathc gate HEAD~1 HEAD > /tmp/gate-fail.out; ec=$?; jq -c "del(.now) | {verdict, has_failed_gap: ([.gaps[].kind] | any(. == \"FailedEvidence\")), failed_obligation: ([.gaps[] | select(.kind == \"FailedEvidence\") | .obligation_id] | length == 1), others_are_missing: ([.gaps[] | select(.kind != \"FailedEvidence\") | .kind] | all(. == \"MissingEvidence\")), obligations_positive: (.obligations > 0)}" < /tmp/gate-fail.out; echo "exit=$ec"'
  {"verdict":"block","has_failed_gap":true,"failed_obligation":true,"others_are_missing":true,"obligations_positive":true}
  exit=1
  $ cd /
  $ rm -rf "$tmp"
