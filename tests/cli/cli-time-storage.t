mc session-start writes a deterministic ISO 8601 UTC anchor;
mc record rejects --value for --scale wall-clock-minutes, requires
--value for --scale step-count, and emits MC-SESSION-MISSING
without prior session-start; mc stats emits aggregate JSON.
Acceptance gates for cli-session-start, cli-record, cli-stats in
bootstrap/time-honesty-storage.yaml.

The test cleans state at start and end so it can run multiple
times without pollution. MATH_CODING_FIXED_TIME pins session-start
to a deterministic value; recorded_at and observed_by in record
output are not currently scrubbed (could use jq if format drifts).

  $ cd "$DUNE_SOURCEROOT"
  $ rm -f .local/session-start bootstrap/execution-logs.jsonl
  $ MATH_CODING_FIXED_TIME=2026-09-27T07:07:17Z MATH_CODING_USER=human:test@local mathc session-start
  "2026-09-27T07:07:17Z"
  $ mathc record --decision-id bootstrap-v3 --scale wall-clock-minutes --value 5
  mc record: --value rejected for --scale wall-clock-minutes
  [2]
  $ rm -f .local/session-start
  $ mathc record --decision-id bootstrap-v3 --scale wall-clock-minutes --class feature-add
  mc record: MC-SESSION-MISSING; run 'mc session-start' first
  [2]
  $ mathc record --decision-id bootstrap-v3 --scale step-count
  mc record: --value is required for --scale step-count
  [2]
  $ rm -f bootstrap/execution-logs.jsonl
  $ mathc stats | jq -c '{n, warning: (.warning // null)}'
  {"n":0,"warning":"insufficient samples (n=0 < 30); declared floor in bin/data/time-distribution.yaml still applies"}
  $ for i in $(seq 1 36); do mathc record --decision-id bootstrap-v3 --scale step-count --value $i >/dev/null 2>&1; done
  $ mathc stats --scale step-count | jq -c '{n, p50: .quantiles.p50, p99: .quantiles.p99}'
  {"n":36,"p50":19,"p99":36}
  $ rm -f .local/session-start bootstrap/execution-logs.jsonl
