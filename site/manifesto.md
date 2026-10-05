# Manifesto

> **Eight principles, one static binary.** Math-coding is a
> discipline of recording decisions before code, with the
> kernel enforcing that record.

## Why this exists

A codebase without decision records drifts. The architect
made a choice in week 3, forgot about it by week 9, and by
week 17 the original reason is gone — only the code remains,
impossible to reconstruct without an archaeologist. The
typical fix is documentation; the typical failure is that
the documentation is not checked against the code.

Math-coding inverts the asymmetry: every architectural
commitment is written **before** the code, and the kernel
checks the commitment against the code on every merge.
The discipline is called **mathcoding** — math-coding
applied as a methodology to software change.^[The smallest
call that closes a feedback loop in a process discipline is a
verifier — a program that can be re-run and whose exit
code means pass or fail.]

## What it is not

- Not a CI runner. Use `scripts/dev` or GitHub Actions.
- Not a documentation generator. The spec is normative;
  the tooling reads the spec.
- Not a code-review tool. Use `paseo` agents or GitHub PR
  review.
- Not a runtime monitor. The kernel runs offline; attestations
  are produced out of band.

The kernel's job is the **assurance loop**: every commitment
has a path to an observation, every observation has a known
source class, every source class is bounded by subject,
inputs, and time.

## Eight principles at v3.0

The kernel verifies eight principles, all documented as
packets under `decisions/`:

| Group | Principle | What it asserts |
|-------|-----------|-----------------|
| foundation | `bootstrap-v3` | the kernel can check this repository |
| foundation | `kernel-conformance-runner` | every fixture is enumerated and run |
| foundation | `validate-and-context` | every decision parses and exposes a capsule |
| foundation | `gate-decision` | the gate verdict is machine-checked |
| foundation | `attestation-store-fill` | the attestation store is populated |
| extension | `mathc-explain-subcommand` | `mathc explain` resolves a `decision:` ref |
| extension | `mathc-self-check-subcommand` | `mathc self-check` returns an automated verdict |
| extension | `mathc-packages-subcommand` | `mathc packages` is a first-class surface |

The eight are not arbitrary. They are the minimum set that
closes the bootstrap loop: from the first commit (`v3-alpha-0.0.1`)
to the moment the kernel can check itself (commit `8fa7fcf`),
every change had to be admitted by all eight. Now both are.

## How to read this site

Start with [Methodology](methodology.html). Then [Axioms](axioms.html)
for the philosophical foundations. Then [Foundations](foundations.html)
for the OCaml mapping. Then [Packages](packages.html) for the live
assurance surface.

This site is itself produced by the kernel (`mathc render`). The
index page below is the live output of `mathc packages`. The
pages you read are arguments the kernel accepts about itself.