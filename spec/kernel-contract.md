# The kernel contract

> **What this is.** An index into the OCaml kernel. Every rule the
> kernel has appears here three times over: WHAT the rule is, WHERE it
> is enforced (the file and the symbol), and HOW you can see it
> enforced (the test that fails if it stops being true).
>
> **What this is not.** A second source of truth, and not a copy of the
> code. The kernel is the normative text; this file is the map that
> says where each rule lives. Where a rule is a NUMBER, the number
> lives in the code, and the test that pins it is named here.
>
> **Two classes.** A promise with a code symbol behind it and a test
> that fails when it stops being true is ENFORCED. A promise with
> neither is DECLARED, and every one of them is in §31 with the owner
> accountable for it and the date it is looked at again. DECLARED is
> not a demotion: the corpus's own instrument
> (`tests/fixtures/negative-control-debt.sh`) counts every promise in
> three classes — CHECKED, DECLARED, UNCHECKED — and a promise that
> says which class it is in is better placed than one that pretends.
>
> **The anchors did not move.** The section numbers are the ones this
> document has carried since the rename of 2026-11: `§2` is the risk
> function, `§7` is the decision record, `§11` is the dialectic, `§15`
> is the gate verdict. A pointer that names a section still names it.
> §32 says what each section became.

## §0. Goal and the honest uncertainty principle

- **Rule.** A result is `Pass`, `Fail`, `Inconclusive` or `InfrastructureError`, and the absence of a result is `Inconclusive`, never `Pass`. `Waived`, `Reviewed` and `Observed` are not verdicts.
- **Code.** `lib/gate.ml` — the verdict type and its rendering; `lib/attestations/attestations.ml` — a missing attestation is not a pass.
- **Test.** `tests/cli/gate-unknown-exit-3.t` (no evidence is `unknown`, exit 3), `tests/cli/gate-pass.t`, `tests/fixtures/verdict-vocabulary-spec-coherence.sh`.

## §1. Vocabulary

- **Rule.** The kinds the kernel knows (`Intent`, `Decision`, `Obligation`, `Change`, `Attestation`, `Observation`, `Revision`) and the sets the algebra is written in (`𝓒` commits, `𝓟` paths, `𝓜` modes, `𝓡` risk, `𝓞` obligations, `𝓣` trust, `𝓢` substrate).
- **Code.** `lib/domain.ml` — the record and variant definitions.
- **Test.** `tests/conformance.ml` (every positive fixture parses, every negative fixture is rejected), `tests/repo_structure.ml`.

## §2. Risk function

- **Rule.** `risk(c) = impact(c) · probability(c) · irreversibility(c)` and `mode(c) = max(risk_to_mode(risk(c)), mode_floor(c))`; the buckets are `< 0.05` tiny, `< 0.20` light, `< 0.60` standard, `< 0.90` strict, exhaustive above that. The floor comes from `policies.yaml`.
- **Code.** `lib/risk.ml::risk_to_mode`, `lib/risk.ml::mode`, `lib/risk.ml::classify`; `lib/policy.ml::mode_floor_of`.
- **Test.** `tests/cli/risk-bucketing.t` (the buckets and the effective mode), `tests/cli/mode-floor-from-policies.t` (the floor is read, not assumed).

> **Notation note.** The bucketed `risk_to_mode` above is the canonical form, and the shorthand it replaced was ambiguous. The ambiguity and its closure are recorded in `decisions/algebra-3.2-notation-flag-2026-10.yaml`.

## §3. Authoring model

- **Rule.** A decision is read from its sibling YAML when one exists and from the commit body otherwise; when both exist their digests must agree.
- **Code.** `lib/decision.ml` — the canonical form and the digest comparison; `lib/memory.ml` — the decision store.
- **Test.** `tests/cli/body-vs-wrapper-canonical.t`, `tests/cli/decision-resolution.t`, `tests/body_canonical_test.ml`.

## §4. Inline authoring

