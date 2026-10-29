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

![The math-coding chain: intent, decision, obligation, change, attestation, revision. Obligation is highlighted — that is where the kernel's check lives. A dashed oxblood arc loops back from revision to intent, labelled "revision extends commitment into the next decision".](assets/chain.svg)

The chain is enforced by a kernel. The kernel does not write new
content into the chain — it only *checks* that the content the
humans wrote is honest. (A0 Separation: an attestation is not an
observation; a decision is not an obligation; a change is not yet
attested.) The kernel produces verdicts (`pass`, `open-with-waiver`,
`block`, `unknown` — the four-value vocabulary of
`spec/semantics.md` §4.3); humans remain the actors.

The seven kinds shown in the diagram are not a hierarchy — they are
a contract. Each kind is a distinct object with a distinct purpose:

- **intent** is what someone wants to do.
- **decision** is the recorded commitment to do it.
- **obligation** is the property the kernel can check on the change.
- **change** is the diff that lands in main.
- **attestation** is the evidence the obligation holds.
- **observation** is the world's signal about whether it does.
- **revision** is the recorded decision about what to do next.

The dashed oxblood arc from `revision` back to `intent` in the diagram
is the closure property: a revision extends commitment into the next
decision, so the chain has no beginning. (A3 Self-application: the
rules govern their own changes — including this very diagram.)

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
the formal statements. Each axiom is operationalised by a specific
bootstrap-related decision:

![The five axioms on the left, paired with the bootstrap decisions they enforce on the right: A0 Separation -> bootstrap-v3, A1 Feedback -> attestation-store-fill, A2 Invariants -> kernel-conformance-runner, A3 Self-application -> mathc-self-check-subcommand, A4 Care -> validate-and-context. Footer: "Each axiom is operationalised by a specific decision the kernel checks; the axioms are not aspirational."](assets/axiom-graph.svg)

The right column of the diagram is the list of decisions that the
bootstrap gate verifies. The fact that the pairing is exhaustive
(A0 through A4 each land on a specific decision) is what makes the
axioms operational rather than aspirational.

## Working chain in practice

A change arrives as a `git diff`. The kernel asks four questions:

1. **Schema.** Does every artifact (decision, obligation,
   attestation, waiver) match its JSON Schema? (`mathc validate`.)
2. **Identity.** Does every relation endpoint resolve? Does every
   `(kind, id, revision)` form a globally unique tuple?
   (Constitution invariants 2 and 4.)
3. **Freshness.** Are the attestations still current? Has any
   material digest shifted? (`mathc gate BASE HEAD`.)
4. **Coverage.** Does every obligation declared in the active
   policy have at least one machine-checked verifier and one
   positive + negative fixture? (`mathc self-check`.)

Each of these four questions has a corresponding step in the
verdict-flow pipeline. The flow shown below is the same code path
that runs every time you invoke `mathc gate` or `mathc self-check`:

![Verdict flow: from decision.yaml and attestations to gate_merge and exit code. Six steps: parse decisions with identity I4; infer obligations per spec/algebra-3.2 §8; classify mode via the risk function per §2; compose direct and transitive obligations per §9; collect attestations across running CIs per §14; gate_merge per §15 plus A2 invariants. Output row lists the four verdict colours and exit codes from spec/semantics.md §4.3.](assets/verdict-flow.svg)

The pipeline reads from two inputs — the decision store and the
attestation store — and produces one output — a verdict per
obligation, composed into a single disposition with an exit code.
The middle three steps (infer, classify, compose) are the kernel
doing what a CI tool could not: composing partial truths from
heterogeneous attestations into a single, defensible verdict.

The fourth question is the one that closes the **bootstrap gate**.
A bootstrap-gate `pass` means the released kernel successfully
checks this repository and its conformance corpus. From that
release onward, the kernel's verdicts are automated guarantees,
not manual declarations.

## Friction levels

Methodology is not uniform. Some changes are silent (deterministic
checks confirm nothing meaningful moved); some require a record
(decision + obligation); some require an *ask* (a reviewer must
weigh in); some **block** (the kernel refuses to merge). The
ladder:

```text
silent < record < ask < block
```

The kernel chooses the least sufficient level. A kernel may raise
friction but never lower it.

![Friction ladder: silent (top, kernel chooses) below ask (human reviews) to block (bottom, kernel refuses). Four rungs with the friction envelope, a representative commit kind, the gate posture, and the signer required by KERNEL_AGENTS.md friction ladder and A3 self-application.](assets/friction-ladder.svg)

The friction ladder has a horizontal axis (friction envelope) and
a vertical axis (level of involvement). Notice the alignment
between the four rungs and the four risk bands:

![Risk bands: five coloured bands from tiny to exhaustive, mapped to example changes, gate posture, and who signs. Bands: tiny (pale gray), light (pale cream), standard (pale oxblood), strict (deeper oxblood), exhaustive (solid oxblood).](assets/risk-bands.svg)

The risk function that classifies a change is the same function
that maps it to a friction level (see `spec/algebra-3.2.md` §2 and
§21). A change that is risky enough to be classified `exhaustive`
will always be `block`; a change classified `tiny` will always be
`silent`. The two diagrams are two views of the same property.

The four risk bands do not just label a change — they bind the
gate posture (silent / record / ask / block) to the signed
attestation type. A `strict` band requires a reviewer signature
plus an automated attestation. An `exhaustive` band requires a
release-engineer signature plus a conformance-runner attestation.
The kernel never invents these requirements; the policy declares
them in `decisions/decision.yaml`.

## Adoption

Adopting mathcoding in an existing project is, in practice, three
steps:

1. Create `decisions/decision.yaml` declaring the active policy
   (start with `bootstrap-v3@2`).
2. Add the kernel binary (`mathc`) to CI; `mathc self-check` becomes a
   blocking step.
3. Move existing guarantees — code-review records, JUnit reports,
   security attestations — into the `attestations/` directory as
   JSON. The kernel reads them; the kernel cannot lie about them.

The third step is the one that changes the project's culture. Code
review comments are the human voice of the project; attestations
in `attestations/*.json` are the machine voice. The kernel reads
the machine voice and produces verdicts; humans read the human
voice and produce revisions. The two voices must agree. A worked
example lives in this site. The README, ROADMAP, PACKAGES, and
KERNEL_AGENTS files in the repo are themselves inputs to the methodology.

The attestation lifecycle is the kernel's contract with CI:

![Attestation lifecycle: production, store, join, verdict, expiry. Five stages from a CI run to a gate verdict. Production captures the substrate fingerprint inside a CI run. Store writes the attestation document. Join reads the store and pairs attestations with obligations. Verdict composes per-obligation results into a single disposition. Expiry flips an obligation to Inconclusive when its valid_until is reached.](assets/attestation-lifecycle.svg)

The five stages — production, store, join, verdict, expiry —
cover every CI run that the kernel reads. The "expiry" stage is
the one most projects miss: an obligation can become stale
without anything changing in the code, simply because time has
passed. A `valid_until` field on every obligation is what makes
the verdicts honest over time, not just at the moment of the
commit.

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

![The math-coding kernel pipeline: input -> schema -> parser -> attestation join -> self-check -> gate. Each stage emits the artifact the next stage consumes. The kernel does not invent content; it only checks the content the humans wrote is honest.](assets/kernel-architecture.svg)

The pipeline above is the architecture. Every box in the diagram
is a kernel module. Every arrow is a function call. The
methodology, by contrast, is what you, the human, decide to do
with the kernel's verdicts — and that decision is the one A4
demands you do with care.
