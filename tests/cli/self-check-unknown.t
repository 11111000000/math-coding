mathc self-check with no attestation store present (the loader
returns []) emits verdict "unknown" and exits 3. Per
constitution.md:59 ("unknown != pass") the unknown verdict MUST
be distinct from pass — collapsing unknown to exit 0 would be
the "unknown != pass" laundering the spec row explicitly
forbids. Every applicable obligation surfaces as a
MissingEvidence gap; the aggregate treats MissingEvidence as
non-blocking but non-pass per the AGENTS.md bootstrap-gate
expiry clause (the kernel can NOT certify the corpus when the
store is absent). Waivers are the one carve-out: a decision
whose obligations are all covered by a NAMED, unexpired waiver
reports `open-with-waiver` with no store present — a named
acceptance of an unmet obligation, not `pass`
(constitution.md Invariant 10) — so `all_unknown` is false WHEN
THE CORPUS CARRIES SUCH A WAIVER.

This corpus does not: the eight files under `decisions/waivers/`
name no gap, so they cover nothing (see
`decisions/exit-honesty-waivers-2026-10.yaml`, which revoked the
decision-wide form those files relied on). The two composition
facts in the JSON therefore move with the corpus — they were
`waived_subjects_present: true` and `all_unknown: false` while
the corpus carried decision-wide waivers, and they are the other
way round now that it does not. What this fixture exists for is
the verdict and the exit code, and those are asserted here.
Acceptance gate for obligation
mathc-self-check-dispatcher-shipped (unknown / infrastructure-error
case) in decisions/mathc-self-check-subcommand.yaml@2.

  $ cd "$DUNE_SOURCEROOT"
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" bash -c 'tmp=$(mktemp -d); MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_ATTESTATION_STORE="$tmp/does-not-exist" $INSIDE_DUNE/bin/mathc.exe self-check > /tmp/sc-unk.out; ec=$?; jq -c "del(.now) | {verdict, unknown_dominates: (([.subjects[] | select(.verdict == \"unknown\")] | length) > ([.subjects[] | select(.verdict != \"unknown\")] | length)), waived_subjects_present: ([.subjects[] | select(.verdict == \"open-with-waiver\")] | length > 0), all_unknown: ([.subjects[].verdict] | all(. == \"unknown\"))}" < /tmp/sc-unk.out; echo "exit=$ec"; rm -rf "$tmp"'
  {"verdict":"unknown","unknown_dominates":true,"waived_subjects_present":false,"all_unknown":true}
  exit=3
