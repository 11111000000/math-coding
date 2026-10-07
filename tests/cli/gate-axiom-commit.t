mathc gate BASE HEAD on a commit touching only `axioms/A0.md`
plus a sibling `decisions/*.yaml` (so the §20 kernel rule
`CoCommitDecision` and the `PreTemporalPrecedence` rule both
pass via `has_sibling_yaml`) and no rebuttal file surfaces
verdict "block" (not "unknown"). The risk classification for
`axioms/A0.md` is exhaustive per the `math-coding-axioms` policy
floor in `policies.yaml`; algebra §10 requires rebuttals for
non-Unblocked verdict at exhaustive mode. The v3.0 `evaluate`
path now consults `Risk.mode files` (T3.1) and promotes the
verdict to Block when `mode >= strict` and rebuttals are absent.
Without T3.1 the v3.0 evaluate path would silently return
Unknown (the previous behaviour, A1-closure of the
mode-vs-rebuttal gap).

The sibling decision is required to neutralise the §20 protected-
path rule so the v3.0 evaluate path is exercised in isolation;
without the sibling decision the kernel-rule path `gate_v32`
would block independently of `evaluate`, masking the T3.1 wiring.

Acceptance gate for obligation `t3-1-gate-v30-risk-aware` of
the meta-decision `decisions/plan-2026-10-improvements@1` and
the sub-decision `decisions/plan-2026-10-improvements/t3-1.yaml@1`.

  $ cd "$DUNE_SOURCEROOT"
  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ git init -q
  $ git config user.email "t@t"
  $ git config user.name "t"
  $ mkdir -p axioms decisions
  $ printf 'placeholder' > a.txt
  $ git add . && git commit -q -m initial
  $ printf 'schema: math-coding/3.0-alpha\nid: t3-1-axiom-toucher\nrevision: 1\nstate: active\nbody_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"\nyaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"\nintent: Test fixture\ncommitment: No obligations\noutcomes: []\nobligations: []\nassumptions: []\nreversal: []\nrisk:\n  declared_triggers: []\n  owner: human:test\nrelations:\n  revises: []\n  supersedes: []\n  superseded_by: []\n  refines: []\n  depends_on: []\n  conflicts_with: []\n  addresses: []\n  implements: []\n  verifies: []\ncounterexample: |\n' > decisions/t3-1-axiom-toucher.yaml
  $ echo "axiom A0 base" > axioms/A0.md
  $ git add . && git commit -q -m "first"
  $ echo "axiom A0 changed" > axioms/A0.md
  $ printf 'schema: math-coding/3.0-alpha\nid: t3-1-axiom-toucher\nrevision: 1\nstate: active\nbody_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"\nyaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"\nintent: Test fixture\ncommitment: No obligations (revised)\noutcomes: []\nobligations: []\nassumptions: []\nreversal: []\nrisk:\n  declared_triggers: []\n  owner: human:test\nrelations:\n  revises: []\n  supersedes: []\n  superseded_by: []\n  refines: []\n  depends_on: []\n  conflicts_with: []\n  addresses: []\n  implements: []\n  verifies: []\ncounterexample: |\n' > decisions/t3-1-axiom-toucher.yaml
  $ git add . && git commit -q -m "second"
  $ git diff HEAD~1 HEAD --name-only
  axioms/A0.md
  decisions/t3-1-axiom-toucher.yaml
  $ MATH_CODING_ROOT="$DUNE_SOURCEROOT" mathc gate HEAD~1 HEAD | jq -c 'del(.now) | {verdict}'
  {"verdict":"block"}
  $ cd /
  $ rm -rf "$tmp"
