# packet-schema (math-coding v0.991)

Every packet is exactly five files. The verifier
(`core/check/verify.sh`) checks this contract.

## packet.yaml — manifest

```yaml
task_id: <string>                  # unique identifier
title: <string>                    # human-readable name
lifecycle: sketch|working|verified|deprecated|archived|superseded
substrate: none|shell|tla|coq|alloy|pbt|bpmn|pbt-prism
rigor: light|property|temporal|proof
decision: needed|made
created: "YYYY-MM-DD"
verifier: <command> | null          # null = self-applied
depends_on: [<task_id>, ...]        # topological
applications: []                   # witness list, see A5
implementation: absent|partial|complete  # v0.991: required for applied
```

## decision.md — proposition

Sections:

  ## Thesis       — the claim this packet commits to
  ## Antithesis   — what could contradict the thesis
  ## Synthesis    — the resolution
  ## Surface impact  (optional) — which external contract this touches
  ## Proof          (optional) — how this is verified

For `bugfix` template, omit `## Antithesis`.

## task.md — intent

Sections:

  ## Problem         — what problem this packet addresses
  ## Desired outcome  — what success looks like
  ## Constraints     — must be testable, plus any others

## assumptions.yaml — epistemic context

```yaml
task_id: <task_id>
assumptions:
  - id: A1
    statement: "<claim>"
    status: user-confirmed|agent-inferred|open
    epistemology: fact|hypothesis|judgment|unknown|proven
    confidence: 0.0-1.0    # only for fact|hypothesis
    evidence: |
      <one-line evidence>
      See: <file:line or packet:path>
```

Five epistemic markers. `proven` is reserved for end-to-end
verified claims (axiom Self-Application).

## refinement.md — state/operation/mapping/invariant/test/runtime

Sections:

  ## State               — pre-state, post-state
  ## Operation           — the action that implements the packet
  ## Mapping             — spec state → impl state
  ## Invariant preservation — what stays true
  ## Test obligation     — how to verify this packet
  ## Runtime check       — how to monitor at runtime

For `bugfix` template, `## Mapping` is optional.

## Mode

The mode is set by `decision.md:## Pressure` and recorded
implicitly by which fields are filled:

  light    — commit message only, no 5-file packet
  standard — full 5-file packet, applications[] filled at verified
  strict   — packet + theory link + applications[] + surface impact