mathc gate BASE HEAD with no attestation store present (the loader
returns []) emits verdict "unknown". Every applicable obligation
surfaces as a MissingEvidence gap; the aggregate treats
MissingEvidence as informational (not blocking) per the
gate-attestation-store-fill commitment ("block if any obligation
fails, unknown otherwise"). `mathc gate` maps unknown to exit 3
per constitution.md Invariants 14/14b; gate-unknown-exit-3.t
asserts that mapping end-to-end. Acceptance gate for obligation
gate-fixtures-coverage in bootstrap/gate-attestation-store-fill-decision.yaml.

MATH_CODING_DECISIONS_DIR is pinned to the repo's own `decisions/`
because this fixture runs from a temp git repo outside the project
root and `Path_config.resolve_with` probes its candidates relative
to the process cwd, not to MATH_CODING_ROOT. Without the pin the
loader finds no decisions at all and the gate reports
`obligations: 0` / verdict `pass`. The obligation and gap counts
move with the live decision set, so the projection asserts
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
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_DECISIONS_DIR="decisions" MATH_CODING_ATTESTATION_STORE="$tmp/does-not-exist" mathc gate --no-scope --no-execute HEAD~1 HEAD | jq -c 'del(.now) | {verdict, all_missing: (.gaps | length > 0 and all(.kind == "MissingEvidence")), every_obligation_is_a_gap: ((.gaps | length) == .obligations), obligations_positive: (.obligations > 0)}'
  {"verdict":"unknown","all_missing":true,"every_obligation_is_a_gap":true,"obligations_positive":true}
  $ cd /
  $ rm -rf "$tmp"