- **Rule.** DECLARED, not enforced: the requirement that a change at the modes `tiny` and `light` carries an inline body section is a promise no program checks — the kernel reads the sibling YAML and the trailer. See §31.
- **Code.** `lib/decision.ml` — the body-section reader, which is what the kernel actually reads.
- **Test.** `tests/cli/body-vs-wrapper-canonical.t`, `tests/cli/gate-trailer-decision.t`.

## §5. Trailer mechanism

- **Rule.** At the modes `tiny` and `light` a change needs a decision with it: a sibling YAML, or a `decision:<id>@<rev>` trailer that resolves in the parent tree.
- **Code.** `lib/gate.ml::apply_rule` — the `PreTemporalPrecedence` rule; `lib/protected_paths.ml` — the paths the rule protects.
- **Test.** `tests/cli/gate-trailer-decision.t`, `tests/cli/gate-v32-wired.t`.

## §6. Sibling YAML authoring

- **Rule.** A decision lives either as `decisions/<id>.yaml` beside the commit or in the `## math-coding:` body section; the sibling YAML is the canonical form from the mode `standard` up.
- **Code.** `lib/decision.ml` — the sibling/body reader.
- **Test.** `tests/cli/decision-resolution.t`, `tests/cli/validate-non-decisions.t`.

## §7. Decision entity

- **Rule.** A decision is a record with an id, a revision, a state, an intent, a commitment, a scope, outcomes, obligations, assumptions, a risk block, relations and two digests. Every active decision names the axiom(s) it addresses through `axiom_link`, and the relation graph is acyclic over `revises`, `supersedes`, `refines` and `depends_on`.
- **Code.** `lib/decision.ml` — the record, the parser and `infer_axiom_candidates`; `lib/domain.ml` — the type.
- **Test.** `tests/cli/validate-axiom-link.t` (the axiom link is required), `tests/fixtures/relation-targets-resolve.sh` (every relation target resolves), `tests/cli/validate-sha-match.t`, `tests/body_canonical_test.ml`.

### §7.1 Byte-range and canonicalisation

- **Rule.** `body_sha` and `yaml_sha` are the sha256 of the file's own bytes with both fields replaced by the placeholder `sha256:` + 64 zeros, after CRLF is normalised to LF; the two fields must be equal when both are present.
- **Code.** `lib/decision.ml::body_canonical_sha256`; the reference implementation is `scripts/axiom-link-seed.py`.
- **Test.** `tests/body_canonical_test.ml` (the four properties and the digest vectors), `tests/cli/body-vs-wrapper-canonical.t`.

## §8. Auto-inferred obligations

- **Rule.** DECLARED, not enforced: the classifier table that maps a path to an obligation kind is a promise no program applies. The obligations the kernel carries are the ones a policy declares and the ones a decision states. See §31.
- **Code.** `lib/policy.ml::obligation_ref` — the (kind, namespace) pair a policy carries; `lib/policy.ml::compose` — where the obligations come from.
- **Test.** `tests/policy_test.ml` (the pair and the composition), `tests/fixtures/redundancy-census.sh` (the paper layer the classifier would have removed).

## §9. Multi-policy per path

- **Rule.** A path is covered by the policies that name it. Three composition axes apply, in this order: hierarchical (the `parent:` chain is resolved first, by `resolve_policy`), union (the obligations are unioned and the floors maximised), transitive (the data-flow closure adds the obligations of the reachable paths).
- **Code.** `lib/policy.ml::resolve_policy`, `lib/policy.ml::compose`, `lib/policy.ml::mode_floor_of`, `lib/policy.ml::data_flow_targets`.
- **Test.** `tests/policy_test.ml` (the three axes and the cycle guard), `tests/cli/mode-floor-from-policies.t`.

### §9.1 Composition axes

- **Rule.** The three composition axes and the order they compose in: hierarchical (the `parent:` chain is resolved first), union (the policies that match are merged), transitive (the data-flow closure is applied last). The rule is §9's; this sub-section names the axes.
- **Code.** `lib/policy.ml::resolve_policy`, `lib/policy.ml::compose`, `lib/policy.ml::data_flow_targets`.
- **Test.** `tests/policy_test.ml`.

## §10. Rebuttal mechanism

