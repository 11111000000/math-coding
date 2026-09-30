# Adopting math-coding

A short runbook for bringing an existing repository under the
math-coding protocol. Assumes you can run the `mc` binary and have a
git repository.

## Install

Two ways to get `mc` (`bin/mathc.exe` once compiled):

- Download a release binary from the project's GitHub releases page
  (Linux or macOS).
- Build locally with `nix develop .#test` then `dune build`; the
  binary lands at `_build/install/default/bin/mathc`.

## Adopt in an existing repo

1. Put the `mc` binary on `PATH` (a `tools/` directory keeps the repo
   self-contained).
2. Create `decisions/decision.yaml` mirroring the active policy at
   [`math-coding/decisions/decision.yaml`](https://github.com/11111000000/math-coding/blob/main/decisions/decision.yaml).
   Start by copying the file verbatim and changing the scope paths.
3. Add an empty `attestations/` directory and commit it.
4. Mirror `.github/workflows/ci.yml` from
   [`math-coding/.github/workflows/ci.yml`](https://github.com/11111000000/math-coding/blob/main/.github/workflows/ci.yml).
   The `mc self-check` step must run as a blocking gate (no
   `continue-on-error: true`).
5. First run, populate the store:
   `python3 scripts/generate-attestations.py < manifest.tsv` reads
   one `decision<TAB>obligation<TAB>kind<TAB>identity` row per line
   and writes one attestation JSON per row into `attestations/`. The
   manual equivalent is one JSON file per obligation matching
   `schemas/attestation.json`. The math-coding repo itself uses
   `scripts/generate-attestations-v3.0.0.20.sh` as a worked example
   for one release's batch.
6. Open a first PR. CI must be green on `mc self-check` before the
   next decision lands.

## Choose your adoption path

Math-coding pays off when its applicability envelope is positive;
for projects below that threshold it is overhead, not insurance.
The envelope ([`spec/algebra-3.2.md`](spec/algebra-3.2.md) §28)
treats applicability as a sum over signals:

- Multi-agent AI-assisted development: highly applicable. Two or
  more agents editing the same repo need a shared authority model
  more than humans do.
- Critical infrastructure with a 3+ person team and a 5+ year
  lifetime: applicable. Decisions outlive the people who wrote
  them.
- Regulatory or contractual audit requirements: mandatory
  applicable. The attestation store and blocking gate are the
  audit trail.
- Solo or small team with no AI agents: low applicability. A
  changelog plus code review is usually enough.
- Prototypes, MVPs, throwaway tools, hackathon code: not
  applicable. Skip the methodology.

### Decision question

> Does your project coordinate two or more AI agents, require
> regulatory audit, or will it live five or more years with three
> or more contributors?
> Yes → Path A. No → Path B.

### Path A — full math-coding 3.2

For applicable projects. The full ceremony is justified.

- Install the kernel binary from the
  [GitHub releases page](https://github.com/11111000000/math-coding/releases).
- Read the user-facing docs: this `USAGE.md`, [`AGENTS.md`](AGENTS.md),
  and the axiom files in [`axioms/`](axioms/). About 1100 lines
  total.
- Follow "Adopt in an existing repo" above to wire the blocking
  `mc gate` into CI.
- Populate the attestation store on day one (step 5 above).

### Path B — regular ADR plus counterexamples

For low-applicability projects. A standard architectural decision
record, one counterexample paragraph, and a human reviewer. No
kernel binary, no blocking gate, no attestation store.

- Write the ADR with `context`, `decision`, `consequences`,
  `risk`, `owner` — the MADR or adr-tools shape.
- Add a `## Counterexample` paragraph: the strongest plausible
  case where this decision is wrong, and what would change your
  verdict.
- Reviewer marks the PR **pass** or **request changes**; their
  verdict is the attestation.
- CI logs and the git history are the evidence trail. No JSON
  store is required.

### Migrating between paths

The two paths are not mutually exclusive. A project can start
on Path B and migrate to Path A when applicability increases —
adding AI agents, growing the team, taking on a regulated
customer. The reverse is also valid: if math-coding becomes
overhead (the project shrinks, the audit requirement ends),
rip out `decisions/`, `attestations/`, and the gate workflow.
A clean revert is itself evidence that the kernel did not
capture you.

## Author your first decision

A decision is a YAML file with front-matter. Seven fields matter:

- **intent**: one paragraph. What should become true?
- **commitment**: what is promised. If you cannot phrase it in two
  sentences, the decision is not ready.
- **scope**: `capabilities[]` and `paths[]`. What is in, what is out.
- **obligations**: list of `{id, claim, acceptance.all[].verifier}`.
  Each obligation names the fixture or kernel test that closes it.
- **acceptance**: `verifier` is a path or a known kernel verifier id;
  `result` is `pass`.
- **risk**: `declared_triggers[]` and an `owner`. What could go wrong?
- **relations**: `addresses[]` and `superseded_by[]`. Connect to
  other decisions and audit items.

Example:

```yaml
---
schema: math-coding/3.0-alpha
id: jwt-rotation
revision: 1

intent: |
  Replace long-lived JWTs with short-lived access tokens plus a
  refresh flow.

commitment: |
  All API endpoints accept only tokens issued by the new signer.
  Legacy tokens expire within 14 days.

scope:
  paths: ["auth/**", "middleware/**"]

obligations:
  - id: signer-rotated
    claim: The new signer is the only signer accepted by middleware.
    acceptance:
      all:
        - verifier: tests/auth/signer.t
          result: pass

risk:
  declared_triggers:
    - clock-skew
    - clients-caching-old-token
  owner: human:security

relations:
  addresses:
    - bootstrap-v3@2
```

## Review-time questions

Before declaring a change ready, an LLM agent should answer four
questions, in this order:

1. Does the diff touch only files in `scope.paths[]`? If not, the
   decision does not authorise it.
2. Does every new artifact pass `mc validate` against its JSON Schema?
3. Does each obligation name a fixture path that is present and green?
4. Does `mc self-check` pass on the branch HEAD?

A `no` on any of these is a block, not a waiver.

## What the kernel will refuse

The constitution lists 14 invariants. The most common refusals:

- **missing result**: a decision without `obligations[]`.
- **missing obligation**: an obligation without an `acceptance` verifier.
- **missing fixture**: a verifier that names a path that does not exist.
- **missing authority**: a protected-policy transition not under the
  previously active policy.
- **missing expiry**: a waiver without `expires_at`.
- **stale attestation**: material digest no longer matches.
- **silent promotion**: `unknown`, `waived`, or `reviewed` reported as `pass`.

Full list: [`spec/constitution.md`](spec/constitution.md) §"Kernel Invariants".