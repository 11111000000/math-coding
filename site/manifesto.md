# Manifesto

> **Eight principles, one static binary.** math-coding is
> a discipline of recording decisions before code, with the
> kernel enforcing that record.

## What this is and where it fits

mathcoding is an assurance protocol for software changes:
each change is bound to a recorded obligation, a bounded
attestation, and a deterministic kernel verdict (`pass`,
`fail`, `inconclusive`, …). It is not CI, not docs-as-code,
and not "LLM-as-judge". A point-by-point comparison with
twenty neighbouring methodologies is at
[Differences](differences.html).

## Why this exists

Decisions get forgotten — but not because nobody writes
them down. They do: `docs/adr/0007-cache-revocation.md`,
`specs/checkout-flow.md`, an LLM-as-judge pipeline in CI.
By the third release the original reason is no longer
recoverable without an archaeologist. The code drifts away
from the intent because we conflate two different actions:
recording a decision and verifying it. None of the usual
tools distinguishes them.

Three neighbouring approaches leave that conflation
unanswered:

- **ADR (Nygard / MADR).** Decisions are recorded in
  Markdown — but there is no gate that checks the ADR
  against the code. The record decays silently; "Status:
  superseded" stays a string instead of becoming an edge
  in a revision DAG.
- **Spec-Driven Development** (GitHub Spec Kit, AWS Kiro,
  2025). The spec precedes the code — but it is not bound
  to a verifier. A spec without a passing test is treated
  as adopted; formal conformance is passed off as
  verification.
- **LLM-as-judge.** The model issues a verdict — but with
  no source class, no inputs, and no time bound. "Checked"
  and "not checked" are indistinguishable in its output:
  a model's verdict is `reviewed`, not `observed`.

All three share the same conflation: recorded is passed
off as verified. mathcoding keeps the two on opposite
sides of the protocol and joins them back together
through the obligation, the attestation, and the verdict.
No attestation means `inconclusive`. "I didn't check" is
not the same as "I checked and it works".

math-coding inverts the asymmetry: every architectural
commitment is written **before** the code, and the kernel
checks the commitment against the code on every merge.
The discipline is called **mathcoding**.^[The smallest
element that closes the feedback loop in a working
discipline is a verifier — a program that can be re-run
and whose exit code means pass or fail.]

![math-coding architecture: five concentric layers around a human — axioms, kernel, protocol objects, site and tools, user projects.](assets/architecture-overview.svg)

The architecture diagram above is the manifesto's mental
model. A human sits at the centre: every change to
math-coding itself, every change to the kernel, every
change to the protocol objects, every change to the site
and tools, every change to the user projects is gated by
the same math-coding. The protocol surrounds the human in
five concentric layers; nothing escapes the gate.

## What this is not

- Not a CI runner. Use `scripts/dev` or GitHub Actions.
- Not a documentation generator. The spec is normative;
  the tooling reads the spec.
- Not a code-review tool. Use `paseo` agents or GitHub PR
  review.
- Not a runtime monitor. The kernel runs offline;
  attestations are produced out of band.

The kernel's job is the **assurance loop**: every commitment
has a path to an observation, every observation is filed
under a known source class, every source class is bounded
by subject, inputs, and time.

![The human in the loop: three roles (author, reviewer, operator) touch five points in the protocol. The fifth (sign attestation or grant waiver) is the only one the kernel cannot replace.](assets/human-in-the-loop.svg)

The human-in-the-loop diagram above is the manifesto's
answer to the question "where does the human fit in an
automated protocol?" The answer: at three roles and five
points. The kernel is the floor; the human is the ceiling.

## Principles at v3.0

The kernel verifies the obligations declared in every
active decision (52 active decisions / 207 obligations
on a clean `main` HEAD per the latest build), all
documented as packets under `decisions/`. Eight of those
packets form the minimum set that closes the bootstrap
loop:

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
closes the bootstrap loop: from the first commit
(`v3-alpha-0.0.1`) to the moment the kernel can check
itself (commit `8fa7fcf`), every change had to be admitted
by all eight. Now both are. The full live inventory is at
[Packages](packages.html).

![Human roles vs object kinds: which role touches which of the seven kinds. Author creates, reviewer reviews, operator operates; the kernel handles the rest.](assets/human-roles.svg)

The roles-vs-kinds diagram is the manifesto saying that
the eight principles are not nine principles. Each role
is a human position; each kind is a kernel position; the
protocol divides the work so that humans do what only
humans can do (commit, review, operate) and the kernel
does the rest.

## The boundary

![The boundary between kernel-determined and human-determined. The kernel may check six things; six things only a human may decide. Verbatim from spec/constitution.md section Authority Boundary.](assets/kernel-vs-human.svg)

The kernel-vs-human diagram is the manifesto's
constitutional moment. Six things the kernel may check;
six things only a human may decide. The boundary is the
manifesto's central commitment: the protocol is checked
by the kernel on one side and judged by humans on the
other; the two sides meet at the gate.

## How to read this site

Start with [Methodology](methodology.html). Then
[Axioms](axioms.html) for the philosophical foundations.
Then [Foundations](foundations.html) for the OCaml mapping.
Then [Packages](packages.html) for the live assurance
surface.

This site is itself produced by the kernel (`mathc render`).
The index page below is the live output of `mathc packages`.
The pages you read are arguments the kernel accepts
about itself.
