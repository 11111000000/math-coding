# Math-coding 3.0-alpha bootstrap protocol

> Project author: Petr Kosov <p.b.kosov@yandex.ru>

This repository is migrating from math-coding 2.1 to 3.0-alpha. The
3.0 kernel does not exist yet. Until `mathc self-check` passes, all
assessments are manual declarations and MUST NOT be described as
automated guarantees.

The complete v2.1 source is preserved by the remote Git tag
`v2.1-final`. Do not use v2 packet fields, commands, or lifecycle rules
for new work.

## Read first

Before changing anything in this repository, read in order:

1. `README.md` — current state and scope.
2. `spec/constitution.md` — invariants of the kernel.
3. `spec/domain.md` — entity model.
4. `spec/semantics.md` — gate logic and exit codes.
5. `OCAML_BEST_PRACTICES.md` — project-specific OCaml conventions,
   including which conventions are *enforced* by `bootstrap/decision.yaml`.
   The trap log in §11 is the first place to look when debugging an
   OCaml or dune error.
6. `bootstrap/decision.yaml` and `bootstrap/infrastructure-honesty.yaml`
   — the active decisions; their obligations describe the manual checks
   you must perform and the verifiers you must satisfy.
7. `axioms/` — the philosophical and mathematical foundations. Every
   non-trivial change MUST be derivable from at least one axiom.

If any of these contradict each other, the contradiction is a deficit.
Report it; do not silently resolve it.

## When a dune or OCaml error appears

Before adding a workaround or running `rm -rf _build`:

1. Read `OCAML_BEST_PRACTICES.md` §11 (the trap log). Many recurring
   errors are recorded there with minimal reproducers.
2. If the error is not in the trap log, fix the underlying cause and
   append a new entry to §11 before merging.
3. Never `rm -rf _build` directly. Use `./scripts/dev rebuild`.

## Purpose

Math-coding links a concrete change to the obligations it may affect and
to bounded evidence about those obligations. It does not prove software
correctness.

The working chain is:

```text
intent -> decision -> obligation -> change -> attestation -> revision
```

## Before work

Use an isolated branch or worktree. Inspect the current tree before
editing. Do not overwrite unrelated work.

For a meaningful change, state this compact contract before editing:

```yaml
intent: What should become true?
change_kind: implementation | decision | policy | constitution
affected_capabilities: []
must_preserve: []
counterexample: What plausible case would make this change wrong?
unknowns: []
planned_evidence: []
```

For a provably editorial change, state only:

```yaml
change_kind: editorial
reason: Why behavior and policy are unchanged.
```

## Friction

Apply the least sufficient response:

- `silent`: deterministic evidence shows no semantic or protected change.
- `record`: the change is meaningful but covered by existing decisions and evidence.
- `ask`: an answer would change behavior, risk, obligations, or recovery.
- `block`: an explicit policy requirement has an unresolved deficit.

Never block without naming the rule, affected subject, reason, and at
least one remedy. Unknown is not Pass. A waiver is not Pass.

## Decisions

Create a decision only for a new commitment, tradeoff, assumption,
public contract, risk acceptance, architecture, or policy change.

Do not create a decision for formatting, spelling, generated output,
evidence refresh, implementation of an existing decision, or a
behavior-preserving refactor with adequate characterization evidence.

Decision reasoning is proportional to risk:

- low risk: commitment, obligation, reversal condition;
- consequential: options, countercase, tradeoff;
- critical or irreversible: failure modes, recovery, independent review.

## Evidence

Distinguish sources:

```text
declared != derived != attested != reviewed != observed
```

An agent report is a declaration, not evidence. A passing test only
attests to its named obligation, subject, inputs, environment, and run.
Do not claim stronger assurance than the source supports.

Prefer existing tests, CI, reviews, and standard reports. Do not rerun
or duplicate evidence when relevant material digests are unchanged.

## After work

Report only the knowledge delta:

```yaml
changed: []
preserved: []
evidence: []
new_assumptions: []
remaining_unknowns: []
```

Run all available relevant checks. If a check cannot run, state why.

## Agent conduct

- Use project memory and a bounded context capsule instead of reading
  every historical decision.
- Suggest failure modes and obligations; do not present inference as
  policy or evidence.
- Ask only questions whose answers change implementation, obligations,
  risk, recovery, or the gate.
- Preserve uncertainty explicitly instead of inventing values.
- Do not store private chain-of-thought, secrets, or unnecessary
  personal data in project artifacts.

## Honest time reporting

When the agent makes a claim about how long a past or future task
"took", "will take", or "should take", it MUST name one of three
observable scales, cite a reference class, and not combine the
three scales into a single natural-language estimate.

The three allowed scales are:

```text
wall-clock-minutes   real seconds/minutes from session start to now
                     (or the runtime harness's own clock)
token-budget         prompt + completion tokens consumed
step-count           tool calls / reasoning rounds performed
```

These three are independently observable. Wall-clock is recorded
by the user or runtime harness; token-budget by the API; step-count
by the harness. No fourth scale is acceptable without an axiomatic
justification (A0 separation).

For a forward-looking estimate (e.g., "this refactor will take
~20 min"), the agent MUST cite a reference class. The default
reference class for software-engineering work in this repository
is `bin/data/time-distribution.yaml`, which is a declared
distribution from SWE-bench Verified (n=500, 2025-Q4 frontier). The
canonical estimator command is:

```text
mc time-estimate --class <name> --count N --percentile p50|p80|p95|p99
```

The agent MUST NOT replace this estimator with private intuition
or with phrases such as "a few days of focused thought" or "a
month of work" that combine scales or omit a reference class.

Anti-patterns:

- "I have spent days on this." — unless wall-clock is recorded.
- "This is a one-month project." — unless reference-class uplifted
  (P95 of SWE-bench-V for class `kernel-change` is 150 min; a
  one-month claim requires a different reference class with a
  decision citing it).
- "Quick fix, a few minutes." — when actual time is unknown.
- Mixing scales: "a week of careful thinking" confuses wall-clock
  (a week) with subjective attention (careful thinking). Pick
  one scale; the other must be in a separate claim.

This norm is normative (see axiom A1 Feedback — every commitment
must have a path to an observation). The agent's duration claims
are commitments. Without an observable scale + reference class they
are wishes.

## Self-application

Changes to this protocol, the constitution, schemas, canonicalization,
kernel, or protected policy controls always require:

1. a decision under the currently active rules;
2. a strongest practical countercase;
3. positive and negative conformance fixtures;
4. a migration and recovery path;
5. authorization by the previous active policy;
6. an explicit list of changed verdicts.

Candidate rules cannot authorize their own adoption.

## Bootstrap gate

Until the 3.0 kernel is implemented, a change may proceed only when
all applicable checks below are manually satisfied:

- the intended behavior and affected capabilities are explicit;
- known invariants are preserved or deliberately revised;
- the strongest relevant counterexample has been considered;
- planned evidence is available or its absence is declared;
- every known blocking deficit has a remedy;
- rollback or forward recovery exists for irreversible work;
- specification changes include positive and negative fixtures;
- no automated guarantee is claimed.

The bootstrap protocol expires when the released 3.0 kernel
successfully checks this repository and its conformance corpus.
