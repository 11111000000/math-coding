---
proposition: "  v0.991 strengthens epistemic honesty in math-coding through   evidence enforcement and peer-review criteria without blocking   honest agents. "
antithesis: "  The same epistemic honesty could be enforced via interactive   prompts that block create until checks pass; this protects   honest agents from oversight but creates ceremony that   slows every legitimate action. "
synthesis: "  Convention echoes prompts without blocking. Epistemic honesty   is enforced structurally — minimum evidence requirements   verified by verify, peer reviews required for applied —   not interactively. Honest agents benefit; adversarial agents "
axiom: 
substrate: none
---

# epistemic-v0991

## Thesis

  v0.991 strengthens epistemic honesty in math-coding through
  evidence enforcement and peer-review criteria without blocking
  honest agents.

## Antithesis

  The same epistemic honesty could be enforced via interactive
  prompts that block create until checks pass; this protects
  honest agents from oversight but creates ceremony that
  slows every legitimate action.

## Synthesis

  Convention echoes prompts without blocking. Epistemic honesty
  is enforced structurally — minimum evidence requirements
  verified by verify, peer reviews required for applied —
  not interactively. Honest agents benefit; adversarial agents
  remain outside the convention's reach, and this is documented
  honestly in KNOWN_LIMITATIONS.

# Refinement: epistemic-v0991

## State

- pre: <state before implementation>
- post:   LLM agents produce packets with honest epistemic markers;
  reviewers (human or AI) apply explicit criteria before
  approving; convention warns but does not block.

## Operation

  1. verify.sh: enforce `fact` requires evidence.
  2. verify.sh: enforce `applied` requires reviews.
  3. SKILL.md: add Anti-patterns section.
  4. SKILL.md: add Peer-critique section.
  5. create-packet.sh: echo self-critique prompt.
  6. review-packet.sh: new command, echo criteria.
  7. math-coding dispatcher: add review command.
  8. mathrc.sh: required_approvals default = 1.
  9. tests/run.sh: Case 30-34 for new behavior.

## Invariant preservation

  All `fact` markers carry evidence; all `applied` packets
  have at least one `approve` review; convention never
  pretendits protection from adversarial LLMs.

## Test obligation

  1. verify exits 0 on packets with `fact`+evidence.
  2. verify warns on packets with `fact` and empty evidence.
  3. verify rejects `applied` packets without reviews.
  4. review command outputs criteria prompt before verdict.
