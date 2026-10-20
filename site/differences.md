# Differences — how mathcoding compares

> **What this page is.** A point-by-point comparison of mathcoding
> with the methodologies that look most like it: specification-driven
> development, decision records, domain-driven design, behaviour-driven
> development, formal methods, architecture frameworks, and the
> assurance-maturity models. Each section names what the other
> methodology does well and what mathcoding adds, refuses, or changes.

## The one-line answer

**mathcoding is an assurance protocol, not a specification language
and not a documentation system.** Most methodologies describe what
should be built or how the team should work. mathcoding binds every
change to a written commitment, a list of obligations, a bounded
attestation, and a verdict that is produced by a deterministic
kernel. Where other methodologies can drift, mathcoding cannot —
the kernel either passes the change or it does not, and the
verdict cites the rule, the subject, the cause, and a remedy.

## Three properties no other methodology combines

mathcoding is not a sum of features from other methodologies. It is
a specific combination of three properties that no other methodology
offers together:

1. **Bounded evidence.** Every claim is bounded by subject,
   obligation, inputs, environment, implementation digest, method,
   and time. A claim without bounds is not a claim; it is a
   statement of intent.
2. **Honest uncertainty.** Absence of evidence is `Inconclusive`,
   not `Pass`. `Pass ≠ Fail ≠ Inconclusive ≠ InfrastructureError`.
   `Waived ≠ Pass`. `Reviewed ≠ Observed`. The five source classes
   (`declared ≠ derived ≠ attested ≠ reviewed ≠ observed`) cannot
   be collapsed.
3. **Self-application.** The rules that govern mathcoding govern
   mathcoding itself. A change to the constitution, the schemas,
   the kernel, or the gate rules is a *protected policy transition*
   and requires a decision under the prior policy, a strongest
   countercase, positive + negative fixtures, a migration path, a
   recovery path, prior authorization, and a verdict diff.

If a methodology offers one of these, mathcoding inherits that
piece. If it offers two, mathcoding tightens the third. If it
offers all three, the methodology is either mathcoding or a
descendant of it.

## Comparison at a glance

| Methodology | What it asserts | What mathcoding adds |
|---|---|---|
| TDD | Tests precede code | Tests verify obligations, not behaviours; obligations are versioned and checkable |
| BDD | Behaviour expressed in Given/When/Then | Behaviour is not enough; the kernel asks who observed it and when |
| DDD | Code mirrors the domain | The domain model is one kind of decision; the kernel gates changes to it |
| FDD | Features are the planning unit | A feature is a decision; the obligation is what the feature must preserve |
| MDD / MDA | Models generate code | Models are evidence, not the source of truth; the source of truth is the decision |
| Spec-Driven Development | Specs precede code | A spec without an attestation is a wish; mathcoding closes the loop |
| ADR (Nygard / MADR) | Decisions are recorded as Markdown | The record is a YAML packet with a schema, an obligation, and a verifiable verdict |
| arc42 | Twelve sections of architecture documentation | Each section is an optional obligation; nothing is required unless the active policy requires it |
| C4 Model | Diagrams at four levels of zoom | Diagrams are evidence under `attested`; the obligation is a property the diagram must preserve |
| Living Documentation | Documentation is generated from code | Living documentation is one source class; mathcoding also admits the others |
| Specification by Example | Examples pin the contract | Examples are one kind of attestation; the contract is the obligation, the example is the witness |
| OpenAPI | API is described in machine-readable form | The description is one obligation; the other obligations cover behaviour, security, freshness |
| Design by Contract | Pre-/post-conditions on every call | Contracts are obligations on functions; mathcoding adds obligations on decisions, attestations, and waivers |
| Formal Methods (TLA+, Coq, …) | Properties proved in a proof assistant | A proof is one attestation kind; the obligation may be review-class, test-class, or observation-class |
| TOGAF | Enterprise architecture framework | mathcoding is the gate; TOGAF describes the meta-model the gate reads |
| ISO/IEC/IEEE 42010 | Architecture description standard | 42010 names the concerns; mathcoding binds each concern to an obligation and a verifier |
| Team Topologies | Organisational structure for software | Team Topologies names the cognitive load; mathcoding names the per-change friction that load produces |
| SAFe | Scaled agile process | SAFe names the ceremonies; mathcoding binds each ceremony's artefact to a verifier and an attestation |
| OWASP SAMM | Software assurance maturity model | SAMM evaluates the organisation; mathcoding evaluates every change |
| NIST SSDF | Secure software development practices | SSDF names the practices; mathcoding makes each practice checkable per change |

