mc rebuttals walks rebuttals/<sha>.yaml for a given commit
prefix per algebra 3.2 §10 (lib/rebuttal.ml). Exercises the
success path on the bootstrap-expiry commit 8fa7fcf (no
rebuttals in this revision, so the array is empty). The
rejection path (missing argument) prints usage to stderr and
exits 2; the test focuses on the positive case so the output
snapshot is stable.

Acceptance gate for obligation rebuttals-subcommand-spec-row
in decisions/3-2-cli-catalog.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc rebuttals 8fa7fcf
  {"commit_sha":"8fa7fcf","rebuttals":[],"stats":{"accepted":0,"ignored_non_binding":0,"never_resolved":0,"pending":0,"rejected_with_reason":0,"total":0}}
