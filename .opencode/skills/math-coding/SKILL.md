# Math-Coding Skill for opencode

This skill teaches opencode how to apply the math-coding
convention when working on this repository.

## What is math-coding

Math-coding is a packet-based methodology for software
development. It is grounded in 8 mathematical theories:
predicate logic, finite state machines, temporal logic,
refinement, Hoare logic, model checking verdicts, epistemic
logic, and supersession. Each rule in the convention has a
formal definition in `core/01-Theory/`.

## When to load this skill

Load this skill when:
- The user asks you to add a feature to a math-coding repository
- The user asks you to refactor or fix a packet
- The user asks about the convention itself
- The user asks you to write or modify TLA+ models, schemas,
  verifiers, or any packet artifact

## How to apply the convention

### Read first (mandatory)

Before doing anything, read:
1. `core/core.md` — the canonical convention
2. `agents/agents.md` — what AI agents specifically should do
3. The relevant theory document from `core/01-Theory/`

### Epistemic action protocol

When you read an `assumptions.yaml` entry, look at the
`epistemology` field. Apply this protocol:

| Epistemology | Your action |
|--------------|--------------|
| `judgment` | Respect, do not challenge |
| `unknown` | Ask user, do not proceed |
| `fact` | Verify if possible; downgrade to `hypothesis` if can't |
| `hypothesis` | Search for evidence; upgrade to `fact` on find |

This protocol is **not optional**. Without it, epistemic
markers are cosmetic.

### Packet lifecycle

`sketch → working → verified → deprecated → archived`

Transitions are FSM-constrained. Don't promote without verifier
output. See `core/core.md §State machine` for details.

### Process for opening a packet

1. Decide: is this task non-trivial (4+ implicit assumptions)?
2. If yes, copy template from `examples/hello/`.
3. Fill in `task.md` (Problem, Desired outcome, Constraints).
4. Fill in `assumptions.yaml` with 4+ entries; apply epistemic
   protocol.
5. Fill in `packet.yaml` with manifest, owner, priority, tags.
6. If task warrants a model, write `Model.tla` and `Model.cfg`.
7. If task warrants a verifier, write `verify*.sh` and ensure
   it produces `verifier-output.yaml`.
8. Write `refinement.md` with five required sections.
9. Write `traceability.json` linking model elements to code.
10. Run `sh examples/self-application/verify-consistency.sh`.
11. Promote lifecycle only if verifier succeeded.

### What NOT to do

- Do not invent file names not in `core/core.md`
- Do not write `verifier-output.yaml` manually
- Do not mark assumptions as `judgment` or `unknown` without
  human confirmation
- Do not commit without successful verifier run

## Verifier

The verifier is `examples/self-application/verify-consistency.sh`.
It checks 14 structural invariants:

- File encoding (UTF-8 LF, no BOM)
- File naming convention
- Required fields present
- Lifecycle value valid
- Section structure (Problem, Desired outcome, Constraints)
- Epistemic markers valid
- FSM transitions legal
- Refinement.md sections present
- Traceability.json valid
- depends_on resolution
- Content check (10+ words per section)

The schema meta-validator is `examples/schema-self-application/verify-schemas.sh`.
It validates that JSON Schema files in `schemas/` are syntactically
valid and structurally complete.

## Mathematical foundation

The eight theories are **the reason** math-coding works. They
let agents reason about packets formally:

- `core/01-Theory/01-Predicate-and-Invariant.md` — invariants as
  predicates $I : S \to \mathbb{B}$
- `core/01-Theory/02-State-Machine.md` — FSM as tuple
  $\langle S, s_0, A, \to, I \rangle$
- `core/01-Theory/03-Temporal-Logic.md` — LTL operators
  `[]`, `<>`, `~>`, `WF`, `SF`
- `core/01-Theory/04-Refinement.md` — refinement as
  homomorphism $R : S_{\text{impl}} \to S_{\text{spec}}$
- `core/01-Theory/05-Assumption-Set.md` — assumptions as
  axioms $\Sigma \vdash \text{Spec}$
- `core/01-Theory/06-Verdict.md` — verdicts as theorem
  statements $\text{Spec} \models P$
- `core/01-Theory/07-Epistemic.md` — belief updates
  $B : \text{Prop} \times \text{Agent} \to [0,1]$
- `core/01-Theory/08-Deprecation.md` — supersession as
  partial order $P_{\text{old}} \perp P_{\text{new}}$

When you read a packet's invariants or state machine, reference
these theories for the formal definitions.

## Anti-patterns

- **Treating epistemic markers as decoration.** They drive
  behavior.
- **Skipping the verifier.** The verifier is what makes the
  convention rigorous.
- **Adding new fields to packet.yaml.** Only fields in the
  schema are allowed.
- **Writing prose that "looks right".** Apply the epistemic
  protocol: judgment, unknown, fact, hypothesis.
- **Skipping the trace links.** `traceability.json` is the
  bridge between model and code.

## When stuck

Read `core/core.md` again. If it doesn't answer, the methodology
is silent on that point — proceed with judgment and document
your decision in the packet's `task.md` under `# Adaptations`.