The table is a summary. The sections below expand each row.

## 1. TDD — Test-Driven Development (Kent Beck, 2002)

TDD writes a failing test, makes it pass, then refactors. The
discipline is local to a unit; the test is the contract; the
refactor is the freedom to change the implementation without
breaking the contract.

**What mathcoding inherits:** the test-as-evidence idea. A
mathcoding `attestation` of `kind: test` is, at the protocol level,
a TDD test that has been promoted to a first-class artifact: it
carries a producer identity, a method, a digest of the
implementation, and a verdict.

**What mathcoding adds:** the test is bound to a specific
`obligation`, not to a behaviour. The obligation names the
*property* the test must preserve; the test names the *check* the
kernel runs. If the test passes but the obligation is not named in
any active decision, the test is not part of the assurance loop —
it is an internal artefact. TDD treats every test as a contract;
mathcoding requires the contract to be declared in a decision.

**What mathcoding refuses:** the implicit claim that "the tests
pass" means "the system is correct". In mathcoding, `pass` is the
verdict of one obligation; a green test suite is a witness, not a
verdict.

## 2. BDD — Behavior-Driven Development (Dan North, 2003)

BDD expresses behaviour in `Given / When / Then` form, with the
scenario written in a natural-language subset the team shares with
the business. The discipline is the scenario; the executor is
Cucumber, SpecFlow, or Behave.

**What mathcoding inherits:** the scenario-as-specification idea.
A mathcoding obligation can be expressed as a `Given/When/Then`
scenario in a `verifier: bdd-scenario` field. The kernel accepts
the scenario, pairs it with the obligation, and treats the
scenario's outcome as the obligation's verdict.

**What mathcoding adds:** the scenario's outcome is one of five
values, not two. `Pass`, `Fail`, `Inconclusive`, `InfrastructureError`,
and `Waived` are distinct; a passing scenario with no executor
run is `Inconclusive`, not `Pass`. BDD confuses "the scenario
passes when run" with "the behaviour is verified"; mathcoding
keeps the two apart.

**What mathcoding refuses:** the assumption that a business-readable
scenario is a verification. Scenarios are easy to read and hard to
verify; mathcoding treats them as one attestation kind, with the
usual `producer_identity` and `environment` bounds.

## 3. DDD — Domain-Driven Design (Eric Evans, 2003)

DDD models the code on the domain: bounded contexts, ubiquitous
language, aggregates, domain events. The discipline is
*conversational*; the artefacts are the code, the diagrams, and
the glossary.

**What mathcoding inherits:** the discipline of naming things so
the kernel and the humans agree. A mathcoding `decision` carries
an `intent` and a `commitment`; the two are written in the team's
ubiquitous language.

**What mathcoding adds:** the kernel does not know the domain; it
knows the decision. The bounded context is one decision; the
ubiquitous language is a property the decisions share; the
aggregate is a path namespace the gate protects. DDD names the
shape; mathcoding enforces the gate on the shape.

**What mathcoding refuses:** the assumption that a well-modelled
domain is a verified system. A correct model with no obligations
is a wish; a correct model with obligations and no attestations
is a hypothesis. mathcoding asks for the third artefact.

## 4. FDD — Feature-Driven Development (De Luca & Coad, 1997)

FDD builds the system feature by feature, with each feature scoped,
designed, and built by a small team. The discipline is the
feature list; the artefact is a working increment.

**What mathcoding inherits:** the feature as a unit of planning.
A mathcoding `decision` may declare a `feature_id`; the obligation
is the property the feature must preserve.

**What mathcoding adds:** the feature carries a `verifier` and a
`verdict`. FDD tracks progress; mathcoding tracks verification.
The kernel does not measure velocity; it measures obligation
verdicts.

**What mathcoding refuses:** the implicit claim that a built
feature is a verified feature. The build is a `change`; the
verification is an `attestation`; the two are distinct kinds.

## 5. MDD / MDA — Model-Driven Development / Model-Driven Architecture (OMG, 2001)

MDD/MDA generates code from platform-independent models (PIMs)
and platform-specific models (PSMs). The discipline is the model;
the artefact is generated code.

**What mathcoding inherits:** the model as a first-class artefact.
A mathcoding decision can declare a `model` field; the model is
one of the substrates the kernel digests.

