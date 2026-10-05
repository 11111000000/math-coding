# math-coding 3.2-ideal — formal algebra

> **Author:** Petr Kosov &lt;p.b.kosov@yandex.ru&gt;
> **Status:** 3.2-ideal specification (post-fresh-rethink)
> **License:** Apache-2.0 (see `LICENSE`, `NOTICE`)
> **Effective:** on acceptance of `decisions/algebra-3.2.yaml`

This document is the **formal mathematical specification** of the
math-coding 3.2-ideal kernel. It supersedes the prose-style
`spec/domain.md` and `spec/semantics.md` for purposes of normative
authority; those documents remain as historical context.

The algebra preserves the 14 constitution invariants from
`spec/constitution.md` and the 5 axioms from `axioms/`.

## Cross-references

- `axioms/` — A0 (Separation), A1 (Feedback), A2 (Invariants and Recovery),
  A3 (Self-application), A4 (Care)
- `spec/constitution.md` — I1–I14 kernel invariants (preserved verbatim)
- `decisions/decision.yaml` — bootstrap policy
- `lib/` — kernel implementation (must conform to this algebra)

---

## §0. Goal

```
friction_user(commit) ≤ friction(ADR + good-CI + code-review + rebuttal-dialog)

∀ c: cost(commit) ≥ 0  ∧  benefit(commit) ≥ benefit(baseline)

applicability(project, protocol) ∈ ℝ
∀ P: applicability(P, 𝒫) > 0 ⟹ P is candidate for 𝒫

# Honest uncertainty principle (A1-derived)
honest_uncertainty: ∀ assurance claim c:
  result(c) ∈ {Pass, Fail, Inconclusive, InfrastructureError}
  Pass ≠ Fail ≠ Inconclusive ≠ InfrastructureError
  Pass ≠ Waived ≠ Reviewed ≠ Observed
  absence(c) ⟹ c is Inconclusive, never Pass
  # "I haven't checked" ≠ "I checked and it works"
  # "Waived" ≠ "Pass": waiver defers a check, does not cancel it
  # "Reviewed" ≠ "Observed": human review is not runtime evidence

∀ c, decision D, obligation ob:
  attested_pass(ob) ∧ attestation_may_be_stale(ob) ⟹ ob is Inconclusive, not Pass
  freshness_violation ⟹ result transitions Pass → Stale, not silent Pass
```

---

## §1. Universal sets

```
𝓒 = Commits                                  (harness-produced)
𝓟 = Paths
𝓜 = Modes = {tiny, light, standard, strict, exhaustive}
𝓡 = Risk ∈ [0, 1]
𝓞 = Obligations (auto-inferred + policy-declared + transitive)
𝓣 = Trust = {Untrusted < Authenticated < Delegated < Authoritative}
𝓢 = Substrate = compiler × build × runtime × toolchain
𝓐 = Agents = {harness, ci-bot, security-scanner, perf-reviewer, reviewer-N, ...}
𝓒-rule = KernelRules (decision-addable)
𝓡-pol = Policies (per-path declarations)
𝓓-flow = DataFlowEdges (inferred from imports/exports)
𝓡-reb = Rebuttals = sibling `rebuttals/<sha>.yaml` ⊕ forge_mirror
𝓡-axiom = AxiomTransitions = revision | addition | removal
𝓡-trail = Trailer = parsed_git_trailer(c.body)
𝓓-bin = {linux-x86_64, linux-aarch64, darwin-x86_64, darwin-aarch64, windows-x86_64}

ObligationDomain = obligation_kind × path_namespace
```

---

## §2. Risk function

```
risk: 𝓒 → 𝓡
risk(c) = impact(c) · probability(c) · irreversibility(c)

impact(c) = max{classify(path) : path ∈ c.files}
  classify: 𝓟 → [0, 1]
    tests/**         → 0.0
    docs/**          → 0.05
    site/**          → 0.2
    scripts/**       → 0.3
    schemas/**       → 0.3
    lib/utils/**     → 0.2
    lib/core/**      → 0.5
    bin/**           → 0.5
    lib/security/**  → 0.8
    axioms/**        → 0.95
    migrations/**    → 0.95
    unclassified     → 0.5

probability(c) = 0.5 + 0.5 · policy_override_probability(c)
  policy_override_probability(c) ∈ [-1, 1] from policy.yaml
  default 0

irreversibility(c) = max{marker(path) : path ∈ c.files}
  non-mig → 0.1
  data-mig → 0.7
  schema-break → 0.95
  business-irreversible → 0.95

mode(c) = max(⌈risk(c)⌉, mode_floor(c))

mode_floor(c) = max{mode_floor(policy(p)) : p ∈ c.files ∪ transitive_paths(c)}
  mode_floor declared in policy.yaml:
    silent → tiny
    baseline → standard
    pci-strict → strict
    axiom-touching → exhaustive
```

