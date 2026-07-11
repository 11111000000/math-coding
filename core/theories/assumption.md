# Theory: Assumption Set (Hoare Logic)

**Rigor:** any

A specification is a pair (Pre, Post) where Pre is the
precondition and Post is the postcondition. A program P
satisfies Spec under assumptions Σ iff:

  ∀s: Pre(s) ⇒ (∧_{a∈Σ} a(s)) ⇒ Post(P(s))

Written: Σ ⊢ Spec.

**Used in:** assumptions.yaml. Each entry is an assumption in Σ.
The packet's task.md:§Constraints is the Pre; the
task.md:§Desired outcome is the Post.

**Example:** Σ = {packet structurally complete}, Pre =
{packet directory exists}, Post = {all 5 files present}.
Program P: creates 5 files. Verification: iff structural
completeness holds, postcondition holds.