**What mathcoding adds:** the model is evidence, not the source
of truth. The source of truth is the decision; the model is one
attestation kind. If the model and the code disagree, the code
loses (because the obligation is a property the code must hold,
not a property the model must hold). MDD/MDA treats the model as
the source; mathcoding treats the model as one witness.

**What mathcoding refuses:** the assumption that generated code is
verified code. The generator is a method; the generated artefact
is a digest; the verification is a separate attestation.

## 6. Spec-Driven Development (GitHub Spec Kit, AWS Kiro, 2025)

Spec-Driven Development (SDD) is the 2025 industry term for
methodologies that begin with a specification: a markdown file
that describes the feature, the acceptance criteria, and the
test plan. GitHub Spec Kit, AWS Kiro, GitLab Duo, and several
commercial coding agents adopt this shape. The discipline is the
spec; the artefact is the spec plus the generated code.

**What mathcoding inherits:** the spec-as-source-of-truth idea. A
mathcoding decision's `commitment` is, in the protocol-level
sense, a spec — a falsifiable claim about a property of a
change.

**What mathcoding adds:** the spec is bound to a *verifier* and a
*verdict*. SDD produces a spec and a code change; the spec is
verified by tests, but the tests are not bound to the spec by
the methodology. A spec can be honoured only in the breach; a
mathcoding obligation cannot — the kernel checks the attestation
on every gate.

**What mathcoding refuses:** the implicit claim that a spec is a
verification. In SDD, "the spec is written" is a milestone; in
mathcoding, "the spec is written" is the start of the loop, not
its end. A spec without a passing attestation is an
`Inconclusive` obligation, not a `Pass`.

**This is the closest living competitor.** SDD is the same
shape without the bounded-evidence discipline. If you read SDD
and think "this would be better with attestation kinds, expiry
on waivers, and a deterministic gate", you have read the
mathcoding delta.

## 7. ADR — Architecture Decision Records (Michael Nygard, 2011; MADR, 2018)

ADR records each significant architectural decision as a short
Markdown file with `Context`, `Decision`, `Consequences`, and
`Status`. MADR extends the format with options, decision drivers,
and a confirmation process. The discipline is the record; the
artefact is the file.

**What mathcoding inherits:** the decision-as-artifact idea. A
mathcoding `decision` is the ADR shape with a schema, a
mandatory obligation list, and a deterministic gate. `mathc
import-adr` is a first-class tool that converts MADR and
adr-tools files into mathcoding packets.

**What mathcoding adds:** the decision carries `obligations` and
`attestations`. The kernel checks every decision against its
obligations on every gate; a decision with no obligation is
informational, not blocking; a decision with an obligation and
no attestation is `Inconclusive`. ADR is a notebook; mathcoding
is a notebook with a checker.

**What mathcoding refuses:** the assumption that a written ADR is
a verified ADR. A `Context / Decision / Consequences` block is a
declaration; the kernel reads declarations and asks "what is the
evidence that the declaration still holds?". The answer is the
attestation.

**This is the closest structural competitor.** ADR is the
upstream of mathcoding. Where ADR is human-readable and
untyped, mathcoding is machine-readable, schema-validated, and
gate-checked. Where ADR's "Status: superseded" is a string,
mathcoding's `supersedes` is a relation on the revision DAG
that the kernel traverses.

## 8. arc42 — Twelve sections of architecture documentation (Dr. Gernot Starke, Peter Hruschka)

arc42 is a template for software-architecture documentation: twelve
sections from `Introduction and Goals` to `Risks and Technical
Debts`. The discipline is the template; the artefact is the
filled-in document.

**What mathcoding inherits:** the section-as-namespace idea. A
mathcoding decision can declare an `arc42_section`; the obligation
is the property that section must preserve.

**What mathcoding adds:** the section is not required unless the
active policy requires it. arc42 ships twelve sections; mathcoding
ships zero sections and asks the active policy to declare which
ones the project cares about. The empty-by-default posture is the
A0 separation axiom in action: kinds are distinct, and the
documentation is a different kind from the decision.

**What mathcoding refuses:** the assumption that filling the
template is the verification. The template is a structure; the
verification is a verifier. mathcoding replaces the structure with
a check.

## 9. C4 Model — Context, Containers, Components, Code (Simon Brown, 2011)