> **Notation note (2026-10-05, ref `decisions/algebra-3.2-notation-flag-2026-10.yaml`):**
> the form `mode(c) = max(⌈risk(c)⌉, mode_floor(c))` is ambiguous given the
> current type declaration `risk: 𝓒 → 𝓡` with `𝓡 ∈ [0, 1]`. The standard
> ceiling function applied to a value in `[0, 1]` yields either `0` or `1`,
> which collapses the mode enumeration. The intended mapping is presumed
> to be a bucketed function `risk_to_mode : [0, 1] → 𝓜` (e.g. via
> `5 ⌈risk · 5⌉` or an explicit piecewise table), but the spec does
> not say so explicitly. This ambiguity is recorded but **not** silently
> rewritten by this branch. The spec owner should either (a) replace
> `⌈risk(c)⌉` with the explicit bucketed form, or (b) redefine `𝓡` as a
> discrete set of values that the ceiling can map onto `𝓜`. See the linked
> decision for counterexamples and the recommended resolution.

---

## §3. Authoring model

```
decision: 𝓒 → Decision
decision(c) = canonical_decision(c)

canonical_decision(c) ≔
  | parse(sibling_yaml(c))             if exists
  | parse(body_section(c))             otherwise
  if both exist: sha256(sibling_yaml) = sha256(body_section)

sibling_yaml(c) = decisions/<id>.yaml @ <rev> referenced by trailer(c)
body_section(c) = parse(## math-coding:* ## in c.body)
```

---

## §4. Inline authoring

```
body_section(c) = parse(## math-coding:* ## in c.body)

∀ c, mode(c) = tiny:
  body section required
  minimum: {classification: impact, probability, irreversibility, risk, mode}

∀ c, mode(c) = light:
  body section required
  minimum: {commitment, counterexample}

∀ c, mode(c) ∈ {standard, strict, exhaustive}:
  body section OPTIONAL
  if present AND sibling_yaml exists: sha256(body) = sha256(sibling_yaml)

∀ axiom-transition c:
  body section OPTIONAL
  if present: sha256(body_new_text) = sha256(axiom_file_at(c))
```

---

## §5. Trailer mechanism

```
trailer(c) = parsed_git_trailer(c.body)

apply(PreTemporalPrecedence, c, t) ≔
  mode(c) ∈ {tiny, light}
  ⊕ has_sibling_yaml(c)
  ⊕ (∃ ref ∈ trailer(c): ref matches "decision:<id>@<rev>?" ∧ resolve(ref, parent(c)) ≠ ∅)

apply(CoCommitDecision, c, t) ≔
  c.files ∩ {lib/**, bin/Mathc.ml, spec/**, schemas/**, axioms/**} = ∅
  ⊕ ∃ d ∈ tree(parent(c)) ∪ tree(c):
       kind(d) ∈ {decision, axiom} ∧ basename(d) referenced by trailer(c)

apply(CoCommitFixture, c, t) ≔
  ∀ ob ∈ obligations(c):
    ob.acceptance.verifier is fixture OR ob.acceptance.review is filled
```

---

## §6. Sibling YAML authoring

```
sibling_yaml(c) exists iff
  ∃ d ∈ tree(parent(c)) ∪ tree(c):
    kind(d) = decision
    ∧ (basename(d) ∈ c.body.sections
       OR trailer(c) ⊇ {Refs: decision:<id>@<rev>?}
       OR declared_decision_paths(c) ⊇ {path_of(d)})

declared_decision_paths(c) = ⋃{yaml_paths(policy(p)) : p ∈ c.files}

∀ c, mode(c) ≥ standard: sibling_yaml exists at commit-time OR trailer references it
```

---

## §7. Decision entity

```
Decision = ⟨id, rev, parents, intent:⟨source,text⟩, commitment, scope,
            outcomes, obligations, assumptions, risk, reversal, relations,
            counterexample, state: draft|active|retired|superseded,
            mode, mode_floor_used, body_sha, yaml_sha⟩

∀ Decision D:
  if D.body_sha ≠ ∅ ∧ D.yaml_sha ≠ ∅: D.body_sha = D.yaml_sha

# 5 epistemic markers for assumptions (restored from v0.854 axiom A5)
assumption = ⟨id,
              state: epistemic_marker,
              statement: String,
              owner: String,
              consequence_if_false: String?,
              review_on: (signal, timestamp?)*,
              evidence: String?,
              confidence: [0.0, 1.0]?⟩

epistemic_marker = fact | hypothesis | judgment | unknown | proven

∀ assumption A:
  if A.state ∈ {fact, hypothesis}: A.confidence ∈ [0.0, 1.0] is required
  if A.state ∈ {judgment}: A.evidence is required (human-rationale observation)
  if A.state = unknown: explicit admission of no current knowledge
  if A.state = proven: end-to-end kernel-verified claim, reserved for axiom A3 self-application

# marker semantics (A1 Feedback closure)
fact:        verifiable observation, current
hypothesis:  predictive, needs future observation
judgment:    human-rationale opinion, not observable yet
unknown:     explicitly not known, must not be passed as ground truth
proven:      closed loop: commitment → attestation → observation

∀ D ∈ Decision, A ∈ D.assumptions:
  if A.state = proven: ∃ attestation a ∈ Attestation: a.decision = D.id ∧ a.result = Pass
  if A.state = unknown: A.consequence_if_false must enumerate risks from ignorance

# 8 relations (from spec/domain.md, made explicit in 3.2)
relation_kind = revises | supersedes | refines | depends_on | conflicts_with
              | addresses | implements | verifies

relations: ⟨
  revises: id[],           # updates representation, preserves identity (acyclic)
  supersedes: id[],        # replaces commitment with different commitment (acyclic)
  refines: id[],           # narrows scope of parent decision (acyclic)
  depends_on: id[],        # cannot be evaluated without parent (acyclic)
  conflicts_with: id[],    # symmetric: mutual exclusion
  addresses: id[],         # implements one or more axioms
  implements: id[],        # realizes one or more decisions (in code)
  verifies: id[]           # attestation that proves one or more obligations
⟩

∀ D ∈ Decision:
  acyclic(revises* ∪ supersedes* ∪ refines* ∪ depends_on*)       [I6, I7]
  symmetric(D₁ ∈ D₂.conflicts_with ⟺ D₂ ∈ D₁.conflicts_with)
  revises ≠ supersedes: revises updates form; supersedes replaces meaning
```

