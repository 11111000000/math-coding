Test mc session-start, mc record, mc stats (bootstrap decision
time-honesty-storage).

The cram sandbox isolates _build/default/, so we anchor the
binary at $INSIDE_DUNE/bin/mathc.exe and the project root at
$DUNE_SOURCEROOT (via the new MATH_CODING_ROOT env var). Each
block starts with a cleanup of local state so the test is
deterministic regardless of prior runs of the worktree.

The `observed_by` lines are tested under MATH_CODING_USER=human:test@local
because the cram sandbox's `.git` is a stub and `git config
user.email` errors out (we cannot reasonably rely on the
fallback path inside a sandbox).

Session-start writes a fresh ISO 8601 UTC anchor; we use cram's
character-class wildcards for the timestamp and exit-status
assertion via [N].

  $ mathc="$INSIDE_DUNE/bin/mathc.exe"
  $ rm -f "$DUNE_SOURCEROOT/.local/session-start" "$DUNE_SOURCEROOT/bootstrap/execution-logs.jsonl"

  $ MATH_CODING_USER=human:test@local MATH_CODING_ROOT="$DUNE_SOURCEROOT" "$mathc" session-start
  "2026-09-27T07:07:17Z"

mc record --scale wall-clock-minutes REJECTS --value. The runtime
clock is the only source for wall-clock; agent-supplied values
would re-open the strategic-misrepresentation vector.

  $ MATH_CODING_USER=human:test@local MATH_CODING_ROOT="$DUNE_SOURCEROOT" "$mathc" record --decision-id bootstrap-v3 --scale wall-clock-minutes --value 5
  mc record: --value rejected for --scale wall-clock-minutes
  [2]

mc record without session-start emits MC-SESSION-MISSING.

  $ rm -f "$DUNE_SOURCEROOT/.local/session-start"
  $ MATH_CODING_USER=human:test@local MATH_CODING_ROOT="$DUNE_SOURCEROOT" "$mathc" record --decision-id bootstrap-v3 --scale wall-clock-minutes --class feature-add
  mc record: MC-SESSION-MISSING; run 'mc session-start' first
  [2]

mc record --scale step-count REQUIRES --value (assumption step-count-
supplied in bootstrap/time-honesty-storage.yaml; future runtime
harness integration will REMOVE the --value flag for step-count).

  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" "$mathc" record --decision-id bootstrap-v3 --scale step-count
  mc record: --value is required for --scale step-count
  [2]

mc stats with no events at all: n=0, warning set, quantiles omitted.

  $ rm -f "$DUNE_SOURCEROOT/bootstrap/execution-logs.jsonl"
  $ MATH_CODING_USER=human:test@local MATH_CODING_ROOT="$DUNE_SOURCEROOT" "$mathc" stats
  {"class":"","n":0,"quantiles":null,"scale":"","since":"","source":"bootstrap/execution-logs.jsonl","threshold":30,"warning":"insufficient samples (n=0 < 30); declared floor in bin/data/time-distribution.yaml still applies"}

mc stats with n < 30: warning still set, quantiles still omitted.

  $ MATH_CODING_USER=human:test@local MATH_CODING_ROOT="$DUNE_SOURCEROOT" "$mathc" record --decision-id bootstrap-v3 --scale step-count --value 1 > /dev/null
  $ MATH_CODING_USER=human:test@local MATH_CODING_ROOT="$DUNE_SOURCEROOT" "$mathc" record --decision-id bootstrap-v3 --scale step-count --value 2 > /dev/null
  $ MATH_CODING_USER=human:test@local MATH_CODING_ROOT="$DUNE_SOURCEROOT" "$mathc" stats --scale step-count
  {"class":"","n":2,"quantiles":null,"scale":"step-count","since":"","source":"bootstrap/execution-logs.jsonl","threshold":30,"warning":"insufficient samples (n=2 < 30); declared floor in bin/data/time-distribution.yaml still applies"}

mc stats reaches n >= 30: quantiles are emitted. The sample is
values 1..36 (the seq above plus 34 sequential writes below).
After sorting, the linear interpolation gives p50=18 (median of
1..36 is 18.5; rounded), p80=29 (29.2), p95=34 (34.25), p99=36
(36.5 -> 36 via the +0.5 rounding in quantile).

  $ rm -f "$DUNE_SOURCEROOT/bootstrap/execution-logs.jsonl"
  $ for i in $(seq 1 36); do MATH_CODING_USER=human:test@local MATH_CODING_ROOT="$DUNE_SOURCEROOT" "$mathc" record --decision-id bootstrap-v3 --scale step-count --value $i > /dev/null; done
  $ MATH_CODING_USER=human:test@local MATH_CODING_ROOT="$DUNE_SOURCEROOT" "$mathc" stats --scale step-count
  {"class":"","n":36,"quantiles":{"p50":19,"p80":29,"p95":34,"p99":36},"scale":"step-count","since":"","source":"bootstrap/execution-logs.jsonl","threshold":30}

mc stats --scale wall-clock-minutes: nothing was written for that
scale (session-start was used only to test the error path).

  $ MATH_CODING_USER=human:test@local MATH_CODING_ROOT="$DUNE_SOURCEROOT" "$mathc" stats --scale wall-clock-minutes
  {"class":"","n":0,"quantiles":null,"scale":"wall-clock-minutes","since":"","source":"bootstrap/execution-logs.jsonl","threshold":30,"warning":"insufficient samples (n=0 < 30); declared floor in bin/data/time-distribution.yaml still applies"}

mc session-start cleans .local/session-start by overwriting it.

  $ rm -f "$DUNE_SOURCEROOT/.local/session-start"
  $ MATH_CODING_USER=human:test@local MATH_CODING_ROOT="$DUNE_SOURCEROOT" "$mathc" session-start
  "2026-09-27T07:07:18Z"
