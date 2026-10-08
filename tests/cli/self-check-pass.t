mathc self-check with a populated attestation store covering every
obligation in every loaded decision emits verdict "pass" and
exits 0. The fixture store at
tests/fixtures/self-check-pass/attestations is generated once
from the current decisions/*.yaml set (see fixture commit); every
(decision_id, obligation_id) pair has a matching pass
attestation. The dispatcher walks the full decisions directory
via Sys.readdir (no hardcoded file list) per ROADMAP P1. The
acceptance gate is the AGENTS.md §Bootstrap gate expiry clause
verbatim ("the released 3.0 kernel successfully checks this
repository and its conformance corpus"). Acceptance gate for
obligation mathc-self-check-dispatcher-shipped (positive case) in
decisions/mathc-self-check-subcommand.yaml@2.

  $ cd "$DUNE_SOURCEROOT"
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" MATH_CODING_ATTESTATION_STORE="$DUNE_SOURCEROOT/tests/fixtures/self-check-pass/attestations" mathc self-check | jq -c '{verdict, pass_count: ([.subjects[] | select(.verdict == "pass")] | length), fail_count: ([.subjects[] | select(.verdict == "fail")] | length), unknown_count: ([.subjects[] | select(.verdict == "unknown")] | length), subjects_len: (.subjects | length), kernel_digest_len: (.kernel_digest | length), repo_digest_len: (.repository_digest | length)}'
  {"verdict":"unknown","pass_count":31,"fail_count":0,"unknown_count":19,"subjects_len":50,"kernel_digest_len":64,"repo_digest_len":64}