---

## §8. Auto-inferred obligations

```
infer: 𝓒 × 𝓜 → P(Obligation)
infer(c, m) = ⋃{classify_obligation(path, m) : path ∈ c.files}

classify_obligation: 𝓟 × 𝓜 → P(ObligationKind)
  case m:
    tiny/light: ∅
    standard+:
      path matches api/**          → {api-backward-compat}
      path matches state-machine/** → {state-transition-correct}
      path matches migrations/**    → {data-integrity}
      path matches security/**      → {security-review}
      path matches perf-critical    → {perf-bench}
      path matches cli/subcommand   → {cli-shape, cli-help-text, spec-catalog-row}
      path matches axioms/**        → {axiom-coherence, axiom-impact-list}
```

---

## §9. Multi-policy per path

```
policy: 𝓟 → Policy
policy(p) = declared(p) if exists else default-policy
policy(p) = ⟨obligations(p), mode_floor(p), transitive_into(p)⟩

direct_obligations(c) = ⋃{obligations(policy(p)) : p ∈ c.files}
transitive_paths(c) = data_flow_targets*(c.files)
transitive_obligations(c) = ⋃{obligations(policy(p)) : p ∈ transitive_paths(c)}

obligations(c) = direct_obligations(c) ⊕ transitive_obligations(c)

data_flow_targets(p):
  - imports(p) → q: q ∈ data_flow_targets(p)
  - exports(p) → q: q ∈ data_flow_targets(p)
  - transitive closure: data_flow_targets*(p) = ⋃ₙ data_flow_targetsⁿ(p)
```

---

## §10. Rebuttal mechanism

```
rebuttals(c) = rebuttals_yaml(c) ⊕ forge_mirror(c).comments

rebuttals_yaml(c) ≔ rebuttals/<commit-sha>.yaml if exists
forge_mirror(c) ≔ forge_api.comments_for(commit_sha) if forge integrated else ∅

∀ rebuttal r ∈ rebuttals(c):
  r = ⟨rebutter: 𝓐, objection: String, evidence: Evidence,
       outcome: pending|accepted|rejected_with_reason|ignored_non_binding|never_resolved,
       trust_level_at_rebuttal: 𝓣⟩

binding(r) ≔ trust(r.rebutter, obligation_domain(c)) ≥ authority(c.mode)

decision_text carries committer's opening position only
rebuttals live in rebuttals/<sha>.yaml + forge mirror, NOT in body

∀ c, mode(c) ≥ strict: rebuttals(c) may exist (not required)
∀ c, mode(c) = exhaustive: rebuttals(c) required for non-Unblocked verdict
```

---

## §11. Counterexample

```
counterexample: Decision → String*

∀ D ∈ Decision, mode(D) ≠ tiny:
  |counterexample(D)| ≥ 1
  rebuttals extend this thread via rebuttals/<sha>.yaml
```

---

## §12. Trust dynamics

```
trust: 𝓐 × ObligationDomain → 𝓣

trust(a, d) = f(history(a, d), attestation-density(a, d))
  history(a, d) = recent_commits_signed(a, d) × recent_rebuttals_accepted(a, d)
  attestation-density(a, d) = signed(a, d) / reviewed(a, d)
  f monotone in both

trust dynamics:
  rebuttal.accepted                → trust(a, d) ↑
  rebuttal.rejected_with_reason    → trust(a, d) ↓
  rebuttal.ignored_non_binding     → trust(a, d) unchanged
  rebuttal.never_resolved          → trust(a, d) unchanged

trust escalation:
  ∃ review(claim_expertise, agent, domain) verified by forge
  → trust(agent, domain) raises one tier
```

---

## §13. Auto-attestation

```
attest: 𝓒 → P(Attestation)
attest(c) = {⟨id=sha256(c × ob × now × ci_run_id),
             decision_sha=c.sha,
             decision_yaml_sha=trailer_decision_sha(c) if exists else ∅,
             obligation=ob,
             ci_run_id,
             substrate_digest=sha256(kernel.ver || ocaml.ver || dep.digests),
             environment_class_level ∈ 0..4,
             environment_class_label ∈ dev|staging|staging-integration|prod-mirror|prod,
             result ∈ Pass|Fail|Inconclusive|InfrastructureError,
             issued_at, valid_until,
             evidence_digest=sha256(ci_logs),
             producer: ci-bot-identity,
             substrate_fingerprint: 𝓢.id⟩ : ob ∈ obligations(c)}

∀ a ∈ Attestation:
  a is signed by producer
  a.environment_class_level ≥ policy.min_environment_class
  a.substrate_digest ∈ known_substrates(policy)
```