C4 is a hierarchical diagram scheme: system context, containers,
components, code. The discipline is the diagram; the artefact is
the diagram set.

**What mathcoding inherits:** the level-of-zoom idea. A mathcoding
decision can declare a `c4_level`; the obligation is the property
the diagram at that level must preserve.

**What mathcoding adds:** the diagram is an `attestation`, not a
`decision`. A diagram can attest that the system has a specific
shape; the decision declares the shape, the obligation names the
property, and the diagram is the witness. C4 conflates the shape
with the witness; mathcoding separates them.

**What mathcoding refuses:** the assumption that a current diagram
is a verified diagram. A diagram ages; the obligation does not.
A `valid_until` field on the obligation is what makes the diagram
honest over time.

## 10. Living Documentation (Cyrille Martraire)

Living Documentation is the practice of generating documentation
from the code: tests, types, examples, scenarios. The discipline
is the generator; the artefact is the documentation.

**What mathcoding inherits:** the documentation-as-byproduct idea.
A mathcoding attestation can carry a `producer: living-doc`
field; the living documentation is one attestation kind.

**What mathcoding adds:** living documentation is one of five
source classes, not the only one. `declared` (advisor), `derived`
(generator), `attested` (test), `reviewed` (human), `observed`
(runtime) are distinct; mathcoding admits all five and refuses to
promote a `derived` claim to an `observed` claim without an
artifact.

**What mathcoding refuses:** the assumption that a generated
document is a verified document. The generator is a method; the
output is a digest; the verification is a separate attestation.

## 11. Specification by Example (Gojko Adzic)

Specification by Example (SBE) writes the contract as examples:
inputs, outputs, edge cases. The discipline is the example; the
artefact is the executable specification.

**What mathcoding inherits:** the example-as-specification idea. A
mathcoding obligation can be expressed as a set of examples in
`acceptance.examples`; the kernel accepts the examples and treats
each one as a fixture.

**What mathcoding adds:** an example is one attestation kind, not
the only one. SBE treats the example as the verification;
mathcoding treats the example as the witness and the obligation
as the contract. The two are distinct kinds.

**What mathcoding refuses:** the assumption that a passing example
set is a verified system. The example set is bounded by inputs;
the obligation is not. A change that preserves the example set
but breaks a property the obligation names is `Fail` in
mathcoding and `Pass` in SBE.

## 12. OpenAPI — Machine-Readable API Specification

OpenAPI describes an HTTP API in YAML or JSON: paths, methods,
parameters, responses, schemas. The discipline is the
description; the artefact is the spec file and the generated
client/server stubs.

**What mathcoding inherits:** the machine-readable contract idea.
A mathcoding decision can declare an `openapi_spec`; the
obligation is the property the API must preserve.

**What mathcoding adds:** the OpenAPI spec is one obligation; the
other obligations cover behaviour, security, freshness, and
backward compatibility. OpenAPI describes the shape; mathcoding
binds the shape to a verifier and a verdict. A green OpenAPI
lint is an `Inconclusive` obligation, not a `Pass` — the
contract may be satisfied while the behaviour is not.

**What mathcoding refuses:** the assumption that a generated
client is a verified client. The generator is a method; the
generated artefact is a digest; the verification is a separate
attestation.

## 13. Design by Contract (Bertrand Meyer, Eiffel, 1986)

Design by Contract (DbC) attaches pre-conditions, post-conditions,
and invariants to every operation. The discipline is the contract;
the artefact is the code with the contracts inline.

**What mathcoding inherits:** the contract-as-property idea. A
mathcoding obligation can be expressed as a `dbc:precondition` or
`dbc:postcondition` field; the kernel accepts the contract and
treats the runtime check as the verifier.

**What mathcoding adds:** the contract is on the *decision*, not
on the function. A decision carries one or more obligations; each
obligation can be expressed as a DbC contract. mathcoding adds
obligations on attestations, on waivers, on revisions — kinds
that DbC does not have. DbC is a contract discipline; mathcoding
is a contract discipline plus a verifier discipline plus a
recovery discipline.

**What mathcoding refuses:** the assumption that a passing DbC
runtime check is a passing system. The runtime check is one
attestation kind, bounded by the inputs that triggered it; the
obligation is not. A change that preserves the runtime check but
breaks a property the obligation names is `Fail` in mathcoding
and `Pass` in DbC.