- **Rule.** A rebuttal is a record beside the commit (`rebuttals/<sha>.yaml`) or in the forge mirror, and it binds when the rebutter's trust in the obligation's domain is at least the authority the mode requires.
- **Code.** `lib/rebuttal.ml` — the reader, `trust_rank` and `compute_binding`; `lib/domain.ml::trust` — the four levels.
- **Test.** `tests/cli/rebuttals.t`.

## §11. Dialectic slots (counterexample, antithesis)

- **Rule.** A decision above the mode `tiny` carries a `counterexample` — the strongest objection to a future reader — and a decision at the mode `considered` carries an `antithesis` — the counter-position the author engaged with. The kernel warns when the counterexample is missing and blocks when the mode requires it.
- **Code.** `lib/diagnostic.ml` — the counterexample and antithesis diagnostics; `bin/Mathc.ml` — the validator.
- **Test.** `tests/cli/validate-counterexample-required.t`, `tests/cli/validate-considered-antithesis.t`.

### §11.1 Rationale (dialectic method, v3)

- **Rule.** The three dialectic moves live in three fields: `intent` is the thesis, `antithesis` the counter-position the author considered and rejected, `commitment` the synthesis. The forcing function beside them is the `counterexample` slot of §11. The rule is §11's; this sub-section names the triad.
- **Code.** `lib/decision.ml` — the fields the parser reads.
- **Test.** `tests/cli/validate-considered-antithesis.t`, `tests/cli/validate-counterexample-required.t`.

## §12. Trust dynamics

- **Rule.** The four trust levels and the binding predicate are ENFORCED (see §10); the DYNAMICS — history, attestation density, escalation — are DECLARED, because no program computes them. See §31.
- **Code.** `lib/domain.ml::trust`, `lib/rebuttal.ml::trust_rank`, `lib/rebuttal.ml::compute_binding`.
- **Test.** `tests/cli/rebuttals.t` (the levels and the binding).

## §13. Auto-attestation

- **Rule.** An attestation records the decision it speaks for, the obligation it discharges, the CI run that produced it, the substrate it was produced against, the environment class it was produced in, the result, and the window in which it is current.
- **Code.** `lib/attestations/attestations.ml` — the record, the environment class and the substrate digest; `bin/Mathc.ml` — the writer.
- **Test.** `tests/cli/attest-batch.t`, `tests/cli/attest-batch-positive.t`, `tests/cli/attest-batch-malformed.t`.

## §14. Multi-CI attestation aggregation

- **Rule.** An obligation is `Pass` when every attestation for it is a pass and every one of them is current; it is `Fail` when a decisive attestation says so; otherwise it is `Inconclusive`. An attestation is current while `issued_at ≤ now ≤ valid_until`, and decisive when its environment class is at least the threshold the policy declares.
- **Code.** `lib/attestations/attestations.ml::current_at`, `::decisive_for`, `::aggregate_obligation`; `lib/gate.ml` — the aggregation into a verdict.
- **Test.** `tests/cli/gate-pass.t`, `tests/cli/gate-unknown-exit-3.t`, `tests/cli/gate-waiver-scope.t`.

## §15. Gate verdict (phase-aware)

- **Rule.** An obligation has a phase: `pre_merge` blocks the merge gate, `pre_release` blocks the release gate, `post_release` is monitoring-only and surfaces an `AssuranceGap`. The merge gate is open when every blocking obligation passes, every kernel rule applies, and the re-evaluation oracle reports no stale claim.
- **Code.** `lib/gate.ml::gate_v32`, `lib/gate.ml::gate_release_v32`, `lib/gate.ml::post_release_monitor`; `bin/Mathc.ml::do_gate` — the composition of the two verdicts.
- **Test.** `tests/cli/gate-v32-wired.t`, `tests/cli/gate-pass.t`, `tests/cli/gate-fail.t`, `tests/cli/gate-stale.t`.

## §16. Substrate

- **Rule.** The substrate fingerprint is the sha256 of the kernel version, the OCaml version and the dependency digests; an attestation carries the fingerprint of the substrate it was produced against, so an attestation from another build is visibly another build.
- **Code.** `lib/attestations/attestations.ml::compute_substrate_digest`, `::compute_substrate_fingerprint`.
- **Test.** `tests/cli/attest-batch.t`, `tests/cli/attest-batch-from-decisions.t`.