---

## §14. Multi-CI attestation aggregation

```
attestations(c) = ⋃{attest_ci(c, k) : k ∈ running_CIs(c)}

gate(c, p, t) default: wait_for_all_blocking_CIs
  blocking_CIs(c) = {k : policy.ci_blocking(k) = True}

∀ obligation ob:
  result(ob) =
    | Pass             if ∀ a ∈ attestations(c) with ob: a.result = Pass ∧ current(a)
    | Fail             if ∃ a ∈ attestations(c) with ob: a.result = Fail ∧ decisive(a)
    | Inconclusive     otherwise

current(a) ≔ a.issued_at ≤ now ≤ a.valid_until
decisive(a, p) ≔ a.environment_class_level ≥ p.decisive_threshold(ob)
```

---

## §15. Gate verdict (phase-aware)

```
# 3 obligation phases (from spec/domain.md, made explicit in 3.2)
phase = pre_merge | pre_release | post_release

∀ obligation ob:
  ob.phase determines when ob is enforced
  phase(pre_merge):    blocking for merge gate (§15 merge)
  phase(pre_release):  blocking for release gate (§15 release)
  phase(post_release): monitoring-only, NOT blocking for merge or release
                       violation → AssuranceGap, surfaced via dashboard

gate: Change × Policy × 𝓣 × 𝓒-rule → Gate × Optional[ReleaseGate] × Stream[AssuranceGap]

gate_merge(c, p, t, rules):
  blocking_obligations(c) = {ob ∈ obligations(c) : ob.phase = pre_merge}
  Open iff ∀ ob ∈ blocking_obligations(c): result(ob) = Pass
        ∧ ∀ r ∈ rules: apply(r, c, t)
        ∧ re_evaluation_status(c) ≠ StaleClaim
  Blocked otherwise

gate_release(candidate_release, p, t, rules):
  blocking_obligations(release) = {ob ∈ obligations(release) : ob.phase ∈ {pre_merge, pre_release}}
  Open iff ∀ ob ∈ blocking_obligations(release): result(ob) = Pass
                  ∧ ∀ r ∈ rules: apply(r, release, t)
                  ∧ re_evaluation_status(release) ≠ StaleClaim
                  ∧ attestation_evidence_chain(release) ⊨ release-policy
  Blocked otherwise

post_release_monitor(c, t) → Stream[AssuranceGap]:
  monitoring_obligations(c) = {ob ∈ obligations(c) : ob.phase = post_release}
  ∀ ob ∈ monitoring_obligations(c):
    if ¬result(ob) ∧ ob.due_date(t) ≤ now:
      emit AssuranceGap {kind: PostReleaseViolation, ob, evidence}

remedies(pre_merge_block) = {add_trailer_ref, create_sibling_yaml, downgrade_mode}
remedies(pre_release_block) = {supersede_decision_per_impact_list, add_release_attestation}
remedies(post_release) = (informational only, no block)
exit ≠ 0 ∧ remedies ≠ ∅                   [I14]
```

---

## §16. Substrate

```
substrate: CI → 𝓢
substrate(ci) = parse(ci.substrate-declaration)
substrate_fingerprint(ci) = sha256(kernel.ver || ocaml.ver || dep.digests)

∀ ci: substrate(ci) canonicalized at startup, frozen for duration
∀ a ∈ Attestation: a.substrate_fingerprint = substrate_fingerprint(producer(a))
```

---

## §17. Inline axiom change

```
axiom-transition: Axiom × TransitionKind
TransitionKind = revision | addition | removal

axiom-revision(c, A):
  required: {old_sha, new_sha, counterexample, impact-list, trailer_ref}
  old_sha = sha256(axiom_file_at(parent(c)))
  new_sha = sha256(axiom_file_at(c))
  trailer_ref: axiom:A@<old_rev>

axiom-addition(c, A_new):
  required: {axiom_id, statement, counterexample,
             references_to_existing_axioms, index_update_in_same_commit,
             no_contradicts_with_existing_axioms}

axiom-removal(c, A): requires successor axiom declaration, A3-protected

re_evaluate: Decision × AxiomRevision → ReEvaluationStatus
re_evaluate(d, A_new):
  ∀ ob ∈ d.obligations:
    - ob.claim references A_old.forbidden_patterns → StaleClaim
    - ob.acceptance.verifier is test-style → run, return Compatible on Pass
    - ob.acceptance.verifier is manual-style → Inconclusive

∀ axiom-revision c:
  ∀ impact-list(d): re_evaluation_status(d) = re_evaluate(d, A_new)
  verdict(c) = max_verdict across impact-list(d)
  max_verdict: Compatible < Inconclusive < StaleClaim

  Compatible only    → axiom change allowed
  StaleClaim exists  → gate = Blocked + remediation list per affected decision
  Inconclusive only  → axiom change allowed + follow-up review list

impact-list(d) = {d' : A ∈ d'.referenced_axioms ∨ A ∈ transitive_referenced_axioms(d')}
```

