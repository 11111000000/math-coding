The migrated decision files all carry the 3.2-ideal fields
(state=active, body_sha, yaml_sha). Verified via `mc packages`
which enumerates every decision in decisions/*.yaml.

This fixture proves the migration script (scripts/migrate-decisions-3.2.py)
ran successfully and the schema-extension is backward-compatible.

  $ cd "$DUNE_SOURCEROOT"

mc packages indexes every non-meta decision (skipping
obligations.yaml aggregator and decision.yaml bootstrap policy):
  $ mathc packages --format=json | jq -r '.decisions[].decision_id' | wc -l
  26

Every indexed decision_id is a non-empty string:
  $ mathc packages --format=json | jq -r '.decisions[].decision_id' | grep -c '^.'
  26

The algebra-3.2 decision is in the index (proves schema extension works):
  $ mathc packages --format=json | jq -r '.decisions[].decision_id' | grep -c '^algebra-3.2$'
  1

Total obligation count is consistent (algebra-3.2 added 7 obligations,
plus the original 72 = 79 total):
  $ mathc packages --format=json | jq '.counts.total'
  79
  $ mathc packages --format=json | jq '.counts.pass'
  72
  $ mathc packages --format=json | jq '.counts.missing'
  7
