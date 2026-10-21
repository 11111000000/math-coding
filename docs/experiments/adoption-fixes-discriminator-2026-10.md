# Second-order findings — to be validated by discriminator agents

> **Source.** This document collects 13 second-order findings
> the orchestrator surfaced AFTER plan-2026-10-adoption-fixes
> landed. The findings are categorised by the orchestrator's
> analysis. Discriminator agents are tasked with verifying
> each finding independently and reporting back whether
> (a) the finding is real, (b) severity is correctly rated,
> (c) the proposed fix is appropriate.
>
> The orchestrator's analysis is *itself a hypothesis*; the
> discriminator agents test it. Findings that survive three
> independent reviews become candidate sub-decisions for
> plan-2026-11-adoption-fixes (or successor); findings that
> do not survive are removed from the candidate list.

## Scope of the experiment

The original experiment was `docs/experiments/adoption-2026-10.md`
(5 OSS projects × 3 tasks + 5 controls = 20 sessions). Plan
`plan-2026-10-adoption-fixes-2026-10` (10 sub-decisions) closed
the 9 recommendations in §13. This document captures what
plan-2026-10-adoption-fixes *itself* surfaced — problems that
were not in the original 9 recommendations but emerged during
the fix process.

## Findings

### F1 — Sub-agents are not atomic

**Symptom.** B1 retry sub-agent (id `3a90dc2b-8f7a-4fb4-9ca9-06b9c278776d`)
ran out of Token Plan budget mid-work. The agent had already
written `do_verify` to `bin/Mathc.ml`, registered the dispatch
arm, updated 14 cram fixtures, and renamed `accept` → `parse-ok`
in the source. But it had NOT committed, NOT written the
decision file, and NOT generated attestations. The orchestrator
had to inspect the partial state, complete the decision file
+ attestations, and commit on the agent's behalf.

**Orchestrator's severity.** P2.

**Proposed fix.** Sub-agents should checkpoint (commit) every
N minutes of wall-clock work. Checkpoint cadence: every 5 min
of pure work, or every kernel-level change, whichever is sooner.

**Discriminator task.** Is the finding real? Is severity P2
right, or should it be P0/P1? Is the fix approach reasonable,
or is there a better one?

### F2 — Sub-agents branch off the wrong base

**Symptom.** B2 sub-agent was tasked with branching off
`plan/adoption-fixes-2026-10` but observed that A2 (YAML
parser) had not yet been merged into that branch. The agent
branched off `fix-yaml-parser-2026-10` instead, documentating
this as a "deliberate deviation". The orchestrator had to
subsequently merge A2 into the plan branch BEFORE B2.

**Orchestrator's severity.** P2.

**Proposed fix.** Orchestrator should merge dependencies
BEFORE launching dependent sub-agents. New convention: "no
sub-agent launches until all its declared dependencies are
merged into the integration branch".

**Discriminator task.** Is the finding real? Is the fix
approach right, or should the sub-agent itself wait for
dependencies? Should the prompt template change?

### F3 — Naming collision on attestation files

**Symptom.** When merging A3 (ship-attest-batch) into
`plan/adoption-fixes-2026-10`, the merge produced an
add/add conflict on
`attestations/plan-2026-10-adoption-fixes-2026-10-a3-attest-batch-shipped.json`.
Both my plan-decision-attestation and A3's own
sub-decision-attestation had written to the same path with
the same intent (`a3-attest-batch-shipped` obligation) but
different `issued_at` (and therefore different `id`).

**Orchestrator's severity.** P2.

**Proposed fix.** Either (a) use a different namespace for
plan-meta-attestations (e.g. `attestations/_plan-meta/`), or
(b) include the sub-decision's id in the attestation filename.

**Discriminator task.** Is the finding real? Will this
re-occur when plan-2026-11 ships? What is the cleanest
naming convention going forward?

### F4 — Plan-decision verifiers are placeholders

**Symptom.** The plan-decision's 13 obligations have verifiers
like `mathc-self-check-no-new-unknowns`,
`file-grep-zero`, `file-grep-non-zero`,
`mathc-validate-verdict-is-parse-ok` — these are placeholder
names, not real kernel verifiers. The plan-decision closed
because the orchestrator manually generated 12 review/test
attestations. This is honest (the attestations say so) but
adds no epistemic weight.

