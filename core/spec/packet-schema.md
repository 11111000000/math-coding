# packet-schema (math-coding v0.992)

Every packet is **six** files: the five below plus a
`witness` file when the packet is applied. The verifier
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
amendments: []                     # v0.992: append-only history of changes
                                   #   each entry: {date, by, reason, sha}

NOTE: witness is NOT in packet.yaml. axiom A5 recursion
breaks when refresh commit rewrites applications[] in the
file it is supposed to witness. Witness lives in a sibling
file `witness` (see below).
```

### Lifecycle (graduated ceremony)

| State      | Files | impl | witness | review | verified_by |
|------------|-------|------|---------|--------|-------------|
| draft      | 5 mandatory | any  | no       | no     | no          |
| applied    | 6 (with witness) | complete | yes (≥1 SHA) | ≥1 approve | yes |
| retired    | 6 (witness frozen) | —    | frozen   | —      | —           |
| abandoned  | 5 (no witness if never applied) | — | — | — | — |

`applied` is the production-ready state. axiom packets are
exempt from `verified_by` and `implementation=complete`
(reference material), but their `witness` files follow the
same format as non-axiom applied packets.

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
  ## Desired outcome  — what becomes true
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

## witness — git state record (applied packets only)

**One line.** Space-separated git SHAs (40-char hex). The
**first** SHA is the canonical applied state; subsequent SHAs
are historical applications. Append-only: each `apply`
operation appends the current HEAD SHA. **Never** modified
when `packet.yaml`, `decision.md`, `refinement.md`, etc.
change — that's the whole point of externalizing the witness.

```
c706707664aad46e39609d80218ddad5ab454066
```

(One SHA on a single line. For multiple applications, space-
separated: `c706707 9c0206d`.)

`drift-check.sh` reads each file under `files[]` (when an
applied packet's entries were migrated to witness, files
were dropped — drift-check reads files from the git history
between witness SHA and HEAD instead). `verify.sh` requires
`witness` to exist for `applied` packets and parses each
SHA via `git cat-file -e`.

axiom A5 (Accounting): "changes are witnessed." Witness is
the **stable**, **external**, **append-only** record of when
the packet was applied. Self-reference in `packet.yaml`
made refresh commits invalidate the witness — the external
file is the fix.

## Naming

If a packet name carries a version tag, the tag is the
**last** segment of the name: `<slug>-v<N><N><N>` (no dots).
Axiom packets (`0X-name`) are exempt. Tests in
`tests/naming-version.sh` enforce this rule.

## Stability contract

These surfaces are stable within a major version:

  - 6-file packet format (5 mandatory + witness when applied)
  - 7 spec fields (proposition/outcome/invariant/test/antithesis/synthesis/operation)
  - 5 epistemic markers (fact/hypothesis/judgment/unknown/proven)
  - 4 lifecycle states (draft/applied/retired/abandoned)
  - All `math-coding` dispatcher commands
  - Witness file format (one line, space-separated SHAs)

`applications[]` field in `packet.yaml` is **removed** as
of v0.992. Migrate existing packets via
`meta/migrate-witnesses.sh`.

A breaking change to any of these requires a major version bump.
See `KNOWN_LIMITATIONS.md` for current limitations.
