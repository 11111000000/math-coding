mc self-check with no attestation store present (the loader
returns []) emits verdict "unknown" and exits 3. Per
constitution.md:59 ("unknown != pass") the unknown verdict MUST
be distinct from pass — collapsing unknown to exit 0 would be
the "unknown != pass" laundering the spec row explicitly
forbids. Every applicable obligation surfaces as a
MissingEvidence gap; the aggregate treats MissingEvidence as
non-blocking but non-pass per the AGENTS.md bootstrap-gate
expiry clause (the kernel can NOT certify the corpus when the
store is absent). Acceptance gate for obligation
mc-self-check-dispatcher-shipped (unknown / infrastructure-error
case) in decisions/mc-self-check-subcommand.yaml@2.

  $ cd "$DUNE_SOURCEROOT"
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_ATTESTATION_STORE="$tmp/does-not-exist" bash -c 'tmp=$(mktemp -d); MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_ATTESTATION_STORE="$tmp/does-not-exist" mathc self-check > /tmp/sc-unk.out; ec=$?; jq -c "del(.now) | {verdict, unknown_count: ([.subjects[] | select(.verdict == \"unknown\")] | length), total_subjects: (.subjects | length), all_unknown: ([.subjects[].verdict] | all(. == \"unknown\"))}" < /tmp/sc-unk.out; echo "exit=$ec"; rm -rf "$tmp"'
  {"verdict":"unknown","unknown_count":23,"total_subjects":23,"all_unknown":true}
  exit=3
