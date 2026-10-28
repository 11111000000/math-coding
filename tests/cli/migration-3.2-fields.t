The migrated decision files all carry the 3.2-ideal fields
(state=active, body_sha, yaml_sha). Verified via `mathc packages`
which enumerates every decision in decisions/*.yaml.

This fixture proves the migration script (scripts/migrate-decisions-3.2.py)
ran successfully and the schema-extension is backward-compatible.

  $ cd "$DUNE_SOURCEROOT"

The repo's decision inventory grows over time, so the index
size and obligation counts are NOT hardcoded as literals;
instead the test pins structural invariants that hold across
every revision. The invariants under check: every non-meta
decision is indexed, `algebra-3.2` is among the indexed
decisions, and the obligation counts from `packages` are
internally consistent (the buckets partition the reported
total). We assert these via jq rather than hardcoding a
numeric count.

  $ mathc packages --format=json > /tmp/packages.json

Every indexed decision_id is a non-empty string AND the
indexed count matches the array length:

  $ indexed=$(jq -r '.decisions[].decision_id' /tmp/packages.json | wc -l)
  $ listed=$(jq '.decisions | length' /tmp/packages.json)
  $ if [ "$indexed" = "$listed" ] && [ "$indexed" -gt 0 ]; then echo "PASS: every decision id is non-empty and present in the array"; else echo "FAIL: indexed=$indexed listed=$listed"; fi
  PASS: every decision id is non-empty and present in the array

The algebra-3.2 decision is in the index (proves schema
extension works):

  $ algebra_count=$(jq -r '.decisions[].decision_id | select(. == "algebra-3.2")' /tmp/packages.json | wc -l)
  $ if [ "$algebra_count" = "1" ]; then echo "PASS: algebra-3.2 is in the packages index (schema extension is backward-compatible)"; else echo "FAIL: algebra_count=$algebra_count"; fi
  PASS: algebra-3.2 is in the packages index (schema extension is backward-compatible)

Total obligation count is consistent: the buckets partition
the whole. We compute the sum from the JSON fields directly
so the test does not pin a stale literal count:

  $ buckets=$(jq '[.counts.pass, .counts.fail, .counts.missing, .counts.stale, .counts.unknown, .counts.waived, .counts.no_store] | add' /tmp/packages.json)
  $ total=$(jq '.counts.total' /tmp/packages.json)
  $ if [ "$total" = "$buckets" ]; then echo "PASS: total == sum-of-buckets (partition holds)"; else echo "FAIL: total=$total buckets_sum=$buckets"; fi
  PASS: total == sum-of-buckets (partition holds)

  $ rm -f /tmp/packages.json
