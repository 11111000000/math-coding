mathc mode computes the risk classification for one or more paths
per algebra 3.2 §2 (lib/risk.ml). Exercises the success path
with a kernel path (lib/packages.ml) and a docs path
(README.md). The rejection path (no positional paths) prints
usage to stderr and exits 2; the test focuses on the
positive case so the output snapshot is stable.

Acceptance gate for obligation mode-subcommand-spec-row in
decisions/3-2-cli-catalog.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc mode lib/packages.ml README.md
  {"impact":"0.5","irreversibility":"0.1","mode":"standard","paths":[{"classify":"0.5","path":"lib/packages.ml"},{"classify":"0.5","path":"README.md"}],"probability":"0.5","risk":"0.025"}
