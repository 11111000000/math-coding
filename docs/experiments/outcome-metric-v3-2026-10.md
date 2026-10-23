# Outcome metric v3 — a measurement that can fall

> Status: protocol, ready to run.
> Decision: `decisions/outcome-metric-v3-2026-10.yaml`
> Date: 2026-10-23

## Why this exists

Every number the project has carried for six weeks measures the
PROCESS: how many decisions exist, how many obligations, how many
attestations, whether the gate says pass. All of them moved in the
right direction while the project was, by its own measurements,
getting worse to use.

The clearest instance: the store reported 192 passing subjects. When
every one of those attestations was re-signed by actually RUNNING the
verifier it names, the number became 139. Nothing broke. The number
had been counting signatures, not verified properties.

A methodology that cannot produce a number that can go DOWN cannot be
used to decide whether it is worth having.

## What is measured

Three numbers, all of which can fall:

| # | Metric | Unit | Where it comes from |
|---|---|---|---|
| M1 | Defects escaping the merge gate | defects per 100 merged changes | a defect is a change that had to be REVERTED or hot-fixed within 14 days |
| M2 | Time to a first green CI on a real change | minutes | CI wall time, measured on the merge queue, not on a synthetic run |
| M3 | Share of decisions that changed the system's behaviour | ratio | the `outcome` field: `changed` or `unchanged` |

M1 and M2 are external to the repository and require a baseline arm.
M3 is internal and can start today.

## The M3 field

Every decision gains:

```yaml
outcome: changed | unchanged
```

`changed` means the decision's commitments alter what the system
DOES. `unchanged` means it records, clarifies, or constrains without
altering behaviour — a taxonomy correction, a doc sync, a schema
tightening with no behaviour change.

The field is a claim about the decision, recorded by its author, and
it is falsifiable: a reviewer who believes a `changed` decision
changed nothing can say so, and the corpus's ratio moves.

**The point of the field is the ratio, not the field.** Today every
decision is implicitly `changed`, because nothing asks. In three
months the corpus can say what fraction of its decisions were
ceremonies — a number that has never existed and that no amount of
process-conformance measurement can produce.

## The protocol for M1 and M2

Three projects, two arms, the same tasks:

- **Arm A (baseline)**: the project as it is, with its own existing
  process.
- **Arm B (math-coding)**: the project with the protocol applied.

Rules:

1. The SAME tasks in both arms, drawn from the project's own backlog,
   not invented.
2. The SAME number of tasks per arm, interleaved in time so a
   machine-load change does not favour one arm.
3. M2 is the wall time from "agent starts" to "CI green on the first
   push", per task.
4. M1 is counted over 14 days AFTER the task merged: a revert, a
   hotfix, or an incident attributable to the change.
5. The result is reported even if it favours the baseline. A
   protocol whose measurement is only published when it wins is a
   protocol whose measurement is worthless.

## What would count as a failure

- M1 is not lower in arm B.
- M2 is not lower in arm B.
- M3's `unchanged` share is above 50%, which would mean most of the
  corpus is ceremony.

Any of these is a result, and the result changes the protocol.

## The standing rule

The experiment runs ONCE and its result is recorded in a decision.
After that the metric is part of the project's own numbers, and the
next run is scheduled rather than summoned.
