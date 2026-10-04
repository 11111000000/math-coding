# Adopting math-coding

A short guide for bringing an existing repository under the
math-coding protocol. For AI-agent adoption see the canonical skill at
[`adoption/SKILL.md`](adoption/SKILL.md).

## Install

Two ways to get `mc` (`bin/mathc.exe` once compiled):

- Download a release binary from the project's GitHub releases page
  (Linux or macOS).
- Build locally with `nix develop .#test` then `dune build`; the
  binary lands at `_build/install/default/bin/mathc`.

## Quick start

If you want an AI coding agent (opencode, Claude Code, Cursor,
GitHub Copilot) to apply math-coding in your repository, copy the
matching file from the latest release tarball under
`dist/adoption/<platform>/` into the path named in
[`adoption/SKILL.md`](adoption/SKILL.md) §"Deploy this skill to your
platform". The skill walks the agent through four steps: install `mc`,
bootstrap the repo, author one decision, run `mc self-check`.

For manual adoption, follow the same four steps by reading the skill.

## Choose your adoption path

Math-coding pays off when its applicability envelope is positive; for
projects below that threshold it is overhead, not insurance. The
envelope ([`spec/algebra-3.2.md`](spec/algebra-3.2.md) §28) treats
applicability as a sum over signals:

- Multi-agent AI-assisted development: highly applicable. Two or more
  agents editing the same repo need a shared authority model more
  than humans do.
- Critical infrastructure with a 3+ person team and a 5+ year
  lifetime: applicable. Decisions outlive the people who wrote them.
- Regulatory or contractual audit requirements: mandatory applicable.
  The attestation store and blocking gate are the audit trail.
- Solo or small team with no AI agents: low applicability. A
  changelog plus code review is usually enough.
- Prototypes, MVPs, throwaway tools, hackathon code: not applicable.
  Skip the methodology.

### Decision question

> Does your project coordinate two or more AI agents, require
> regulatory audit, or will it live five or more years with three or
> more contributors?
> Yes → Path A. No → Path B.

### Path A — full math-coding 3.2

For applicable projects. The full ceremony is justified.

- Install the kernel binary from the
  [GitHub releases page](https://github.com/11111000000/math-coding/releases).
  On Linux the binary is built against Ubuntu-22.04 system glibc
  (`mathc-linux-x86_64`, `mathc-linux-aarch64`). On systems with
  older glibc or musl-libc (Alpine), the glibc binary may fail
  with `GLIBC_X.Y not found`. A musl-linked variant
  (`mathc-linux-x86_64-musl`) was attempted via `feature/portable-musl-build`
  but reverted in v3.2 (see `decisions/portable-linux-musl.yaml`
  reversal signal `alpine-ci-build-fails`); the CI build pipeline
  was unable to drive the Alpine container's opam setup end-to-end.
  A future release will re-attempt.
- Use the AI-agent skill from
  [`adoption/SKILL.md`](adoption/SKILL.md) (preferred) or follow the
  four steps in it manually.
- Wire the blocking `mc self-check` into CI per the project's
  [`.github/workflows/ci.yml`](https://github.com/11111000000/math-coding/blob/main/.github/workflows/ci.yml).
- Populate the attestation store on day one so the gate goes green.

### Path B — regular ADR plus counterexamples

For low-applicability projects. A standard architectural decision
record, one counterexample paragraph, and a human reviewer. No kernel
binary, no blocking gate, no attestation store.

- Write the ADR with `context`, `decision`, `consequences`, `risk`,
  `owner` — the MADR or adr-tools shape.
- Add a `## Counterexample` paragraph: the strongest plausible case
  where this decision is wrong, and what would change your verdict.
- Reviewer marks the PR **pass** or **request changes**; their
  verdict is the attestation.
- CI logs and the git history are the evidence trail. No JSON store
  is required.

### Migrating between paths

The two paths are not mutually exclusive. A project can start on
Path B and migrate to Path A when applicability increases — adding
AI agents, growing the team, taking on a regulated customer. The
reverse is also valid: if math-coding becomes overhead (the project
shrinks, the audit requirement ends), rip out `decisions/`,
`attestations/`, and the gate workflow. A clean revert is itself
evidence that the kernel did not capture you.

## Review-time questions

Before declaring a change ready, a reviewer should answer four
questions, in this order:

1. Does the diff touch only files in `scope.paths[]`? If not, the
   decision does not authorise it.
2. Does every new artifact pass `mc validate` against its JSON Schema?
3. Does each obligation name a fixture path that is present and green?
4. Does `mc self-check` pass on the branch HEAD?

A `no` on any of these is a block, not a waiver. AI agents walking
the same checks find the questions enumerated at the top of
[`adoption/SKILL.md`](adoption/SKILL.md) §"Step 4".

## What the kernel refuses

The constitution lists 14 invariants; the most common refusals are
enumerated in [`adoption/SKILL.md`](adoption/SKILL.md) §"What the
kernel refuses" (missing result, missing obligation, missing fixture,
missing authority, missing expiry, silent promotion). Full list:
[`spec/constitution.md`](spec/constitution.md) §"Kernel Invariants".