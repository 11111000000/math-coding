mathc self-check with a populated attestation store that does not
yet cover the whole corpus emits verdict "unknown" and exits 3.
The fixture store at tests/fixtures/gate-pass/attestations holds ten
hand-written pass attestations, covering the obligations of two
decisions in full; every covered subject reports pass, the rest
report unknown, and the aggregate refuses to certify the uncovered
remainder. It is the same store tests/cli/gate-pass.t gates
against, so the positive control of the dispatcher costs ten files.

The store it replaces (tests/fixtures/self-check-pass/, 887 files)
was a hand-synchronised MIRROR of the live corpus: a second copy
that had to be regenerated whenever the corpus moved, and that was
measured on 2026-10-27 to be 91 required (decision, obligation)
pairs short of the enumeration `mathc packages --format=json`
produces, so its own coverage checker exited 1. A property that ten
files prove does not need a mirror of the corpus to be proven; see
decisions/corpus-meta-layer-2026-10.yaml.

The verdict vocabulary has four values, not three: a subject whose
gaps are accepted by a waiver reports `open-with-waiver`, which is
neither `pass` nor `unknown` (constitution.md Invariant 10; see
`decisions/self-check-waiver-verdict-coherence-2026-10.yaml`).
`all_subjects_classified` therefore enumerates all four, and
would go false if a fifth verdict string ever appeared. The dispatcher walks
the full decisions directory via Sys.readdir (no hardcoded file
list) per ROADMAP P1, so the subject count moves with
`decisions/*.yaml` — this fixture asserts the invariants, not a
count. Acceptance gate for obligation mathc-self-check-dispatcher-shipped
(positive case) in decisions/mathc-self-check-subcommand.yaml@2.

  $ cd "$DUNE_SOURCEROOT"
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_ATTESTATION_STORE="$DUNE_SOURCEROOT/tests/fixtures/gate-pass/attestations" bash -c 'mathc self-check > /tmp/sc-pass.out; ec=$?; jq -c "del(.now) | {verdict, store_read: ([.subjects[] | select(.verdict == \"pass\")] | length > 0), uncovered_unknown: ([.subjects[] | select(.verdict == \"unknown\")] | length > 0), fail_count: ([.subjects[] | select(.verdict == \"fail\")] | length), all_subjects_classified: (([.subjects[].verdict] | map(select(. == \"pass\" or . == \"fail\" or . == \"unknown\" or . == \"open-with-waiver\")) | length) == (.subjects | length)), kernel_digest_len: (.kernel_digest | length), repo_digest_len: (.repository_digest | length)}" < /tmp/sc-pass.out; echo "exit=$ec"'
  {"verdict":"unknown","store_read":true,"uncovered_unknown":true,"fail_count":0,"all_subjects_classified":true,"kernel_digest_len":64,"repo_digest_len":64}
  exit=3