**Orchestrator's severity.** P3.

**Proposed fix.** Either (a) implement real kernel verifiers
that the kernel recognises by name; or (b) replace the
placeholder strings with paths to actual cram fixtures that
mathc can run.

**Discriminator task.** Is the finding real? How often does
this pattern recur across the project's other plan-decisions
(e.g. `plan-2026-10-ux-friction`, `plan-2026-10-distro-friction`)?

### F5 — Brownfield candidates were speculative

**Symptom.** §10.7 of the original experiment named
`open-telemetry/opentelemetry-go`, `opa`, `cncf/toc` as
candidates for the brownfield experiment. C4 (brownfield-experiment
v2) verified that NONE of these ship ADRs in their main
branches. C4 substituted 5 actually-verified candidates
(`adr/madr`, `JabRef/jabref`, `TUF`, `home-assistant/architecture`,
`cluster-api-provider-aws`).

**Orchestrator's severity.** P2.

**Proposed fix.** Add a "verified-by-clone" pre-flight step to
the experiment-design template: every project candidate must
have `git ls-tree <ref> docs/adr/ | head` checked before
inclusion.

**Discriminator task.** Is the finding real? Was C4's
substitution principled? Should we run the brownfield
experiment v2 execution?

### F6 — `mathc doctor` was not exercised in the experiment

**Symptom.** §11.1 of the original report mentions `mathc
doctor` as a positive note. C3 verified that doctor ships
(`bin/Mathc.ml::do_doctor` is defined, dispatch is registered,
`tests/cli/doctor.t` exists). But neither the original 15
sub-agents nor the 5 control tasks actually ran `mathc doctor`.

**Orchestrator's severity.** P3.

**Proposed fix.** Add `mathc doctor` to the per-session
checklist (alongside `mathc validate`, `mathc self-check`,
etc.).

**Discriminator task.** Is the finding real? How would
adding `mathc doctor` to the checklist change the experiment
result?

### F7 — Friction taxonomy was subjective even after C1

**Symptom.** C1 collapsed 8→4 categories but the same env-var
bug was tagged `F-WORKFLOW` (cobra), `F-TOOLING` (click),
`F-INTEGRATION` (express/ripgrep), `F-SETUP` (ripgrep) — by 4
different agents. The category reduction did not address the
**classification** problem.

**Orchestrator's severity.** P3.

**Proposed fix.** Add a disambiguation rule: "if the event
matches two categories, prefer the more *upstream* category
(installation > schema > workflow > semantic)". Document in
the experiment-design template.

**Discriminator task.** Is the finding real? Is the proposed
disambiguation rule clear, or will it just shift the
ambiguity?

### F8 — `attest-batch` was already implemented (A3 overstated)

**Symptom.** A3's decision says "ship the attest-batch
subcommand". In fact, the subcommand was already implemented
in `lib/attestations/batch.ml` and `bin/Mathc.ml::do_attest_batch`.
A3 only had to add a one-line dispatch entry and a cram
fixture. The plan allocated 1/10 of the workstream to A3
based on this overstated scope.

**Orchestrator's severity.** P3.

**Proposed fix.** When a sub-decision is tasked with "pin
existing implementation as acceptance crate", the decision
file's `outcomes:` should distinguish "implementation work"
from "acceptance work" so the project's effort accounting is
honest.

**Discriminator task.** Is the finding real? Is the fix
worthwhile? How would this affect the project if applied
retrospectively?

### F9 — `mathc verify` introduces a new attack surface

**Symptom.** B1's decision counterexample acknowledges:
"verifier execution must be sandboxed (no shell
privileges)". The actual implementation runs subprocesses
with only `PATH`/`HOME`/`LANG` inherited, with a 60-second
timeout. There is no seccomp, no bwrap, no chroot, no
namespace isolation. A malicious verifier string
(e.g. `rm -rf /`) would execute with the user's privileges
minus three env vars.

**Orchestrator's severity.** P1.

**Proposed fix.** Either (a) refuse to execute verifiers that
look like shell-injection vectors (escape analysis); or
(b) ship `mathc verify` behind a `--sandbox` flag that uses
bwrap or namespaces; or (c) require verifiers to be
whitelisted pathnames (e.g. only allow `pytest`, `npm test`,
`go test`, etc.).

