The risk buckets are the kernel's own constants, and they live in the
code: `lib/risk.ml::risk_to_mode`. The thresholds are read from there,
and the kernel is then exercised at one risk per bucket, so a threshold
that moves without the kernel's answer moving fails in this file.

WHAT IS NOT PINNED HERE, AND WHY. This fixture used to read the five
thresholds out of `spec/kernel-contract.md` and compare them with the
code. That mirror is what the contract's shrink removes: a fixture
that greps the prose breaks the moment the prose is rewritten, and the
prose is rewritten now. The document is the INDEX -- it says where the
rule lives (`lib/risk.ml::risk_to_mode`) and which test would notice if
it stopped (this file); the NUMBERS are the code's, and this file
compares them with the code, never with a line of prose.

Acceptance gate for obligation `t0-1-spec-notation` of the
meta-decision `decisions/plan-2026-10-improvements@1` and the
sub-decision `docs/plans/t0-1.yaml@1`.

  $ cd "$DUNE_SOURCEROOT"

The kernel implementation carries the same five buckets in the
open-vs-closed-boundary order. We pin the body of `let risk_to_mode`
from the source (the function body is five `if` lines followed by the
final `else `Exhaustive`; surrounding comment blocks may move, but the
bucket body is stable):

  $ sed -n '/^let risk_to_mode/,/^\s*else `Exhaustive/p' lib/risk.ml
  let risk_to_mode (r : float) : Domain.mode =
    if r < 0.05 then `Tiny
    else if r < 0.20 then `Light
    else if r < 0.60 then `Standard
    else if r < 0.90 then `Strict
    else `Exhaustive

The four thresholds, read from the code that owns them. The extraction
is the check: a body that stops carrying four boundaries produces no
thresholds here, and the fixture fails rather than passes vacuously.

  $ sed -n '/^let risk_to_mode/,/^\s*else `Exhaustive/p' lib/risk.ml | grep -oE 'r < [0-9.]+' | grep -oE '[0-9.]+'
  0.05
  0.20
  0.60
  0.90

THE KERNEL'S OWN ANSWER, ONE PATH PER BUCKET. A temporary policy sets
the probability override to 1.0 and the floor to `tiny`, so the printed
mode is the bucket and nothing else. The paths carry the two segment
markers the kernel knows (`data-mig`, `schema-break`), which is how a
risk above 0.05 is reached at all: the maximum risk this repository
can produce without a marker is 0.0475.

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ touch dune-project
  $ cat > policies.yaml <<'YAML'
  > - policy_id: bucket-fixture
  >   scope_paths:
  >     - "docs/**"
  >     - "axioms/**"
  >     - "lib/**"
  >   mode_floor: tiny
  >   override_probability: 1.0
  >   obligations: []
  >   transitive_into: []
  >   data_flow_edges: []
  > YAML
  $ $INSIDE_DUNE/bin/mathc.exe mode docs/x.md | jq -c '{risk, mode}'
  {"risk":"0.005","mode":"tiny"}
  $ $INSIDE_DUNE/bin/mathc.exe mode axioms/x.md | jq -c '{risk, mode}'
  {"risk":"0.095","mode":"light"}
  $ $INSIDE_DUNE/bin/mathc.exe mode lib/core/data-mig/x.ml | jq -c '{risk, mode}'
  {"risk":"0.35","mode":"standard"}
  $ $INSIDE_DUNE/bin/mathc.exe mode axioms/data-mig/x.md | jq -c '{risk, mode}'
  {"risk":"0.665","mode":"strict"}
  $ $INSIDE_DUNE/bin/mathc.exe mode axioms/schema-break/x.md | jq -c '{risk, mode}'
  {"risk":"0.9025","mode":"exhaustive"}
  $ cd "$DUNE_SOURCEROOT"
  $ rm -rf "$tmp"

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