---

## §18. Time-budget

```
time: Session × Agent → ExecutionLog
time(s, a) = ⟨scale, value, observed_at, observed_by=a⟩

scale ∈ {WallClockMinutes, TokenBudget, StepCount}
∀ session: time recorded before commit ∧ reference-class declared
```

---

## §19. 14 invariants

```
(I1)  ∀ c, p, t₁=t₂: gate(c, p, t₁, ∅) = gate(c, p, t₂, ∅)
(I2)  ∀ ref: resolve(ref) ≠ ∅
(I3)  ∀ rel(r, x, y): x.kind ∈ Src(r) ∧ y.kind ∈ Tgt(r)
(I4)  ∀ a: (kind, id, rev) globally unique
(I5)  ∀ rev accepted: digest(rev) = const
(I6)  ∀ rev: parents(rev) < rev ∧ acyclic(revisions)
(I7)  ∀ D₁, D₂: supersedes(D₁, D₂) acyclic
(I8)  ∀ a ∈ Attestation: a names exact decision_sha + materials_𝓓
(I9)  Δ materials_𝓓 ⇒ stale(a) (unless method(a) ⊢ digest-indep)
(I10) Pass ≠ Unknown ≠ Waived ≠ Reviewed ≠ Observed
(I11) ∀ w ∈ Waiver: scope(w) ⊆ scope(gap) ∧ revs(w) ⊆ revs(gap)
(I12) ∀ protected τ: authorized_by(previous(P))
(I13) ∀ MUST ∈ kernel: ∃ f⁺, f⁻ ∈ Fixtures
(I14) gate = Blocked ⇒ exit ≠ 0
```

---

## §20. Kernel rules

```
𝓒-rule ⊂ 𝒱_ideal_3.2
initially: 𝓒-rule = {PreTemporalPrecedence, CoCommitDecision, CoCommitFixture}

apply(PreTemporalPrecedence, c, t) ≔
  mode(c) ∈ {tiny, light}
  ⊕ has_sibling_yaml(c)
  ⊕ (∃ ref ∈ trailer(c): ref matches "decision:<id>@<rev>?" ∧ resolve(ref, parent(c)) ≠ ∅)

apply(CoCommitDecision, c, t) ≔
  c.files ∩ {lib/**, bin/Mathc.ml, spec/**, schemas/**, axioms/**} = ∅
  ⊕ ∃ d ∈ tree(parent(c)) ∪ tree(c):
       kind(d) ∈ {decision, axiom} ∧ basename(d) referenced by trailer(c)

apply(CoCommitFixture, c, t) ≔
  ∀ ob ∈ obligations(c):
    ob.acceptance.verifier is fixture OR ob.acceptance.review is filled

add-rule: Decision → 𝓒-rule
add-rule(d) requires:
  - mode(d) ≥ strict
  - 1 positive + 1 negative conformance fixture
  - counterexample with strongest objection
  - reference to axiom that justifies the rule
```

---

## §21. Friction envelope

```
friction(c) = friction_user(c) ⊕ friction_kernel_dev(c)

friction_user(c) ≔ max(0, cost_user(commit-with-protocol(c)) - cost_user(plain-commit(c)))
friction_kernel_dev(c) ≔ amortized over all users, O(1) per release cycle

cost_user(c) = body_lines(c) + trailer_lines(c) + yaml_new_lines(c)
             + rebuttal_lines(c) + context_lines_read(c)
             where context_lines_read ≤ 1100 for users adopting 3.2

cost_kernel_dev(c) = cost_user(c) + axiom_re_evaluate_cost(c)
                   + 3600_lines_kernel_dev_context (amortized per release)

friction_user_envelope:
  tiny:        ≤ 0       (commit message, body classification line, no trailer)
  light:       ≤ 10      (body {commitment, counterexample})
  standard:    ≤ 60      (body 30 + trailer 1 + yaml 0-30)
  strict:      ≤ 130     (body 80 + trailer 1 + yaml 0-50 + rebuttals 0-50)
  exhaustive:  ≤ 300     (body 200 + trailer 1 + yaml 0-100 + rebuttals 0-100 + formal)

friction_kernel_dev_envelope (constant per release, not per commit):
  ≤ 3600_lines_once_per_release_cycle

vs baselines:
  ADR:                 ~100 lines markdown
  code review (good):  ~30 min wall-clock
  good CI:             ~50 lines yaml + 5 min/run
  rebuttal dialog:     ~30 lines in PR comments

ideal_3.2(c) friction_user     ≤ baseline friction  for mode(c) ≤ standard
ideal_3.2(c) friction_user     ≤ 1.5 × baseline       for mode(c) ∈ {strict, exhaustive}
ideal_3.2(c) friction_kernel_dev ≤ baseline_once     per release cycle
```

---

## §22. Quality dimensions