**Discriminator task.** Is the finding real? What is the
right sandbox model? Is OS-level sandboxing necessary, or is
"trust the decision" acceptable?

### F10 — Other `bin/Mathc.ml` paths may still be hard-coded

**Symptom.** A1's sub-agent claimed to wire 7 subcommands
through the path resolver. The orchestrator did not verify
all read-side paths. Possible still-hard-coded:
`mathc migrate --manifest=PATH` (read-side), `mathc
re-evaluate-decisions AXIOM_ID`, `mathc record --decision-id
ID ...`.

**Orchestrator's severity.** P1.

**Proposed fix.** A kernel-decision `path-resolver-audit-2026-11`
that:
1. Greps `bin/Mathc.ml` for `decisions/`, `attestations/`,
   `policies.yaml` literals.
2. For each literal, classifies as "writable" (must go
   through resolver) or "readable from a fixed location"
   (e.g. master policy).
3. Files a follow-up sub-decision for each unresolved literal.

**Discriminator task.** Is the finding real? Are there
hard-coded paths that A1 missed? Run a grep and verify.

### F11 — Other `scripts/*.py` may have the same env-var issue

**Symptom.** A4 fixed `scripts/generate-attestations.py`. But
`scripts/slack2madr.py` and `scripts/confluence2madr.py` (mentioned
in `plan-2026-10-ux-friction` obligation `p11-brownfield-import-scripts`)
were not audited.

**Orchestrator's severity.** P2.

**Proposed fix.** A scripts-audit kernel-decision that runs
over `scripts/*.py` and reports env-var compatibility per script.

**Discriminator task.** Is the finding real? Run the grep
yourself and report.

### F12 — `mathc attest` is a misleading name

**Symptom.** `mathc attest FILE` is documented as parsing JUnit
XML; it does NOT write attestations. The bulk-write subcommand
is `mathc attest-batch` (now dispatched in A3). A new user
reading `mathc --help` will likely try `mathc attest` first and
be confused.

**Orchestrator's severity.** P2.

**Proposed fix.** Rename `mathc attest` → `mathc import-junit`
in the dispatch table. The JUnit-importer use case is real
(third-party CI integration) and deserves a descriptive name.

**Discriminator task.** Is the finding real? Is the rename
backwards-incompatible? Is the JUnit use case worth keeping
vs removing?

### F13 — `mathc doctor` was an undocumented assumption

**Symptom.** The original experiment prompt mentioned
`mathc doctor` in §11.1 as a future subcommand. C3 verified
that doctor was actually shipped in v3.3.0 (2026-10-15).
The experiment never tested it. The plan-meta-decision's
obligation `c3-mathc-doctor-ship-status-verified` is satisfied,
but the experiment never produced empirical data on doctor's
adoption value.

**Orchestrator's severity.** P3.

**Proposed fix.** The brownfield-experiment v2 design
(in `docs/experiments/brownfield-experiment-v2-2026-10.md`)
should include a `mathc doctor` exercise in the T1 task
template.

**Discriminator task.** Is the finding real? What is the
right way to test doctor in adoption experiments?

---

## Discriminator instructions

For each finding F1-F13:

1. **Verify the finding.** Read the relevant file or run the
   suggested command. Confirm the symptom is real.
2. **Re-rate severity.** P0 (blocker), P1 (must-fix), P2
   (should-fix), P3 (nice-to-have). Justify your rating.
3. **Suggest fix approach.** Concrete: name the files to
   change, the new tests to add, the kernel decisions to
   file. Do not just say "do X" — say "edit `bin/Mathc.ml`
   lines 123-145 to ...; add `tests/cli/foo.t` exercising ...".
4. **Flag false positives.** If a finding is overstated or
   based on a misreading, say so. The orchestrator's analysis
   is itself a hypothesis.

Output format: a YAML file with one entry per finding, like:

```yaml
findings:
  - id: F1
    verdict: confirmed | qualified | refuted
    severity: P0 | P1 | P2 | P3
    rationale: <one paragraph>
    fix: <concrete description; null if finding is refuted>
  ...
```

Discriminator agents are dispatched in parallel. The orchestrator
will aggregate the verdicts and use the surviving findings to
author the next round of plans.