**This is a structurally close neighbour.** DbC and mathcoding
share the property-based view of correctness. The difference is
that mathcoding's properties are on decisions, attestations, and
waivers — not just on functions.

## 14. Formal Methods — TLA+, Coq, Isabelle, Lean, Alloy

Formal methods express a specification in a formal language and
prove (or model-check) properties of it. The discipline is the
proof; the artefact is the proof script and the certificate.

**What mathcoding inherits:** the proof-as-evidence idea. A
mathcoding attestation can carry a `producer: tla+ | coq |
isabelle` field; the proof is one attestation kind.

**What mathcoding adds:** the proof is one attestation kind, not
the only one. A formal proof is a `Pass` attestation; an
informal review is a `Review` attestation; a runtime observation
is an `Observed` attestation. The three are distinct; mathcoding
admits all three and refuses to promote a `Review` to an
`Observed` without an artifact.

**What mathcoding refuses:** the assumption that a proved
property is a verified system. The proof is bounded by the
model; the model is bounded by the spec; the spec is bounded by
the decision. A proved property in a model that does not match
the decision is `Stale` in mathcoding — the attestation is
honest, the substrate has changed, the kernel re-evaluates.

**This is the deepest neighbour.** Formal methods and mathcoding
share the bounded-evidence discipline. The difference is the
scope: formal methods prove properties of a model; mathcoding
binds a decision to a verifier of any kind (test, review,
observation, proof, runtime signal) and refuses to promote
verdicts between kinds.

## 15. TOGAF — The Open Group Architecture Framework

TOGAF is an enterprise-architecture framework: Architecture
Development Method (ADM), Architecture Content Framework,
Enterprise Continuum. The discipline is the ADM cycle; the
artefact is the architecture description.

**What mathcoding inherits:** the architecture-as-content idea. A
mathcoding decision can declare a `togaf_phase`; the obligation
is the property that phase must produce.

**What mathcoding adds:** TOGAF names the phase; mathcoding names
the verifier. A TOGAF phase A (Architecture Vision) without a
verifier is a wish; a mathcoding decision that names phase A and
declares a verifier is a check. TOGAF is a meta-model; mathcoding
is the gate that reads the meta-model.

**What mathcoding refuses:** the assumption that a completed ADM
cycle is a verified architecture. The cycle is a process; the
verification is per artefact. mathcoding replaces the cycle with
per-artefact obligations.

## 16. ISO/IEC/IEEE 42010 — Architecture Description Standard

ISO/IEC/IEEE 42010 is an international standard for architecture
description: stakeholders, concerns, viewpoints, views,
correspondence rules, languages. The discipline is the
architecture description; the artefact is the architecture
description document.

**What mathcoding inherits:** the concern-as-property idea. A
mathcoding obligation can declare an `iso42010_concern`; the
obligation is the property the architecture must satisfy for
that concern.

**What mathcoding adds:** 42010 names the concern; mathcoding
binds the concern to a verifier. A 42010-compliant architecture
description without verifiers is a document; a mathcoding
decision that names the concern and the verifier is a check.
42010 is the meta-model; mathcoding is the gate.

**This is the deepest standards-based neighbour.** 42010 and
mathcoding share the concern-driven view of architecture. The
difference is the kind of obligation: 42010 obligations are on
the description; mathcoding obligations are on the change, the
attestation, the waiver, and the revision.

## 17. Team Topologies (Matthew Skelhorn, Manuel Pais)

Team Topologies is an organisational design for software teams:
four team types (stream-aligned, enabling, complicated-subsystem,
platform), three interaction modes (collaboration, X-as-a-Service,
facilitating), and a cognitive-load model. The discipline is the
team structure; the artefact is the team topology and the
inter-team protocols.

**What mathcoding inherits:** the cognitive-load model. A
mathcoding `mode` (tiny / light / standard / strict / exhaustive)
is a function of the risk, which is a function of the cognitive
load a change places on the team.

**What mathcoding adds:** Team Topologies names the load;
mathcoding names the friction the load produces. A change that
Team Topologies classifies as `facilitating` is, in mathcoding,
`record`-friction; a change that crosses a team boundary is
`ask`-friction; a change to a constitutional rule is
`block`-friction. The two systems map onto each other but
mathcoding's friction is per change, not per team.

**What mathcoding refuses:** the assumption that a well-structured
team is a verifying team. The structure is a property of the
organisation; the verification is a property of the change. A
change in a stream-aligned team is `Inconclusive` if the
attestation is missing, regardless of the team structure.