```
quality(protocol 𝒫) for project P = min over dimensions:
  correctness          : ∃ obligations, all attested pass
  explicitness         : commitment(c) recoverable from history(c)
  recovery             : ∀ irreversible(c) : recovery(c) declared
  coordination         : multi-agent consensus (rebuttal binding)
  auditability         : attestation(c) immutable, queryable
  evolution            : axiom-changes tracked, impacted decisions re-evaluated
  zero-friction-user   : tiny/light commits have zero user friction
  no-retrofit          : kernel/protected commits cannot be post-hoc rationalized
  cross-cutting        : security/perf concerns surface via rebuttal mechanism
  substrate-honesty    : cross-CI evaluation includes substrate fingerprint
  sha-consistency      : dual authoring (inline + sibling) cannot drift
  transitive-policy    : policies extend via data flow edges
  axiom-safety         : axiom changes gate on re-evaluation oracle
  applicability-fit    : protocol's friction ≤ protocol's value for this project

applicability-fit(P) =
  | True   if applicability_3.2(P) > 0    (per §28)
  | False  if applicability_3.2(P) ≤ 0

∀ project P adopting 3.2: applicability-fit(P) = True
∀ project P not adopting 3.2: applicability-fit(P) requires explicit rationale

improvements vs baseline:
  correctness          : +30%
  explicitness         : +50%
  recovery             : +100%
  coordination         : +∞
  auditability         : +200%
  evolution            : +150%
  zero-friction-user   : preserved
  no-retrofit          : enforced
  cross-cutting        : enforced
  substrate-honesty    : enforced
  sha-consistency      : enforced
  transitive-policy    : enforced
  axiom-safety         : enforced
  applicability-fit    : explicit per project
```

---

## §23. Kernel signature

```
Kernel = ⟨infer, mode, compose, attest, gate, trust, apply, re_evaluate, transition⟩

infer:           𝓒 × 𝓜 → P(Obligation)
mode:            𝓒 → 𝓜
compose:         𝓒 → P(Obligation)
attest:          𝓒 → P(Attestation)
gate:            Change × Policy × 𝓣 × 𝓒-rule → Gate
trust:           𝓐 × ObligationDomain → 𝓣
apply:           𝓒-rule × 𝓒 × 𝓣 → 𝓑
re_evaluate:     Decision × AxiomRevision → ReEvaluationStatus
transition:      Axiom × TransitionKind → AxiomTransition

total cost per commit:
  O(infer)        = O(|c.files| · path_classification_cost)
  O(mode)         = O(1)
  O(compose)      = O(|c.files| + |data_flow_targets*(c.files)| · policy_lookup)
  O(attest)       = O(|obligations(c)| · verifier_cost)
  O(gate)         = O(|attestations(c)| + |𝓒-rule| · apply_cost)
  O(trust)        = O(history(agent, domain))
  O(re_evaluate)  = triggered only on axiom-revision
  O(transition)   = O(1)

∀ c: total_cost_user(c) ≤ baseline_cost_user(plain_commit(c)) + ε_user
∀ c: total_cost_kernel_dev(c) ≤ baseline_cost_kernel_dev(plain_commit(c)) + ε_kernel_dev
```

---

## §24. Adoption path

```
adoption(P) = choose_path(P, applicability_3.2(P))
where choose_path returns one of:
  Path A: full 3.2 (kernel binary + full methodology)
  Path C: no math-coding (regular ADR + good CI)

Path A — full 3.2:
  Step 1: download kernel binary from releases (Linux/macOS/Windows × x86_64/aarch64)
  Step 2: read USAGE.md + AGENTS.md + axioms/ (~1100 lines)
  Step 3: copy decisions/decision.yaml template to user's project
  Step 4: enable mathc gate as blocking CI step
  Step 5: populate attestation store from CI logs
  friction_user: 1100_lines_once + per-commit as in §21
  friction_kernel_dev: amortized, shared with all users

Path C — no math-coding (regular ADR):
  Step 1: standard ADR practice (one markdown file per decision)
  Step 2: counterexample as prose paragraph in ADR
  Step 3: PR review for verdict (no mathc gate)
  Step 4: CI logs as evidence (no attestation store)
  friction: 0 (regular practice)

∀ project P: choose_path(P) based on applicability_3.2(P) per §28
  applicability > 0           → Path A (full 3.2)
  applicability ∈ [low, ~0]   → Path C (no math-coding)
  applicability ≈ 0           → Path C (no protocol needed)

preserves (from 3.1):
  14 constitution invariants
  5 axioms A0-A4
  5 modes
  dual authoring model
  CI-declared substrate
  append-only attestation store
  auto-inferred obligations
  counterexample as dialog
  rebuttal mechanism (hybrid)
  per-domain trust dynamics
  re-evaluation oracle
  axiom transition kinds

adds (from §28-§30):
  applicability envelope
  two-tier cognitive model
  binary distribution as architectural property
```

---

## §25. Equivalence with 3.1

```
π: 𝒱_ideal_3.2 → 𝒱_ideal_3.1

π(decision(c) with sha-match) = yaml_decision(c) + body_section(c)
π(infer(c)) = obligation list (without transitive_paths)
π(attest(c) with substrate_fingerprint) = attest_v3.1(c) + substrate_fingerprint
π(axiom-revision c) = axiom-change c
π(rebuttals(c)) = body_section_rebuttals_v3.1 (loses information)
π(trust(agent, domain)) = trust(agent) (loses granularity)
π(apply(PreTemporalPrecedence, c, t))  ⟺  apply_v3.1(c, t)
π(compose(c) without transitive_paths) = infer_v3.1(c)

kernel composition:
  K_3.1(π(c), π(p), t) = π(K_3.2(c, p, t, 𝓒-rule_3.1))
  K_3.2 extends 3.1 with: CoCommitDecision, CoCommitFixture, re_evaluate, transition, transitive_paths

3.2 is strict superset of 3.1:
  ∀ c: 3.1-verdict(c) ⇒ 3.2-verdict ∈ {same, more restrictive}
```

