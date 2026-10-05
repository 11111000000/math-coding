mathc time-estimate reads bin/data/time-distribution.yaml via the
project-root anchor and prints a JSON forecast. This exercises the
documented success paths (single-file-edit at p80,
feature-add at p95 with two multipliers) and rejection paths
(unknown class, missing --class). Acceptance gate for obligation
cli-time-estimate in bootstrap/time-honesty.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc time-estimate --class single-file-edit --percentile p80
  {"applied_multipliers":[],"caveat":"declared distribution; SWE-bench-V 2025-Q4; update via Decision","class":"single-file-edit","count":1,"estimate_value":8,"percentile":80,"reference":"SWE-bench Verified (n=500, 2025-Q4)","scale":"minutes","source":"bin/data/time-distribution.yaml"}
  $ mathc time-estimate --class feature-add --count 3 --percentile p95 --multiplier per_artifact_over_first --multiplier test_required_with_runtime
  {"applied_multipliers":["per_artifact_over_first","test_required_with_runtime"],"caveat":"declared distribution; SWE-bench-V 2025-Q4; update via Decision","class":"feature-add","count":3,"estimate_value":168,"percentile":95,"reference":"SWE-bench Verified (n=500, 2025-Q4)","scale":"minutes","source":"bin/data/time-distribution.yaml"}
  $ mathc time-estimate --class bogus
  {"class":"bogus","code":"MC-CLASS-UNKNOWN","known_classes":"[\"bug-diagnosis\",\"docs-only\",\"feature-add\",\"kernel-change\",\"multi-file-edit\",\"refactor\",\"schema-change\",\"single-file-edit\",\"trivial\"]","message":"unknown class; known: [\"bug-diagnosis\",\"docs-only\",\"feature-add\",\"kernel-change\",\"multi-file-edit\",\"refactor\",\"schema-change\",\"single-file-edit\",\"trivial\"]"}
  [2]
  $ mathc time-estimate
  mathc time-estimate: --class is required
  [2]
