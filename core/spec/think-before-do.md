# think-before-do (math-coding v0.854)

The process precedes the code. The packet is written before
the implementation. axiom Process fixes this as the temporal
discipline of the convention.

## Order

1. **State the proposition** in `decision.md`. Why does this
   code exist? What claim does it make?

2. **State the intent** in `task.md`. What does success look
   like? What constraints apply?

3. **Mark the assumptions** in `assumptions.yaml`. What do
   we believe? With what confidence? On what evidence?

4. **Refine the implementation** in `refinement.md`. What is
   the state? What is the operation? What is the invariant?
   What is the test?

5. **Commit the manifest** in `packet.yaml`. Pin the
   lifecycle. Pin the verifier.

6. **Write the code** in `src/`, `lib/`, or wherever the
   project's own convention dictates.

7. **Record the witness** in `packet.yaml:applications[]`.
   The git SHA of the commit, the files that implement the
   packet, the date, the author.

8. **Verify** with `sh core/check/verify.sh`. Five files
   present? Lifecycles valid? Epistemic markers valid?

9. **Probe** with `sh core/self/probe.sh`. axiom Self-Application holds?

## Forbidden

- **Code before packet.** Writing code without a proposition
  is vibe-coding. axiom Process forbids it.

- **Skip `working`.** A packet may not move from `sketch` to
  `verified` directly. axiom Process forbids it.

- **Verify without witness.** A `verified` packet without
  `applications[]` SHA is a lie. axiom Process enforces it.

## Anti-patterns

- **"Looks fine" verdicts.** A packet must declare its
  verdict, not assume it. axiom Accounting forbids unmarked belief.

- **Unmarked assumptions.** Every claim has a marker. axiom Accounting
  enforces it.

- **Drift after witness.** A `applications[].sha` that no
  longer matches the file is a stale witness. axiom Self-Application
  detects it.

## What `think-before-do` is NOT

- It is not a recipe. It is a discipline. The five files are
  not a script; they are a record.

- It is not bureaucracy. Every field has a role. If a field
  does not help the proof, it should not be there.

- It is not perfection. A packet's claim may be wrong.
  axiom Accounting's epistemic markers exist precisely so that wrong
  claims are marked as `hypothesis` or `unknown`, not `fact`.