---

## §26. Universal property

```
∀ protocol 𝒫 satisfying 14 invariants:
  ∃! morphism η: 𝒫 → 𝒱_ideal_3.2 such that
    friction_user(𝒫(c)) ≥ friction_user(ideal_3.2(c))
    quality(𝒫) ≤ quality(ideal_3.2)
    𝓒-rule(𝒫) ⊆ 𝓒-rule(3.2)
    ∀ r ∈ 𝓒-rule(𝒫): apply(r, c, t)  ⟺  apply(η(r), c, t)
    ∀ D ∈ Decision(𝒫): D has counterexample if mode(D) ≠ tiny

η constructed by:
  η(decision file)             ↦ decision_text + sibling_yaml (sha-match)
  η(obligation list)           ↦ infer(diff) + transitive (data flow)
  η(attestation)               ↦ ci_run output + substrate_fingerprint + env_class_level
  η(rebuttal dialog)           ↦ rebuttals/<sha>.yaml + forge mirror + body opening
  η(substrate decl)            ↦ CI substrate block + substrate_fingerprint
  η(trust policy)              ↦ trust(agent, domain) dynamics with non-binding distinction
  η(multi-policy)              ↦ policy(p) + transitive_paths (data flow) + union
  η(axiom change)              ↦ transition(revision|addition|removal) + re_evaluate oracle
  η(kernel rule)               ↦ apply(rule, c, t) in 𝓒-rule
  η(temporal order rule)       ↦ PreTemporalPrecedence + CoCommitDecision + CoCommitFixture
  η(sha consistency)           ↦ body_sha = yaml_sha validation
  η(applicability envelope)    ↦ applicability(P, 𝒫_3.2) per §28
  η(binary distribution)       ↦ distribution_property per §30
```

---

## §27. Friction-zero theorem

```
Theorem: ∀ c ∈ Commits, friction_user(ideal_3.2(c)) ≤ friction_user(plain-commit(c)) + ε

where ε_user = O(mode(c) · sibling_yaml_size)
       + O(rebuttal_yaml_size)     if strict+
       + O(|impact-list|)          if axiom-revision
       + O(|data_flow_targets|)    if multi-policy commit

Proof sketch:
  tiny mode:       friction_user = 0
  light mode:      friction_user ≤ 10
  standard mode:   friction_user ≤ 60
  strict mode:     friction_user ≤ 130
  exhaustive mode: friction_user ≤ 300

  ∴ friction_user_ideal_3.2 ≤ friction_user_baseline    for mode(c) ≤ standard
  ∴ friction_user_ideal_3.2 ≤ 1.5 × friction_user_baseline    for mode(c) ∈ {strict, exhaustive}
  ∴ axiom A4 Process preserved via PreTemporalPrecedence + CoCommitDecision
  ∴ multi-agent rebuttals structured via rebuttals/<sha>.yaml + forge mirror
  ∴ multi-policy composition via union + transitive
  ∴ axiom changes via transition kinds + re_evaluate oracle
  ∴ multi-CI attestations via substrate_fingerprint + env_class lattice + wait-for-all
  ∴ per-domain trust via trust(agent, domain) dynamics
  ∴ dual authoring consistency via sha-match validation
  ∴ honest uncertainty principle: Pass ≠ Fail ≠ Inconclusive ≠ Waived (per §0)
  ∴ 3.2 is strict superset of 3.1 (more checks, never less restrictive)
  ∴ applicability-fit (per §28) determines adoption choice per project   □
```

---

## §28. Applicability envelope

```
applicability(project P, protocol 𝒫) ≔ value(P, 𝒫) - friction_user(P, 𝒫)

value(P, 𝒫) =
  | +∞ if P ∈ regulatory_audit_required(P)
  | high    if P ∈ multi_agent_ai_assisted(P)
  | medium  if P ∈ long_lived_critical_infrastructure(P) ∧ |team(P)| > 1
  | low     if P ∈ solo_or_small_team(P) ∧ ¬multi_agent_ai_assisted(P)
  | ~0      if P ∈ prototype_or_throwaway(P)

regulatory_audit_required(P) ≔ P touches medical|financial|aviation|critical_infra
multi_agent_ai_assisted(P) ≔ |agents(P)| ≥ 2 ∧ agents coordinate on P
long_lived_critical_infrastructure(P) ≔ expected_lifetime(P) ≥ 5 years ∧ |team(P)| ≥ 3
prototype_or_throwaway(P) ≔ P is MVP / spike / experimental code

applicability_envelope:
  applicability ≥ +∞      → Path A: full 3.2 (kernel binary + all obligations)
  applicability ≥ high    → Path A: full 3.2 (kernel binary + obligations)
  applicability ≥ medium  → Path A: full 3.2, accept higher friction
  applicability ∈ [low, ~0] → Path C: no math-coding, regular ADR
  applicability ≈ 0       → Path C: no protocol needed

∀ project P: applicability(P, 𝒫_3.2) > 0 ⟹ P is candidate for 𝒫_3.2

non-candidates (applicability ≤ 0):
  - prototype / MVP / spike
  - throwaway tools
  - learning exercises
  - 1-day hackathon output

candidates (applicability > 0):
  - regulatory audit environments
  - multi-agent AI-assisted development
  - long-lived critical infrastructure
  - teams of ≥3 on stable projects
```

