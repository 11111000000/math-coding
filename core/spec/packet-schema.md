# packet-schema (math-coding v0.992)

Every packet is exactly five files. The verifier
(`core/check/verify.sh`) checks this contract.

## packet.yaml — manifest

```yaml
task_id: <string>                  # unique identifier
title: <string>                    # human-readable name
lifecycle: draft|applied|retired|abandoned   # v0.992: graduated ceremony
substrate: none|shell|tla|coq|alloy|pbt|bpmn|pbt-prism
rigor: light|property|temporal|proof
decision: needed|made
created: "YYYY-MM-DD"
verifier: <command> | null          # null = self-applied
depends_on: [<task_id>, ...]        # topological
implementation: absent|partial|complete  # v0.991: required for applied
verified_by: [name, ...]            # v0.992: required when applied (peer review traceability)
single_author: false                # v0.992: set true if peer-review is single-actor
applications: []                   # witness list, see A5
                                   #   each entry: {sha, by, date, pressure,
                                   #   files[], tests, tests_result}
amendments: []                     # v0.992: append-only history of changes
                                   #   each entry: {date, by, reason, sha}

### Lifecycle (graduated ceremony)

| State      | Files | impl | SHA | review | verified_by |
|------------|-------|------|-----|--------|-------------|
| draft      | 3 mandatory | any  | no  | no     | no          |
| applied    | 3 mandatory | complete | yes | ≥1 approve | yes |
| retired    | closed       | —    | —   | —      | —           |
| abandoned  | closed       | —    | —   | —      | —           |

`applied` is the production-ready state. axiom packets are exempt
from `verified_by` and `implementation=complete` (reference material).
Drafts are cheap; ceremony grows with state.
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

## Naming

If a packet name carries a version tag, the tag is the
**last** segment of the name: `<slug>-v<N><N><N>` (no dots).
Axiom packets (`0X-name`) are exempt. Tests in
`tests/naming-version.sh` enforce this rule.

## Stability contract

These surfaces are stable within a major version:

  - 5-file packet format (additive only; renaming is breaking)
  - 7 spec fields (proposition/outcome/invariant/test/antithesis/synthesis/operation)
  - 5 epistemic markers (fact/hypothesis/judgment/unknown/proven)
  - 4 lifecycle states (draft/applied/retired/abandoned)
  - applications[] entry fields (sha, by, date, files, pressure, tests, tests_result)
  - All `math-coding` dispatcher commands

A breaking change to any of these requires a major version bump.
See `KNOWN_LIMITATIONS.md` for current limitations.