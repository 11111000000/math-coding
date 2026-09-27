Test the mc time-estimate subcommand (bootstrap decision time-honesty).

The subcommand reads bin/data/time-distribution.yaml via the
project-root anchor and prints a JSON forecast. Exit 0 on
success; 2 on bad input. The test exercises the documented
success path, the multiplier path, and three rejection paths.

The cram sandbox isolates _build/default/bin/, so we anchor the
binary at $INSIDE_DUNE/bin/mathc.exe (see OCAML_BEST_PRACTICES
trap log §11.20). Cram asserts the exit code via a trailing
[N] marker after the expected output; running `echo $?`
separately would always report 0 because cram executes each
'$'-line in its own subshell.

Single-file-edit at P80 — interpolated between declared P50=3 and
P95=10. estimate_value = 3 + (10-3)*(30/45) round-to-int = 8.

  $ mathc="$INSIDE_DUNE/bin/mathc.exe"

  $ "$mathc" time-estimate --class single-file-edit --percentile p80
  {"applied_multipliers":[],"caveat":"declared distribution; SWE-bench-V 2025-Q4; update via Decision","class":"single-file-edit","count":1,"estimate_value":8,"percentile":80,"reference":"SWE-bench Verified (n=500, 2025-Q4)","scale":"minutes","source":"bin/data/time-distribution.yaml"}

Feature-add at P95 with two multipliers: per_artifact_over_first
at count=3 (declared factor_at_count_3_x10=20, i.e. 2.0) and
test_required_with_runtime (factor_x10=12, i.e. 1.2).
Declared P95 of feature-add = 70. estimate = 70 * 2.0 * 1.2 = 168.

  $ "$mathc" time-estimate --class feature-add --count 3 --percentile p95 --multiplier per_artifact_over_first --multiplier test_required_with_runtime
  {"applied_multipliers":["per_artifact_over_first","test_required_with_runtime"],"caveat":"declared distribution; SWE-bench-V 2025-Q4; update via Decision","class":"feature-add","count":3,"estimate_value":168,"percentile":95,"reference":"SWE-bench Verified (n=500, 2025-Q4)","scale":"minutes","source":"bin/data/time-distribution.yaml"}

Unknown class exits 2 with a JSON diagnostic.

  $ "$mathc" time-estimate --class bogus
  {"class":"bogus","code":"MC-CLASS-UNKNOWN","known_classes":"[\"bug-diagnosis\",\"docs-only\",\"feature-add\",\"kernel-change\",\"multi-file-edit\",\"refactor\",\"schema-change\",\"single-file-edit\",\"trivial\"]","message":"unknown class; known: [\"bug-diagnosis\",\"docs-only\",\"feature-add\",\"kernel-change\",\"multi-file-edit\",\"refactor\",\"schema-change\",\"single-file-edit\",\"trivial\"]"}
  [2]

Missing --class exits 2 with a textual diagnostic.

  $ "$mathc" time-estimate
  mc time-estimate: --class is required
  [2]
