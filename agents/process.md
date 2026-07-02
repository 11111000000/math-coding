# Detailed process for opening a packet

This document expands the 5-step process in `agents/agents.md`
into 13 detailed steps. Use it when you need to write a
non-trivial packet and want explicit guidance.

## 1. Read core.md

Read `core/core.md` completely. Do not skim. The document
is the single source of truth, grounded in theory.

## 2. Decide rigor

Pick the rigor level that matches the task. See
`agents/rigor-tools.md` for the six levels and when to use
each. Default: `light`.

## 3. Check existing packets

Look in the project's `specs/` (or `math/`) directory for
existing packets that overlap with this task. If you find
one, update it rather than opening a new packet.

## 4. Decide whether the task is non-trivial

Apply the decision gate (ADR-0002): 4+ implicit assumptions
mean the task warrants a packet. If the task is trivial
(rename, typo, one-line fix), fix it directly and skip the
rest.

## 5. Create the packet directory

Run:

```sh
sh .opencode/commands/mathpacket <id> [title]
```

The script reads `.mathcodingrc` for `packets_dir` (default
`specs/`). It generates the boilerplate: `packet.yaml`,
`task.md`, `assumptions.yaml`, `refinement.md`,
`traceability.json`.

## 6. Fill in task.md

Three sections, in this order:

- `## Problem` — what is wrong or missing
- `## Desired outcome` — what success looks like
- `## Constraints` — bullet list, each bullet a predicate
  (must / shall / requires / <= / >= / =) or 5+ words

Each section must be substantive. Empty sections or
single-sentence sections fail verification.

## 7. Fill in assumptions.yaml with 4+ entries

Each entry:

```yaml
- id: A<n>             # sequential
  statement: <text>
  status: user-confirmed | agent-inferred | open
  epistemology: fact | hypothesis | judgment | unknown
  confidence: 0.0-1.0  # optional but encouraged
```

Apply the epistemic protocol from `agents/agents.md`:
- `judgment` for design decisions (you cannot verify these)
- `unknown` for open questions (ask the user)
- `fact` if you can verify (read source, run check)
- `hypothesis` if uncertain (default)

## 8. Fill in packet.yaml

Set:

- `task_id` — already filled by `mathpacket`
- `title` — already filled
- `lifecycle` — `sketch` initially
- `created` — already filled
- `substrate` — matches your rigor choice
- `decision` — `needed` if you opened the packet
- `verifier` — leave null for now
- `owner`, `priority`, `tags` — recommended

## 9. Write the model (if rigor > light)

If rigor is `temporal`, write `Model.tla`. If `relational`,
write `Model.als`. If `proof`, write `Model.v`. If `bpmn`,
write `Model.bpmn`.

Each model is a **formal artifact** in the language of your
rigor tool. The model describes the system; the verifier
script runs the tool against it.

For `light` and `property` rigor, no model file is needed.

## 10. Write the verifier

Each rigor level has a corresponding `verify-*.sh`:

- `light`: `verify.sh` — runs the structural verifier
- `property`: `verify-property.sh` — runs PBT
- `temporal`: `verify-tlc.sh` — runs TLC
- `relational`: `verify-alloy.sh` — runs Alloy Analyzer
- `proof`: `verify-coq.sh` — runs Coq
- `bpmn`: `verify-bpmn.sh` — runs BPMN engine

The verifier must produce `verifier-output.yaml` with
provenance fields (`verdict`, `verified_at`, `scope`, `tool`,
`evidence`).

## 11. Write refinement.md

Five sections:

- `## State mapping` — spec states to implementation states
- `## Operation mapping` — spec actions to impl actions
- `## Invariant preservation` — proof sketch
- `## Test obligation mapping` — tests for each invariant
- `## Runtime-check mapping` — where checks live in code

## 12. Write traceability.json

```json
{
  "links": [
    {
      "source": "task.md:## Problem",
      "target": "<file:line or path>",
      "kind": "concept-grounding | implementation-grounding | cross-reference | bibliographic"
    }
  ]
}
```

The `target` is either a real source file (in the project's
`src/`, not in the packet) or a reference to another
document.

## 13. Run the verifier and promote lifecycle

Run the structural verifier:

```sh
sh examples/self-application/verify-consistency.sh
```

If the verdict is `VERIFIED`, you may set
`lifecycle: verified`. Otherwise, fix the violations and
re-run.

For promoted packets, update `packet.yaml`:

```yaml
verifier:
  command: sh verify.sh
  verdict_file: verifier-output.yaml
```

The `verifier-output.yaml` is auto-written by the verifier;
do not write it manually.

## After promotion

The packet is now part of the project. Update
`traceability.json` if the implementation changes. Run the
verifier on every change. Promote to `deprecated` or
`archived` when the packet no longer reflects current code.