---

## §29. Two-tier cognitive model

```
protocol has two consumer populations:
  U = {users of 𝒫 on their projects}              [mainstream, |U| ≫ 1]
  K = {kernel developers modifying 𝒫 itself}        [rare, |K| ≪ |U|]

documentation_scope(consumer A):
  A ∈ U: reads USAGE.md + AGENTS.md + axioms/ + PACKAGES.md ≈ 1100 lines, 5 modes, 1 schema
  A ∈ K: reads all of U's docs + OCAML_BEST_PRACTICES.md + spec/
         ≈ 3600 lines, 31 sections (§0-§30), 14 invariants

friction(c) = friction_user(c) ⊕ friction_kernel_dev(c)

friction_user(c) =
  per-commit friction for users adopting 3.2
  = 0 for tiny, ≤ 10 for light, ≤ 60 for standard, ≤ 130 for strict, ≤ 300 for exhaustive

friction_kernel_dev(c) =
  constant cost of maintaining kernel itself
  amortized across |U|
  = O(kernel_changes) per release, NOT per commit

∀ users A ∈ U: friction_user(A) is the actual friction they experience
∀ developers D ∈ K: friction_kernel_dev(D) is amortized over |U|

implication: most projects have U ∩ K = ∅
            kernel developers (5 people) maintain for users (1000s of projects)
            friction_kernel_dev per release << friction_user per commit × |commits|
```

---

## §30. Binary distribution as architectural property

```
distribution: Kernel → {platform-binary × sha256}
  platforms = {linux-x86_64, linux-aarch64, darwin-x86_64, darwin-aarch64, windows-x86_64}
  each release publishes 5 binaries

∀ user A ∈ U: A obtains kernel via binary_download(A) ⟹ A.requires(nix) = False
∀ developer D ∈ K: D obtains kernel via source_build(D) ⟹ D.requires(nix, ocaml, dune) = True

∀ U, K: U ∩ K = ∅    [disjoint populations]

adoption_cost(U) = binary_download_cost + 1100_lines_user_doc
maintenance_cost(K) = source_build_cost + 3600_lines_kernel_doc + OCaml_toolchain

distribution_property:
  ∀ users A ∈ U: friction_user(A, c) ≤ friction_baseline(A, c) for mode(c) ≤ standard

distribution requirements:
  - kernel must compile to native binary (not require runtime interpreter)
  - kernel must ship as portable artifact (no nix-store paths in dependencies)
  - kernel must be reproducible (same source → same binary hash)

anti-property (forbidden):
  - require OCaml compiler on user machines
  - require nix-store paths in binary dependencies
  - require dune installation for users
  - bind kernel to single OS or architecture

∀ future kernel changes: maintain distribution_property
```

---

## Summary

| Section | Topic | Status vs 3.1 |
|---|---|---|
| §0 | Goal + Honest Uncertainty | extended |
| §1 | Universal sets | extended (binary platforms, epistemic markers) |
| §2 | Risk function | clarified (impact vs risk, mode_floor) |
| §3 | Authoring model | same (dual) |
| §4 | Inline authoring | parser-enforced |
| §5 | Trailer mechanism | drop-if-sibling |
| §6 | Sibling YAML | same |
| §7 | Decision entity | +5 epistemic markers, +8 relations, +state, +body_sha/yaml_sha |
| §8 | Auto-inferred obligations | extended (cli/subcommand, axioms/**) |
| §9 | Multi-policy | +transitive via data flow |
| §10 | Rebuttal | hybrid (sibling + forge mirror) |
| §11 | Counterexample | same |
| §12 | Trust | per-domain |
| §13 | Auto-attestation | +substrate_fingerprint, +env_class_level |
| §14 | Multi-CI aggregation | new |
| §15 | Gate verdict | +3 obligation phases, +3 gate types |
| §16 | Substrate | +substrate_fingerprint |
| §17 | Axiom change | +transition kinds, +re_evaluate oracle |
| §18 | Time-budget | same |
| §19 | 14 invariants | preserved |
| §20 | Kernel rules | +CoCommitDecision, +CoCommitFixture |
| §21 | Friction envelope | user/kernel-dev split |
| §22 | Quality dimensions | +applicability-fit |
| §23 | Kernel signature | same |
| §24 | Adoption path | two paths (full/no), no 3.2-L |
| §25 | Equivalence with 3.1 | new |
| §26 | Universal property | extended |
| §27 | Friction-zero theorem | extended |
| §28 | Applicability envelope | new |
| §29 | Two-tier cognitive model | new |
| §30 | Binary distribution | new |