## 18. SAFe — Scaled Agile Framework

SAFe is a scaling framework for agile: configuration levels
(Essential, Large, Portfolio), roles, ceremonies, artefacts. The
discipline is the ceremony cadence; the artefact is the
Program Increment (PI) plan and the iteration outputs.

**What mathcoding inherits:** the cadence idea. A mathcoding
decision can declare a `safe_pi`; the obligation is the property
the PI must preserve.

**What mathcoding adds:** SAFe names the ceremony; mathcoding
binds the artefact to a verifier. A PI plan without a verifier
is a wish; a mathcoding decision that names the PI artefact and
declares a verifier is a check. SAFe is a process; mathcoding is
a per-artefact check.

**What mathcoding refuses:** the assumption that a completed PI
is a verified PI. The PI is a process outcome; the verification
is per-artefact. mathcoding replaces the process gate with
per-artefact obligations.

## 19. OWASP SAMM — Software Assurance Maturity Model

OWASP SAMM is a maturity model for software assurance: five
business functions (Governance, Design, Implementation,
Verification, Operations), each with three security practices,
each with three maturity levels. The discipline is the maturity
ladder; the artefact is the SAMM assessment.

**What mathcoding inherits:** the assurance-function idea. A
mathcoding decision can declare a `samm_function`; the obligation
is the property the function must satisfy.

**What mathcoding adds:** SAMM evaluates the organisation;
mathcoding evaluates every change. A SAMM level-3 organisation
can ship a change whose obligations are `Inconclusive`; a SAMM
level-1 organisation can ship a change whose obligations are
`Pass`. The verdict is per change, not per organisation.

**What mathcoding refuses:** the assumption that a mature
organisation is a verifying change. Maturity is a property of
the organisation; verification is a property of the change. The
two are distinct kinds.

**This is the closest assurance-maturity neighbour.** SAMM and
mathcoding share the assurance vocabulary. The difference is
the grain: SAMM is annual and per organisation; mathcoding is
per change and per obligation.

## 20. NIST SSDF — Secure Software Development Framework

NIST SSDF is a framework of secure software development
practices: PO (Prepare the Organisation), PS (Protect the
Software), PW (Produce Well-Secured Software), RV (Respond to
Vulnerabilities). The discipline is the practice; the artefact
is the SSDF profile.

**What mathcoding inherits:** the practice-as-requirement idea. A
mathcoding decision can declare a `ssdf_practice`; the obligation
is the property the practice must satisfy.

**What mathcoding adds:** SSDF names the practice; mathcoding
binds the practice to a verifier. An SSDF-compliant practice
without a verifier is a description; a mathcoding decision that
names the practice and declares a verifier is a check. SSDF is
a profile; mathcoding is the gate that reads the profile.

**What mathcoding refuses:** the assumption that a profile is a
verification. The profile is a description; the verification is
per change. mathcoding replaces the profile with per-change
obligations.

## What mathcoding inherits and what it adds

mathcoding is not a clean break from prior work. It is a
combination of pieces that already exist, tightened by three
properties no other methodology combines:

| From | What mathcoding inherits |
|---|---|
| TDD | Tests as evidence |
| BDD | Behaviour as a checkable claim |
| DDD | Domain language as a property |
| FDD | Feature as a planning unit |
| MDD/MDA | Model as a first-class artefact |
| Spec-Driven Development | Spec as the source of truth |
| ADR / MADR | Decision as a versioned artifact |
| arc42 | Section as a namespace |
| C4 Model | Level-of-zoom as a property |
| Living Documentation | Generated artefact as evidence |
| Specification by Example | Example as a witness |
| OpenAPI | Machine-readable contract |
| Design by Contract | Pre-/post-condition as a property |
| Formal Methods | Proof as evidence |
| TOGAF | Phase as a property |
| ISO/IEC/IEEE 42010 | Concern as a property |
| Team Topologies | Cognitive load as a friction driver |
| SAFe | Cadence as a property |
| OWASP SAMM | Assurance function as a property |
| NIST SSDF | Practice as a requirement |

