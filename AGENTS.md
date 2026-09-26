# Math-coding 3.0-alpha bootstrap protocol

> Project author: Petr Kosov <p.b.kosov@yandex.ru>

This repository is migrating from math-coding 2.1 to 3.0-alpha. The
3.0 kernel does not exist yet. Until `mathc self-check` passes, all
assessments are manual declarations and MUST NOT be described as
automated guarantees.

The complete v2.1 source is preserved by the remote Git tag
`v2.1-final`. Do not use v2 packet fields, commands, or lifecycle rules
for new work.

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
