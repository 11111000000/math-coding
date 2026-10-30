Risk bucketing (algebra 3.2 §2) is now declared explicitly in the
spec via `risk_to_mode : [0, 1] → 𝓜` with five thresholds
(0.05 / 0.20 / 0.60 / 0.90 / 1.0). This cram fixture pins both the
spec text (the contract) and the kernel implementation in
`lib/risk.ml:183-188` (the realisation) so a future threshold
shift in either side shows up as a cram failure.

Acceptance gate for obligation `t0-1-spec-notation` of the
meta-decision `decisions/plan-2026-10-improvements@1` and the
sub-decision `docs/plans/t0-1.yaml@1`.

The spec declares the bucketed function in §2 and the spec uses the
new notation in `mode(c)`:

  $ cd "$DUNE_SOURCEROOT"

  $ grep -qF 'risk_to_mode : [0, 1] → 𝓜' "$DUNE_SOURCEROOT/spec/algebra-3.2.md"

  $ grep -qF 'mode(c) = max(risk_to_mode(risk(c)), mode_floor(c))' "$DUNE_SOURCEROOT/spec/algebra-3.2.md"

The five threshold lines appear in §2, in order, with the exact
text. We extract the bucket name from each line so the assertion
survives comment-block insertions that shift line numbers:

  $ grep -nE 'tiny.*0\.05|light.*0\.20|standard.*0\.60|strict.*0\.90|exhaustive.*0\.90' "$DUNE_SOURCEROOT/spec/algebra-3.2.md" | awk -F'|' '{print $2}' | awk '{print $1}'
  tiny
  light
  standard
  strict
  exhaustive

The ambiguous ceiling notation `⌈risk(c)⌉` is gone from the spec:

  $ ! grep -qF '⌈risk(c)⌉' "$DUNE_SOURCEROOT/spec/algebra-3.2.md"

The spec still references the prior notation-flag decision (which
closes out as `superseded` once the human maintainer retires it):

  $ grep -qF 'algebra-3.2-notation-flag-2026-10' "$DUNE_SOURCEROOT/spec/algebra-3.2.md"

The kernel implementation carries the same five thresholds in the
same open-vs-closed-boundary order. We pin the body of
`let risk_to_mode` from the source (the function body is five
`if` lines followed by the final `else \`Exhaustive`; surrounding
comment blocks may move, but the bucket body is stable):

  $ sed -n '/^let risk_to_mode/,/^\s*else `Exhaustive/p' lib/risk.ml
  let risk_to_mode (r : float) : Domain.mode =
    if r < 0.05 then `Tiny
    else if r < 0.20 then `Light
    else if r < 0.60 then `Standard
    else if r < 0.90 then `Strict
    else `Exhaustive

The `mathc mode` subcommand exercises the kernel end-to-end. Path
`lib/packages.ml` classifies at risk = 0.025, which is `tiny` on its
own under the 0.05 boundary. The EFFECTIVE mode is the floor:
`max(risk_to_mode(risk(c)), mode_floor(c))`, and `policies.yaml`
floors `lib/**` at `standard`. The floor was dead until 2026-10-30
-- the resolver named a decision document instead of the policy
file, so every path read as `tiny` -- and this snapshot recorded the
dead behaviour. See `decisions/record-proportionality-2026-10`:

  $ $INSIDE_DUNE/bin/mathc.exe mode lib/packages.ml
  {"impact":"0.5","irreversibility":"0.1","mode":"standard","paths":[{"classify":"0.5","path":"lib/packages.ml"}],"probability":"0.5","risk":"0.025"}

The sub-decision file is present and is accepted by the validator.
New verifier-scheme warnings emitted under the
`verifier-scheme-convention-2026-11` policy render before the
verdict line; the verdict-line first match captures the canonical
verdict (`accept` was renamed to `parse-ok` in commit a602b361):

  $ $INSIDE_DUNE/bin/mathc.exe validate docs/plans/t0-1.yaml 2>/dev/null | grep -E '^(parse-ok|accept):'
  parse-ok: docs/plans/t0-1.yaml