## §17. Inline axiom change

- **Rule.** An axiom change is a revision, an addition or a removal; a revision names the old and the new digests, a counterexample, the impact list and the trailer reference. The re-evaluation oracle answers `Compatible`, `Inconclusive` or `StaleClaim` for every impacted decision, and a stale claim blocks the gate.
- **Code.** `lib/re_evaluation.ml` — the oracle and the verdict order; `bin/Mathc.ml` — the `re-evaluate` subcommand.
- **Test.** `tests/cli/re-evaluate.t`, `tests/cli/re-evaluate-decisions.t`.

## §18. Time-budget

- **Rule.** DECLARED, not enforced: a decision may carry a time estimate, and nothing measures the time a decision took. See §31.
- **Code.** `schemas/decision.json` — the optional `time` block.
- **Test.** `tests/cli/cli-time-estimate.t`, `tests/cli/cli-time-storage.t`.

## §20. Kernel rules

- **Rule.** The kernel carries three rules: `PreTemporalPrecedence`, `CoCommitDecision` (a change to a protected path needs a decision with it) and `CoCommitFixture` (every obligation needs a fixture or a filled review). A rule is added by decision, only at the mode `strict` or above, with a positive and a negative fixture.
- **Code.** `lib/gate.ml::apply_rule` — the three rules; `lib/protected_paths.ml` — the protected paths; `bin/Mathc.ml` — the rules the gate applies.
- **Test.** `tests/cli/gate-v32-wired.t` (each rule fires, and each does not), `tests/fixtures/protected-paths-single-source.sh`.

## §21. Friction envelope

- **Rule.** DECLARED, not enforced: the per-mode line budgets and the comparison with the ADR/CI/review baselines are a promise no program measures. See §31.
- **Code.** `bin/Mathc.ml` — the `context` subcommand's `--budget`, which is a different number from this one.
- **Test.** `tests/cli/context-budget-bound.t` (the budget that IS enforced).

## §22. Quality dimensions

- **Rule.** DECLARED, not enforced: the dimensions and the improvement percentages are a promise no program measures. One rule in this section IS enforced — the required-attestation gate: a decision that declares `required_attestations` rejects a clean tree unless every (kind, producer) pair is satisfied by an attestation in the store. See §31 for the rest.
- **Code.** `lib/gate.ml::required_attestation_satisfied` and the gate that consults it.
- **Test.** `tests/cli/required-attestation.t`, `tests/fixtures/unmet-obligations-are-inventoried.sh`.

## §23. Kernel signature

- **Rule.** The signature is the kernel's: `infer`, `mode`, `compose`, `attest`, `gate`, `trust`, `apply`, `re_evaluate` and `transition` are the functions of `lib/`, and each one is named in the section that owns it. The per-commit COST model that stood beside them — the `O(...)` bounds — is DECLARED: nothing measures the cost of a commit. See §31.
- **Code.** `lib/*.ml` — the nine functions, each named in its own section above.
- **Test.** `tests/conformance.ml`, `tests/repo_structure.ml`.

## §24. Adoption path

- **Rule.** DECLARED, not enforced: which path a project takes — the full kernel, the kernel at a light floor, or no kernel at all — is the owner's documented judgement. See §31.
- **Code.** `lib/init/init.ml` — the envelope the CLI prints at deploy time, which is the part a program can say.
- **Test.** `tests/cli/init.t`, `tests/cli/init-defaults.t`, `scripts/check-adoption-doc-freshen.sh`.

## §28. Applicability envelope

- **Rule.** `default_path(P) ≔ Path A unless P ∈ prototype_or_throwaway(P)`. The envelope is default-on: the burden of proof sits on the exclusion, not on the adoption. The membership test that decides a project's rung is a human's judgement, and the kernel prints the envelope rather than deciding it.
- **Code.** `lib/init/init.ml` — the envelope the CLI prints; `lib/policy.ml` — the mode floor a project declares.
- **Test.** `scripts/check-applicability-agreement.sh` (the rule is stated once and the three surfaces agree), `tests/cli/applicability-envelope.t`.

