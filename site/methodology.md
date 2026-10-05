# Methodology — mathcoding

> This page is about the methodology that math-coding (the kernel)
> implements. We call the methodology **mathcoding** — math-coding
> applied as a discipline to software change. The kernel is the
> reference implementation; the methodology is the thinking.

## What mathcoding is

Mathcoding is the practice of binding every meaningful change to an
**observable commitment** before it merges. It is not a CI tool, not
a code-review tool, not a documentation tool. It is the discipline
that links intent, decisions, obligations, changes, attestations,
and revisions into one chain:

```text
intent -> decision -> obligation -> change -> attestation -> revision
```

The chain is enforced by a kernel. The kernel does not write new
content into the chain — it only *checks* that the content the
humans wrote is honest. (A0 Separation: an attestation is not an
observation; a decision is not an obligation; a change is not yet
attested.) The kernel produces verdicts (`pass`, `fail`, `unknown`,
`waived`, `stale`, `missing`); humans remain the actors.

## The five axioms

The methodology is grounded in five propositions. Each one is a
constraint on what the kernel may say, not a feature the kernel
ships.

| ID | Title | One-line |
|----|-------|----------|
| A0 | Separation | Kinds are distinct; the chain goes one way |
| A1 | Feedback | Every commitment has a path to observation |
| A2 | Invariants | Every invariant is paired with a recovery path |
| A3 | Self-application | The rules govern their own changes |
| A4 | Care | Owner, consequence, accountability required |

The axioms are in `axioms/` as Markdown. The kernel reads them
only as data, not as instructions. See [axioms](axioms.html) for
the formal statements.

## Working chain in practice

A change arrives as a `git diff`. The kernel asks four questions:

1. **Schema.** Does every artifact (decision, obligation,
   attestation, waiver) match its JSON Schema? (`mc validate`.)
2. **Identity.** Does every relation endpoint resolve? Does every
   `(kind, id, revision)` form a globally unique tuple?
   (Constitution invariants 2 and 4.)
3. **Freshness.** Are the attestations still current? Has any
   material digest shifted? (`mc gate BASE HEAD`.)
4. **Coverage.** Does every obligation declared in the active
   policy have at least one machine-checked verifier and one
   positive + negative fixture? (`mc self-check`.)

The fourth question is the one that closes the **bootstrap gate**.
A bootstrap-gate `pass` means the released kernel successfully
checks this repository and its conformance corpus. From that
release onward, the kernel's verdicts are automated guarantees,
not manual declarations.

## Friction levels

Mathoding is not uniform. Some changes are silent (deterministic
checks confirm nothing meaningful moved); some require a record
(decision + obligation); some require an *ask* (a reviewer must
weigh in); some **block** (the kernel refuses to merge). The
ladder:

```text
silent < record < ask < block
```

The kernel chooses the least sufficient level. A kernel may raise
friction but never lower it.

## Adoption

Adopting mathcoding in an existing project is, in practice, three
steps:

1. Create `decisions/decision.yaml` declaring the active policy
   (start with `bootstrap-v3@2`).
2. Add the kernel binary (`mc`) to CI; `mc self-check` becomes a
   blocking step.
3. Move existing guarantees — code-review records, JUnit reports,
   security attestations — into the `attestations/` directory as
   JSON. The kernel reads them; the kernel cannot lie about them.

A worked example lives in this site. The README, ROADMAP, PACKAGES,
and AGENTS files in the repo are themselves inputs to the
methodology.

## Why this is a methodology, not a tool

A tool runs on a computer. A methodology checks whether the
computer (and the people using it) are doing what they said they
were doing. The math-coding kernel is the reference implementation
of the methodology; the methodology is the set of constraints the
kernel enforces. Without the methodology, the kernel is a parser
that produces verdicts about well-formed JSON. Without the kernel,
the methodology is a discipline that produces no enforced
guarantees.

The two exist in order. The methodology constrains the kernel.
The kernel proves the methodology. This is what A3 means by
*self-application*: the rules govern their own changes.