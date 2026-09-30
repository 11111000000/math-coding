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