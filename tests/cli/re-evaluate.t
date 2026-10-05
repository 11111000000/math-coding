mathc re-evaluate classifies a (DECISION_ID, AXIOM_ID) pair per
algebra 3.2 §17. Exercises the rejection paths. The success
path is currently blocked by a pre-existing parser bug
(`Decision.parse_decision` rejects every decision in the
repo, including the master policy); a positive fixture will
be added once that bug is fixed. This fixture documents the
rejection contract so the dispatcher cannot regress.

Acceptance gate for obligation re-evaluate-subcommand-spec-row
in decisions/3-2-cli-catalog.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc re-evaluate
  mathc re-evaluate: DECISION_ID and AXIOM_ID are required
  [2]
  $ mathc re-evaluate nonexistent A1
  mathc re-evaluate: unknown DECISION_ID nonexistent
  [2]
  $ mathc re-evaluate bootstrap-v3 BOGUS
  mathc re-evaluate: AXIOM_ID must be one of A0..A4 (got BOGUS)
  [2]
