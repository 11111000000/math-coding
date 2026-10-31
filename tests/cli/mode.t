mathc mode computes the risk classification for one or more paths
per kernel contract §2 (lib/risk.ml). Exercises the success path
with a kernel path (lib/packages.ml) and a docs path
(README.md).

THE MODE IS THE FLOOR, NOT ONLY THE RISK. The risk of
lib/packages.ml is 0.025, which is `tiny` on its own. The
effective mode is `max(risk_to_mode(risk(c)), mode_floor(c))`,
and `policies.yaml` floors `lib/**` at `standard`: a kernel change
carries a commitment, so it costs a decision or a citation. The
floor was dead until 2026-10-30 (the resolver named a decision
document instead of the policy file), and this snapshot recorded
the dead behaviour. See `decisions/record-proportionality-2026-10`. The rejection path (no positional paths) prints
usage to stderr and exits 2; the test focuses on the
positive case so the output snapshot is stable.

Acceptance gate for obligation mode-subcommand-spec-row in
decisions/3-2-cli-catalog.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ $INSIDE_DUNE/bin/mathc.exe mode lib/packages.ml README.md
  {"impact":"0.5","irreversibility":"0.1","mode":"standard","paths":[{"classify":"0.5","path":"lib/packages.ml"},{"classify":"0.5","path":"README.md"}],"probability":"0.5","risk":"0.025"}