| What mathcoding adds that none of them offer together |
|---|
| Bounded evidence (subject, obligation, inputs, env, digest, method, time) |
| Honest uncertainty (absence = Inconclusive, never Pass) |
| Source-class discipline (declared ≠ derived ≠ attested ≠ reviewed ≠ observed) |
| Verdict-state discipline (Pass ≠ Fail ≠ Inconclusive ≠ InfrastructureError) |
| Five-band risk × four-level friction |
| Counterexample requirement (every non-tiny decision) |
| Waiver state machine (Active, Grace, Expired, Revoked) |
| Protected-policy transition checklist (7 guards) |
| Self-application (the kernel checks its own upgrade) |
| Substrate fingerprint (decisions and attestations digests are equal iff equal) |

## What mathcoding refuses

mathcoding's refusals are not features; they are the boundary
that keeps the protocol honest:

- "Approved" without an observation. Approval is a `Review`
  attestation; observation is an `Observed` attestation; the two
  are not interchangeable.
- A waiver without `expires_at`. A waiver that does not expire is
  a permission slip, not a deferral.
- A `Pass` on absence. An obligation with no attestation is
  `Inconclusive`, not `Pass`. "I haven't checked" is not "I
  checked and it works".
- A protected-policy transition without prior authority. A
  candidate policy cannot authorize its own adoption.
- A change that touches `axioms/`, `constitution`, or
  `kernel` without a counterexample, a fixture pair, and a
  migration path.
- A decision with no `risk.owner`. The owner is the person who
  is accountable when the obligation fails; without the owner,
  the decision is unaccountable.
- A remediation named `unassigned`, `TBD`, `auto`, or
  `system`. A synthetic remediation is a placeholder, not a
  remedy.

## When mathcoding is for you

The applicability envelope (`spec/algebra-3.2.md` §28) was
written in a hostile reading: which projects *cannot* afford
the discipline. A friendlier reading asks the inverse: which
projects *gain* from it, and how much does the discipline
actually cost?

The honest answer is: the discipline is cheap. Writing a
`commitment:` and an `obligation:` block before a change
takes seconds, not hours. The kernel's verdict on a passing
change takes sub-seconds. The cost of mathcoding is dominated
by *clarity of thought*, not by *ceremony of process* — and
clarity of thought pays off in every project, including the
smallest.

The success of a small project is usually decided in the
first hour: the better the question, the better the code.
mathcoding's discipline is, at its core, the discipline of
writing the question before the code. That is useful for one
developer on a hackathon, and it is useful for fifty
developers on a regulated aerospace system.

Where the discipline pays off most, the cost is invisible:

| Signal | Why mathcoding helps |
|---|---|
| Solo developer, no audit, 1-year lifetime | Forces you to write the question before the code; cheap (seconds per change) |
| Hackathon, MVP, prototype | Forces you to state what the prototype must prove; prevents over-engineering by name |
| 1-person team with an AI coding agent | Forces you to state the contract before the agent writes the code; turns "vibe coding" into "spec coding" |
| Two or more AI agents editing the same repo | Forces each agent to declare its commitment; prevents silent overwrite |
| 5+ year lifetime, 3+ person team | Forces architectural decisions to outlive their authors; the record is the rescue plan |
| Regulatory or contractual audit requirement | The attestation store and blocking gate are the audit trail |

The only cases where mathcoding is genuinely overhead are
the ones the kernel already covers silently: a 30-second
typo fix to a comment (mode `tiny`; the kernel is silent;
the discipline is invisible), a one-line patch to a fixture
(mode `light`; a one-line `commitment:` block), and an
emergency hotfix on a production outage (use the waiver
path; the post-hoc decision is mandatory within 24h).

In every other case — including "I am one person and I will
throw this away tomorrow" — the discipline of writing the
question before the code is worth the seconds it takes.

The honest cost reference is
`mathc time-estimate --class single-file-edit --count 1 --percentile p50`
— about 3 minutes of total wall-clock for a one-file
decision. Most of that time is *thinking*, not *typing*; the
discipline makes the thinking explicit, which is the point.

## Where to read more

- [Methodology](methodology.html) — the discipline.
- [Axioms](axioms.html) — the five axioms.
- [Foundations](foundations.html) — axioms → OCaml.
- [Spec/constitution](spec/constitution.html) — the 14 invariants.
- [Spec/algebra-3.2](spec/algebra-3.2.html) — the formal
  algebra (normative).
- [USAGE](https://github.com/11111000000/math-coding/blob/main/USAGE.md) — the Path A / Path C adoption runbook
  (canonical source on GitHub; `USAGE.md` is not rendered into `dist/`).