## §30. Binary distribution

- **Rule.** DECLARED, not enforced by this repository: the property that a user needs no nix, no OCaml and no dune, and that the released binary is reproducible. The anti-property — a nix-store path in the binary's dependencies — is tracked by `decisions/portable-linux-musl.yaml`. See §31.
- **Code.** `flake.nix` — the release matrix and the musl build.
- **Test.** `scripts/check-adoption-doc-freshen.sh` (the pins the adoption documents carry).

## §31. Declared promises

Every promise the kernel cannot check is here, with the owner who is accountable for it and the date it is looked at again. The owner and the date are the corpus's standing ones — `human:maintainer`, reviewed on `2026-12-15`, the same pair the corpus's `declared:` blocks carry. A promise that is neither enforced nor declared is UNCHECKED, and the corpus counts that class separately (`tests/fixtures/negative-control-debt.sh`).

| promise | why no program can check it | owner | review on |
|---|---|---|---|
| The goal of §0: a commit's friction never exceeds ADR + CI + review | nobody measures a commit's friction | human:maintainer | 2026-12-15 |
| The path classifier of §8: `api/**` implies `api-backward-compat`, and the rest of the table | the kernel has no classifier; the obligations come from the policies and the decisions | human:maintainer | 2026-12-15 |
| The inline body section at the modes `tiny` and `light` (§4) | the kernel reads the sibling YAML; it does not read a commit body | human:maintainer | 2026-12-15 |
| The trust dynamics of §12: history, attestation density, escalation | no program computes a trust level over time | human:maintainer | 2026-12-15 |
| The time budget of §18 | a decision states a duration; nothing measures the one it took | human:maintainer | 2026-12-15 |
| The friction envelope of §21: the per-mode line budgets and the baselines | nobody counts the lines of a commit | human:maintainer | 2026-12-15 |
| The quality dimensions of §22 and their improvement percentages | a percentage of what, measured how, is a human's number | human:maintainer | 2026-12-15 |
| The cost model of §23: the per-commit complexity bounds | nothing measures the cost of a commit | human:maintainer | 2026-12-15 |
| The adoption path of §24: which rung a project takes | the membership test is a judgement about the project | human:maintainer | 2026-12-15 |
| The distribution property of §30: a user needs no toolchain, the binary is reproducible | the release artefacts are built elsewhere and are not compared here | human:maintainer | 2026-12-15 |
| The dual-authored canonicalisation of §7.1 | the case has no live consumer, and its three open questions are design questions | human:maintainer | 2026-12-15 |

## §32. What this document no longer carries

Every section that survived kept its number and its subject; what changed is the body. The algebra became a rule with a code symbol and a test, and the sections whose rule no program enforces say so where they stand and point at §31.

- **What became a DECLARED pointer.** §4 (inline authoring), §8 (the auto-inferred obligations), §12 (the trust dynamics), §18 (the time budget), §21 (the friction envelope), §22 (the quality dimensions), §23 (the cost model), §24 (the adoption path) and §30 (the distribution property): each keeps its number and its subject and says, in place, that the promise is one no program checks. §31 carries the list with the owner and the date.
- **What became a pointer to a rule that stayed.** §9.1 (the composition axes) and §11.1 (the dialectic's rationale): the rules are §9's and §11's, and the sub-sections name them.
- **Removed before this transition.** §19 (the fourteen invariants, a duplicate of `spec/constitution.md`), §25, §26, §27 and §29 — see `decisions/kernel-contract-rename-2026-11.yaml` and `archive/decisions/spec-is-an-index-2026-10.yaml`. §19, §27 and §29 are still named by live decisions: those citations were already dangling before this transition and are reported with it.
- **What a reader can no longer learn here.** The pseudo-mathematics, the quantified formulas and the improvement percentages: they were never checked, and a formula that no program checks cannot fail a test. The rules they described are still here, and each one now names the code that enforces it and the test that would notice if it stopped.
