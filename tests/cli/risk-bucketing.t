Risk bucketing (algebra 3.2 §2) is now declared explicitly in the
spec via `risk_to_mode : [0, 1] → 𝓜` with five thresholds
(0.05 / 0.20 / 0.60 / 0.90 / 1.0). This cram fixture pins both the
spec text (the contract) and the kernel implementation in
`lib/risk.ml:183-188` (the realisation) so a future threshold
shift in either side shows up as a cram failure.

Acceptance gate for obligation `t0-1-spec-notation` of the
meta-decision `decisions/plan-2026-10-improvements@1` and the
sub-decision `decisions/plan-2026-10-improvements/t0-1.yaml@1`.

The spec declares the bucketed function in §2 and the spec uses the
new notation in `mode(c)`:

  $ cd "$DUNE_SOURCEROOT"

  $ grep -qF 'risk_to_mode : [0, 1] → 𝓜' spec/algebra-3.2.md

  $ grep -qF 'mode(c) = max(risk_to_mode(risk(c)), mode_floor(c))' spec/algebra-3.2.md

The five threshold lines appear in §2, in order, with the exact
text:

  $ grep -nE 'tiny.*0\.05|light.*0\.20|standard.*0\.60|strict.*0\.90|exhaustive.*0\.90' spec/algebra-3.2.md
  112:    | tiny        if r < 0.05
  113:    | light       if 0.05 ≤ r < 0.20
  114:    | standard    if 0.20 ≤ r < 0.60
  115:    | strict      if 0.60 ≤ r < 0.90
  116:    | exhaustive  if r ≥ 0.90

The ambiguous ceiling notation `⌈risk(c)⌉` is gone from the spec:

  $ ! grep -qF '⌈risk(c)⌉' spec/algebra-3.2.md

The spec still references the prior notation-flag decision (which
closes out as `superseded` once the human maintainer retires it):

  $ grep -qF 'algebra-3.2-notation-flag-2026-10' spec/algebra-3.2.md

The kernel implementation, unchanged in this branch, carries the
same five thresholds in the same open-vs-closed-boundary order:

  $ awk 'NR>=183 && NR<=188' lib/risk.ml
  let risk_to_mode (r : float) : Domain.mode =
    if r < 0.05 then `Tiny
    else if r < 0.20 then `Light
    else if r < 0.60 then `Standard
    else if r < 0.90 then `Strict
    else `Exhaustive

The `mathc mode` subcommand exercises the kernel end-to-end. Path
`lib/packages.ml` classifies at 0.5 with the default policy giving
mode_floor = standard, so the effective mode is `standard` (the
floor), not the bucketed bucket of risk = 0.025 (which would be
`tiny`). The exercise confirms the spec text `mode(c) =
max(risk_to_mode(risk(c)), mode_floor(c))` is honoured by the
kernel:

  $ mathc mode lib/packages.ml
  {"impact":"0.5","irreversibility":"0.1","mode":"standard","paths":[{"classify":"0.5","path":"lib/packages.ml"}],"probability":"0.5","risk":"0.025"}

The sub-decision file is present and is accepted by the validator:

  $ test -f decisions/plan-2026-10-improvements/t0-1.yaml && echo "decision present"
  decision present

  $ mathc validate decisions/plan-2026-10-improvements/t0-1.yaml | head -1
  accept: decisions/plan-2026-10-improvements/t0-1.yaml
