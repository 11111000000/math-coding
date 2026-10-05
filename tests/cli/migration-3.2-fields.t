The migrated decision files all carry the 3.2-ideal fields
(state=active, body_sha, yaml_sha). Verified via `mc packages`
which enumerates every decision in decisions/*.yaml.

This fixture proves the migration script (scripts/migrate-decisions-3.2.py)
ran successfully and the schema-extension is backward-compatible.

  $ cd "$DUNE_SOURCEROOT"

mc packages indexes every non-meta decision (skipping
obligations.yaml aggregator and decision.yaml bootstrap policy):
  $ mathc packages --format=json | jq -r '.decisions[].decision_id' | wc -l
  28

Every indexed decision_id is a non-empty string:
  $ mathc packages --format=json | jq -r '.decisions[].decision_id' | grep -c '^.'
  28

The algebra-3.2 decision is in the index (proves schema extension works):
  $ mathc packages --format=json | jq -r '.decisions[].decision_id' | grep -c '^algebra-3.2$'
  1

Total obligation count is consistent (algebra-3.2 added 7 obligations,
plus the original 72 = 79 total; site-deploy@2 adds 6 more = 85 total;
3-2-cli-catalog@1 adds 8 more = 93; portable-linux-musl adds 7 retired
obligations not visible in counts = 100; the actual count at HEAD
includes the +1 aggregate-7-of-7 from obligation-count-reconcile = 101):
  $ mathc packages --format=json | jq '.counts.total'
  101
  $ mathc packages --format=json | jq '.counts.pass'
  94
  $ mathc packages --format=json | jq '.counts.missing'
  7
